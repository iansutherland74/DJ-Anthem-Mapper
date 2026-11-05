import Foundation
import XCTest
@testable import DJAnthemMapper

@MainActor
final class TransactionalMediaImportCoordinatorTests: XCTestCase {
    private typealias ImportResult =
        Swift.Result<MediaDescription, MediaImportError>

    private func url(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(name)")
    }

    private func description(
        _ name: String
    ) -> MediaDescription {
        MediaDescription(
            sourceURL: url(name),
            fileSize: 123,
            container: "MP3",
            duration: 180,
            overallBitRate: 320_000,
            metadata: MediaMetadata(
                title: nil,
                artist: nil,
                album: nil,
                genre: nil
            ),
            audioStreams: [
                AudioStreamDescription(
                    id: 0,
                    codecName: "MP3",
                    codecLongName: nil,
                    sampleRate: 44_100,
                    channels: 2,
                    channelLayout: "stereo",
                    bitRate: 320_000,
                    language: nil,
                    title: nil,
                    isDefault: true,
                    isCommentary: false
                )
            ],
            hasVideo: false
        )
    }

    func testSuccessfulInspectionDeliversDescription() {
        let expected = description("track-a.mp3")
        var receivedURL: URL?

        let coordinator =
            TransactionalMediaImportCoordinator {
                _, completion in

                completion(.success(expected))
            }

        coordinator.begin(url: expected.sourceURL) { outcome in
            if case .succeeded(let actual) = outcome {
                receivedURL = actual.sourceURL
            }
        }

        XCTAssertEqual(receivedURL, expected.sourceURL)
        XCTAssertFalse(coordinator.hasPendingImport)
    }

    func testFailedInspectionDeliversFailure() {
        var didFail = false

        let coordinator =
            TransactionalMediaImportCoordinator {
                _, completion in

                completion(.failure(.invalidResponse))
            }

        coordinator.begin(url: url("broken.mp3")) { outcome in
            if case .failed(.invalidResponse) = outcome {
                didFail = true
            }
        }

        XCTAssertTrue(didFail)
        XCTAssertFalse(coordinator.hasPendingImport)
    }

    func testInspectionReceivesExactURL() {
        let expected = url("exact source.mp3")
        var inspected: URL?

        let coordinator =
            TransactionalMediaImportCoordinator {
                incomingURL, completion in

                inspected = incomingURL
                completion(.failure(.invalidResponse))
            }

        coordinator.begin(url: expected) { _ in }

        XCTAssertEqual(inspected, expected)
    }

    func testPendingStateExistsUntilCallback() {
        var callback:
            (@MainActor (ImportResult) -> Void)?

        let coordinator =
            TransactionalMediaImportCoordinator {
                _, completion in

                callback = completion
            }

        coordinator.begin(
            url: url("track-a.mp3")
        ) { _ in }

        XCTAssertTrue(coordinator.hasPendingImport)

        callback?(.failure(.invalidResponse))

        XCTAssertFalse(coordinator.hasPendingImport)
    }

    func testCancelRejectsLaterCallback() {
        var callback:
            (@MainActor (ImportResult) -> Void)?

        var completionCount = 0

        let coordinator =
            TransactionalMediaImportCoordinator {
                _, completion in

                callback = completion
            }

        coordinator.begin(
            url: url("track-a.mp3")
        ) { _ in
            completionCount += 1
        }

        coordinator.cancelPendingImport()

        callback?(
            .success(description("track-a.mp3"))
        )

        XCTAssertEqual(completionCount, 0)
        XCTAssertFalse(coordinator.hasPendingImport)
    }

    func testLaterRequestSupersedesEarlierRequest() {
        var callbacks:
            [@MainActor (ImportResult) -> Void] = []

        var completedNames: [String] = []

        let coordinator =
            TransactionalMediaImportCoordinator {
                _, completion in

                callbacks.append(completion)
            }

        coordinator.begin(
            url: url("first.mp3")
        ) { outcome in
            if case .succeeded(let media) = outcome {
                completedNames.append(
                    media.sourceURL.lastPathComponent
                )
            }
        }

        coordinator.begin(
            url: url("second.mp3")
        ) { outcome in
            if case .succeeded(let media) = outcome {
                completedNames.append(
                    media.sourceURL.lastPathComponent
                )
            }
        }

        XCTAssertEqual(callbacks.count, 2)

        callbacks[0](
            .success(description("first.mp3"))
        )

        XCTAssertTrue(completedNames.isEmpty)
        XCTAssertTrue(coordinator.hasPendingImport)

        callbacks[1](
            .success(description("second.mp3"))
        )

        XCTAssertEqual(
            completedNames,
            ["second.mp3"]
        )

        XCTAssertFalse(coordinator.hasPendingImport)
    }

    func testStaleFailureCannotCancelLaterRequest() {
        var callbacks:
            [@MainActor (ImportResult) -> Void] = []

        var results: [String] = []

        let coordinator =
            TransactionalMediaImportCoordinator {
                _, completion in

                callbacks.append(completion)
            }

        coordinator.begin(
            url: url("first.mp3")
        ) { _ in
            results.append("first")
        }

        coordinator.begin(
            url: url("second.mp3")
        ) { outcome in
            if case .succeeded = outcome {
                results.append("second")
            }
        }

        callbacks[0](
            .failure(.invalidResponse)
        )

        XCTAssertTrue(results.isEmpty)
        XCTAssertTrue(coordinator.hasPendingImport)

        callbacks[1](
            .success(description("second.mp3"))
        )

        XCTAssertEqual(results, ["second"])
        XCTAssertFalse(coordinator.hasPendingImport)
    }

    func testFailureDoesNotInvokeSuccessPath() {
        var succeeded = false
        var failed = false

        let coordinator =
            TransactionalMediaImportCoordinator {
                _, completion in

                completion(.failure(.noAudio))
            }

        coordinator.begin(
            url: url("silent.mp3")
        ) { outcome in
            switch outcome {
            case .succeeded:
                succeeded = true
            case .failed(.noAudio):
                failed = true
            case .failed:
                break
            }
        }

        XCTAssertFalse(succeeded)
        XCTAssertTrue(failed)
    }

    func testSuccessDoesNotInvokeFailurePath() {
        var succeeded = false
        var failed = false
        let expected = description("good.mp3")

        let coordinator =
            TransactionalMediaImportCoordinator {
                _, completion in

                completion(.success(expected))
            }

        coordinator.begin(
            url: expected.sourceURL
        ) { outcome in
            switch outcome {
            case .succeeded:
                succeeded = true
            case .failed:
                failed = true
            }
        }

        XCTAssertTrue(succeeded)
        XCTAssertFalse(failed)
    }

    func testRequestIDsAdvance() {
        var callbacks:
            [@MainActor (ImportResult) -> Void] = []

        let coordinator =
            TransactionalMediaImportCoordinator {
                _, completion in

                callbacks.append(completion)
            }

        let first = coordinator.begin(
            url: url("first.mp3")
        ) { _ in }

        let second = coordinator.begin(
            url: url("second.mp3")
        ) { _ in }

        XCTAssertNotEqual(first, second)
        XCTAssertGreaterThan(second, first)
        XCTAssertEqual(callbacks.count, 2)
    }
}
