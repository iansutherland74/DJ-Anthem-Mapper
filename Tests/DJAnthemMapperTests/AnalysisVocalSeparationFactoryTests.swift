import XCTest
@testable import DJAnthemMapper

@MainActor
final class AnalysisVocalSeparationFactoryTests: XCTestCase {
    private func makeRequest(extension ext: String = "wav", streamID: Int? = nil) -> AnalysisAudioDecodeRequest {
        AnalysisAudioDecodeRequest(
            sourceURL: URL(fileURLWithPath: "/tmp/C6.\(ext)"),
            absoluteAudioStreamIndex: streamID
        )
    }

    func testProductionFactoryConstructsBridge() {
        _ = AnalysisVocalSeparationFactory.makeProduction()
    }

    func testInjectedFactoryPassesExactRequestToDecoder() async throws {
        let request = makeRequest(extension: "mkv", streamID: 7)
        let decoded = try AnalysisAudioPCM(left: [0.1, 0.2], right: [0.3, 0.4], sampleRate: 48_000)
        let expected = try VocalSeparationPCM(left: [0.5, 0.6], right: [0.7, 0.8], sampleRate: 48_000)
        let recorder = C6Recorder()
        let bridge = AnalysisVocalSeparationFactory.make(
            decode: { actualRequest in
                recorder.decodeCalled = true
                recorder.receivedRequest = actualRequest
                return decoded
            },
            separate: { left, right, sampleRate in
                recorder.separateCalled = true
                recorder.receivedLeft = left
                recorder.receivedRight = right
                recorder.receivedSampleRate = sampleRate
                return expected
            }
        )
        let actual = try await bridge.separateVocals(request: request)
        XCTAssertEqual(actual, expected)
        XCTAssertTrue(recorder.decodeCalled)
        XCTAssertTrue(recorder.separateCalled)
        XCTAssertEqual(recorder.receivedRequest, request)
        XCTAssertEqual(recorder.receivedRequest?.absoluteAudioStreamIndex, 7)
    }

    func testDecodedPCMIsForwardedExactlyToSeparator() async throws {
        let decoded = try AnalysisAudioPCM(left: [1, 2, 3], right: [10, 20, 30], sampleRate: 48_000)
        let expected = try VocalSeparationPCM(left: [4, 5, 6], right: [40, 50, 60], sampleRate: 48_000)
        let recorder = C6Recorder()
        let bridge = AnalysisVocalSeparationFactory.make(
            decode: { request in
                recorder.decodeCalled = true
                recorder.receivedRequest = request
                return decoded
            },
            separate: { left, right, sampleRate in
                recorder.separateCalled = true
                recorder.receivedLeft = left
                recorder.receivedRight = right
                recorder.receivedSampleRate = sampleRate
                return expected
            }
        )
        let actual = try await bridge.separateVocals(request: makeRequest())
        XCTAssertEqual(actual, expected)
        XCTAssertTrue(recorder.decodeCalled)
        XCTAssertTrue(recorder.separateCalled)
        XCTAssertEqual(recorder.receivedLeft, decoded.left)
        XCTAssertEqual(recorder.receivedRight, decoded.right)
        XCTAssertEqual(recorder.receivedSampleRate, decoded.sampleRate)
    }

    func testSeparatorOutputIsReturnedUnchanged() async throws {
        let decoded = try AnalysisAudioPCM(left: [0, 0], right: [0, 0], sampleRate: 44_100)
        let expected = try VocalSeparationPCM(left: [0.25, 0.5], right: [0.75, 1.0], sampleRate: 44_100)
        let bridge = AnalysisVocalSeparationFactory.make(
            decode: { _ in decoded },
            separate: { _, _, _ in expected }
        )
        let actual = try await bridge.separateVocals(request: makeRequest())
        XCTAssertEqual(actual, expected)
    }

    func testDecodeFailurePreventsSeparatorInvocation() async {
        enum TestError: Error { case decode }
        let recorder = C6Recorder()
        let bridge = AnalysisVocalSeparationFactory.make(
            decode: { _ in recorder.decodeCalled = true; throw TestError.decode },
            separate: { _, _, _ in recorder.separateCalled = true; throw TestError.decode }
        )
        do {
            _ = try await bridge.separateVocals(request: makeRequest())
            XCTFail("Decode failure unexpectedly succeeded")
        } catch TestError.decode {
            XCTAssertTrue(recorder.decodeCalled)
            XCTAssertFalse(recorder.separateCalled)
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    func testSeparatorFailurePropagatesUnchanged() async throws {
        enum TestError: Error { case separator }
        let decoded = try AnalysisAudioPCM(left: [0], right: [0], sampleRate: 44_100)
        let recorder = C6Recorder()
        let bridge = AnalysisVocalSeparationFactory.make(
            decode: { _ in recorder.decodeCalled = true; return decoded },
            separate: { _, _, _ in recorder.separateCalled = true; throw TestError.separator }
        )
        do {
            _ = try await bridge.separateVocals(request: makeRequest())
            XCTFail("Separator failure unexpectedly succeeded")
        } catch TestError.separator {
            XCTAssertTrue(recorder.decodeCalled)
            XCTAssertTrue(recorder.separateCalled)
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    func testPreCancelledPipelineDoesNotStartDecodeOrSeparation() async {
        let recorder = C6Recorder()
        let bridge = AnalysisVocalSeparationFactory.make(
            decode: { _ in
                recorder.decodeCalled = true
                return try AnalysisAudioPCM(left: [0], right: [0], sampleRate: 44_100)
            },
            separate: { _, _, _ in
                recorder.separateCalled = true
                return try VocalSeparationPCM(left: [0], right: [0], sampleRate: 44_100)
            }
        )
        let request = makeRequest()
        let task = Task { @MainActor in try await bridge.separateVocals(request: request) }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Cancelled pipeline unexpectedly succeeded")
        } catch is CancellationError {
            XCTAssertFalse(recorder.decodeCalled)
            XCTAssertFalse(recorder.separateCalled)
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    func testCancellationFromDecoderDoesNotStartSeparator() async {
        let recorder = C6Recorder()
        let bridge = AnalysisVocalSeparationFactory.make(
            decode: { _ in recorder.decodeCalled = true; throw CancellationError() },
            separate: { _, _, _ in
                recorder.separateCalled = true
                return try VocalSeparationPCM(left: [0], right: [0], sampleRate: 44_100)
            }
        )
        do {
            _ = try await bridge.separateVocals(request: makeRequest())
            XCTFail("Cancellation unexpectedly succeeded")
        } catch is CancellationError {
            XCTAssertTrue(recorder.decodeCalled)
            XCTAssertFalse(recorder.separateCalled)
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    func testCancellationFromSeparatorRemainsCancellation() async throws {
        let decoded = try AnalysisAudioPCM(left: [0], right: [0], sampleRate: 44_100)
        let recorder = C6Recorder()
        let bridge = AnalysisVocalSeparationFactory.make(
            decode: { _ in recorder.decodeCalled = true; return decoded },
            separate: { _, _, _ in recorder.separateCalled = true; throw CancellationError() }
        )
        do {
            _ = try await bridge.separateVocals(request: makeRequest())
            XCTFail("Cancellation unexpectedly succeeded")
        } catch is CancellationError {
            XCTAssertTrue(recorder.decodeCalled)
            XCTAssertTrue(recorder.separateCalled)
        } catch { XCTFail("Unexpected error: \(error)") }
    }
}

@MainActor
private final class C6Recorder {
    var receivedRequest: AnalysisAudioDecodeRequest?
    var receivedLeft: [Float]?
    var receivedRight: [Float]?
    var receivedSampleRate: UInt32?
    var decodeCalled = false
    var separateCalled = false
}
