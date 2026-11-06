import XCTest
@testable import DJAnthemMapper

@MainActor
final class AnalysisVocalPipelineHardeningTests: XCTestCase {
    private func request(_ ext: String = "wav", streamID: Int? = nil) -> AnalysisAudioDecodeRequest {
        .init(sourceURL: URL(fileURLWithPath: "/tmp/C7.\(ext)"), absoluteAudioStreamIndex: streamID)
    }

    func testUnsupportedFormatFailsBeforeSeparation() async {
        let recorder = C7Recorder()
        let decoder = AnalysisAudioDecoder(
            nativeDecode: { _ in XCTFail("native decode called"); throw C7Error.unexpected },
            containerDecode: { _, _ in XCTFail("container decode called"); throw C7Error.unexpected }
        )
        let bridge = AnalysisVocalSeparationFactory.make(
            decode: { try await decoder.decode(request: $0) },
            separate: { _, _, _ in recorder.separateCalled = true; throw C7Error.unexpected }
        )
        do { _ = try await bridge.separateVocals(request: request("flac")); XCTFail("Expected unsupported format") }
        catch let error as AnalysisAudioDecoderError { XCTAssertEqual(error, .unsupportedFormat); XCTAssertFalse(recorder.separateCalled) }
        catch { XCTFail("Unexpected error: \(error)") }
    }

    func testContainerMissingStreamIDFailsBeforeSeparation() async {
        let recorder = C7Recorder()
        let decoder = AnalysisAudioDecoder(
            nativeDecode: { _ in throw C7Error.unexpected },
            containerDecode: { _, _ in throw C7Error.unexpected }
        )
        let bridge = AnalysisVocalSeparationFactory.make(
            decode: { try await decoder.decode(request: $0) },
            separate: { _, _, _ in recorder.separateCalled = true; throw C7Error.unexpected }
        )
        do { _ = try await bridge.separateVocals(request: request("mkv")); XCTFail("Expected missing stream ID") }
        catch let error as AnalysisAudioDecoderError { XCTAssertEqual(error, .missingAudioStreamID); XCTAssertFalse(recorder.separateCalled) }
        catch { XCTFail("Unexpected error: \(error)") }
    }

    func testRepeatedPipelineCallsRemainIndependent() async throws {
        let state = C7State()
        let bridge = AnalysisVocalSeparationFactory.make(
            decode: { _ in try await state.nextPCM() },
            separate: { left, right, rate in try VocalSeparationPCM(left: left, right: right, sampleRate: rate) }
        )
        let first = try await bridge.separateVocals(request: request())
        let second = try await bridge.separateVocals(request: request())
        XCTAssertNotEqual(first.left, second.left)
        XCTAssertEqual(first.sampleRate, second.sampleRate)
    }

    func testFailureDoesNotPoisonFollowingPipelineCall() async throws {
        let state = C7RecoveryState()
        let bridge = AnalysisVocalSeparationFactory.make(
            decode: { _ in try await state.next() },
            separate: { left, right, rate in try VocalSeparationPCM(left: left, right: right, sampleRate: rate) }
        )
        do { _ = try await bridge.separateVocals(request: request()); XCTFail("First call unexpectedly succeeded") }
        catch C7Error.expected {}
        let recovered = try await bridge.separateVocals(request: request())
        XCTAssertEqual(recovered.left, [7, 8])
        XCTAssertEqual(recovered.right, [9, 10])
    }

    func testContainerAbsoluteStreamIDSurvivesPipelineBoundary() async throws {
        let recorder = C7StreamRecorder()
        let pcm = try AnalysisAudioPCM(left: [1], right: [2], sampleRate: 44_100)
        let decoder = AnalysisAudioDecoder(
            nativeDecode: { _ in throw C7Error.unexpected },
            containerDecode: { _, streamID in
                await recorder.record(streamID)
                return pcm
            }
        )
        let bridge = AnalysisVocalSeparationFactory.make(
            decode: { try await decoder.decode(request: $0) },
            separate: { left, right, rate in try VocalSeparationPCM(left: left, right: right, sampleRate: rate) }
        )
        let result = try await bridge.separateVocals(request: request("mkv", streamID: 11))
        let recordedStreamID = await recorder.streamID
        XCTAssertEqual(recordedStreamID, 11)
        XCTAssertEqual(result.left, [1])
        XCTAssertEqual(result.right, [2])
    }
}

private enum C7Error: Error { case expected, unexpected }

@MainActor private final class C7Recorder {
    var separateCalled = false
}

private actor C7StreamRecorder {
    private(set) var streamID: Int?

    func record(_ streamID: Int) {
        self.streamID = streamID
    }
}

private actor C7State {
    private var count = 0
    func nextPCM() throws -> AnalysisAudioPCM {
        count += 1
        let x = Float(count)
        return try AnalysisAudioPCM(left: [x, x + 1], right: [x + 2, x + 3], sampleRate: 48_000)
    }
}

private actor C7RecoveryState {
    private var count = 0
    func next() throws -> AnalysisAudioPCM {
        count += 1
        if count == 1 { throw C7Error.expected }
        return try AnalysisAudioPCM(left: [7, 8], right: [9, 10], sampleRate: 44_100)
    }
}
