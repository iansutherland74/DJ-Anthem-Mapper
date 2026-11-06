import XCTest
@testable import DJAnthemMapper

@MainActor
final class HTDemucsVocalSeparatorTests: XCTestCase {
    final class Backend: VocalSeparationBackend {
        var prepareCount = 0
        var received: VocalSeparationPCM?
        var result: Result<VocalSeparationPCM, Error>

        init(result: Result<VocalSeparationPCM, Error>) { self.result = result }
        func prepare() async throws { prepareCount += 1 }
        func separate(_ input: VocalSeparationPCM) async throws -> VocalSeparationPCM {
            received = input
            return try result.get()
        }
    }

    func testPCMRejectsZeroSampleRate() {
        XCTAssertThrowsError(try VocalSeparationPCM(left: [0], right: [0], sampleRate: 0))
    }

    func testPCMRejectsMismatchedChannels() {
        XCTAssertThrowsError(try VocalSeparationPCM(left: [0, 0], right: [0], sampleRate: 44_100))
    }

    func testPCMRejectsEmptyChannels() {
        XCTAssertThrowsError(try VocalSeparationPCM(left: [], right: [], sampleRate: 44_100))
    }

    func testPCMRejectsNonFiniteSamples() {
        XCTAssertThrowsError(try VocalSeparationPCM(left: [.nan], right: [0], sampleRate: 44_100))
    }

    func testSeparatorPreparesThenReturnsBackendVocalPCM() async throws {
        let expected = try VocalSeparationPCM(left: [0.1, 0.2], right: [0.3, 0.4], sampleRate: 44_100)
        let backend = Backend(result: .success(expected))
        let separator = HTDemucsVocalSeparator(backend: backend)
        let actual = try await separator.separate(left: [0, 0], right: [0, 0], sampleRate: 44_100)
        XCTAssertEqual(actual, expected)
        XCTAssertEqual(backend.prepareCount, 1)
        XCTAssertEqual(backend.received?.sampleRate, 44_100)
        XCTAssertEqual(backend.received?.left, [0, 0])
    }

    func testSeparatorPropagatesTypedBackendFailure() async throws {
        let placeholder = try VocalSeparationPCM(left: [0], right: [0], sampleRate: 44_100)
        let backend = Backend(result: .failure(VocalSeparationError.noVocalStem))
        let separator = HTDemucsVocalSeparator(backend: backend)
        do {
            _ = try await separator.separate(left: placeholder.left, right: placeholder.right, sampleRate: placeholder.sampleRate)
            XCTFail("Expected failure")
        } catch let error as VocalSeparationError {
            XCTAssertEqual(error, .noVocalStem)
        }
    }

    func testPrepareIsDelegated() async throws {
        let output = try VocalSeparationPCM(left: [0], right: [0], sampleRate: 44_100)
        let backend = Backend(result: .success(output))
        let separator = HTDemucsVocalSeparator(backend: backend)
        try await separator.prepare()
        XCTAssertEqual(backend.prepareCount, 1)
    }
}
