import XCTest
@testable import DJAnthemMapper

final class AnalysisAudioDecoderTests: XCTestCase {
    private func pcm(_ marker: Float = 1) throws -> AnalysisAudioPCM {
        try AnalysisAudioPCM(
            left: [marker, marker + 1],
            right: [marker + 10, marker + 11],
            sampleRate: 48_000
        )
    }

    private func makeDecoder(
        nativeResult: Result<AnalysisAudioPCM, Error>,
        containerResult: Result<AnalysisAudioPCM, Error>
    ) -> (AnalysisAudioDecoder, DecodeRecorder) {
        let recorder = DecodeRecorder()
        let decoder = AnalysisAudioDecoder(
            nativeDecode: { url in
                await recorder.recordNative(url)
                return try nativeResult.get()
            },
            containerDecode: { url, streamID in
                await recorder.recordContainer(url, streamID: streamID)
                return try containerResult.get()
            }
        )
        return (decoder, recorder)
    }

    func testWAVRoutesOnlyToNativeDecoder() async throws {
        try await assertNativeRouting(extension: "wav")
    }

    func testMP3RoutesOnlyToNativeDecoder() async throws {
        try await assertNativeRouting(extension: "mp3")
    }

    func testM4ARoutesOnlyToNativeDecoder() async throws {
        try await assertNativeRouting(extension: "m4a")
    }

    func testUppercaseNativeExtensionRoutesToNativeDecoder() async throws {
        try await assertNativeRouting(extension: "WAV")
    }

    func testMP4RoutesOnlyToContainerDecoder() async throws {
        try await assertContainerRouting(extension: "mp4", streamID: 7)
    }

    func testMKVRoutesOnlyToContainerDecoder() async throws {
        try await assertContainerRouting(extension: "mkv", streamID: 12)
    }

    func testUnsupportedExtensionFailsBeforeEitherBackend() async throws {
        let value = try pcm()
        let (decoder, recorder) = makeDecoder(nativeResult: .success(value), containerResult: .success(value))
        do {
            _ = try await decoder.decode(request: .init(sourceURL: URL(fileURLWithPath: "/tmp/a.flac")))
            XCTFail("Unsupported format unexpectedly decoded")
        } catch let error as AnalysisAudioDecoderError {
            XCTAssertEqual(error, .unsupportedFormat)
        }
        let counts = await recorder.counts()
        XCTAssertEqual(counts.native, 0)
        XCTAssertEqual(counts.container, 0)
    }

    func testMP4PreservesAbsoluteStreamIDExactly() async throws {
        try await assertContainerRouting(extension: "mp4", streamID: 7)
    }

    func testMKVPreservesAbsoluteStreamIDExactly() async throws {
        try await assertContainerRouting(extension: "mkv", streamID: 12)
    }

    func testMP4WithoutStreamIDFailsClosed() async throws {
        try await assertMissingStreamID(extension: "mp4")
    }

    func testMKVWithoutStreamIDFailsClosed() async throws {
        try await assertMissingStreamID(extension: "mkv")
    }

    func testNativePCMReturnedUnchanged() async throws {
        let expected = try pcm(3)
        let fallback = try pcm(9)
        let (decoder, _) = makeDecoder(nativeResult: .success(expected), containerResult: .success(fallback))
        let actual = try await decoder.decode(request: .init(sourceURL: URL(fileURLWithPath: "/tmp/a.wav")))
        XCTAssertEqual(actual, expected)
    }

    func testContainerPCMReturnedUnchanged() async throws {
        let expected = try pcm(4)
        let fallback = try pcm(8)
        let (decoder, _) = makeDecoder(nativeResult: .success(fallback), containerResult: .success(expected))
        let actual = try await decoder.decode(request: .init(sourceURL: URL(fileURLWithPath: "/tmp/a.mkv"), absoluteAudioStreamIndex: 5))
        XCTAssertEqual(actual, expected)
    }

    func testNativeFailureDoesNotInvokeContainer() async throws {
        let fallback = try pcm()
        let (decoder, recorder) = makeDecoder(nativeResult: .failure(TestError.failed), containerResult: .success(fallback))
        do {
            _ = try await decoder.decode(request: .init(sourceURL: URL(fileURLWithPath: "/tmp/a.mp3")))
            XCTFail("Native failure unexpectedly succeeded")
        } catch let error as AnalysisAudioDecoderError {
            XCTAssertEqual(error, .nativeDecodeFailed)
        }
        let counts = await recorder.counts()
        XCTAssertEqual(counts.native, 1)
        XCTAssertEqual(counts.container, 0)
    }

    func testContainerFailureDoesNotInvokeNative() async throws {
        let fallback = try pcm()
        let (decoder, recorder) = makeDecoder(nativeResult: .success(fallback), containerResult: .failure(TestError.failed))
        do {
            _ = try await decoder.decode(request: .init(sourceURL: URL(fileURLWithPath: "/tmp/a.mp4"), absoluteAudioStreamIndex: 3))
            XCTFail("Container failure unexpectedly succeeded")
        } catch let error as AnalysisAudioDecoderError {
            XCTAssertEqual(error, .containerDecodeFailed)
        }
        let counts = await recorder.counts()
        XCTAssertEqual(counts.native, 0)
        XCTAssertEqual(counts.container, 1)
    }

    func testNativeCancellationRemainsCancellation() async throws {
        let fallback = try pcm()
        let (decoder, _) = makeDecoder(nativeResult: .failure(CancellationError()), containerResult: .success(fallback))
        do {
            _ = try await decoder.decode(request: .init(sourceURL: URL(fileURLWithPath: "/tmp/a.wav")))
            XCTFail("Cancellation unexpectedly translated")
        } catch is CancellationError {}
    }

    func testContainerCancellationRemainsCancellation() async throws {
        let fallback = try pcm()
        let (decoder, _) = makeDecoder(nativeResult: .success(fallback), containerResult: .failure(CancellationError()))
        do {
            _ = try await decoder.decode(request: .init(sourceURL: URL(fileURLWithPath: "/tmp/a.mkv"), absoluteAudioStreamIndex: 2))
            XCTFail("Cancellation unexpectedly translated")
        } catch is CancellationError {}
    }

    func testFailureDoesNotPoisonFollowingDecode() async throws {
        let recorder = DecodeRecorder()
        let expected = try pcm(6)
        let state = AttemptState(success: expected)
        let decoder = AnalysisAudioDecoder(
            nativeDecode: { url in
                await recorder.recordNative(url)
                return try await state.next()
            },
            containerDecode: { _, _ in throw TestError.failed }
        )

        do {
            _ = try await decoder.decode(request: .init(sourceURL: URL(fileURLWithPath: "/tmp/a.wav")))
            XCTFail("First call unexpectedly succeeded")
        } catch let error as AnalysisAudioDecoderError {
            XCTAssertEqual(error, .nativeDecodeFailed)
        }

        let recovered = try await decoder.decode(request: .init(sourceURL: URL(fileURLWithPath: "/tmp/a.wav")))
        XCTAssertEqual(recovered, expected)
    }

    private func assertNativeRouting(extension ext: String) async throws {
        let expected = try pcm(2)
        let fallback = try pcm(9)
        let (decoder, recorder) = makeDecoder(nativeResult: .success(expected), containerResult: .success(fallback))
        let url = URL(fileURLWithPath: "/tmp/input.\(ext)")
        let actual = try await decoder.decode(request: .init(sourceURL: url, absoluteAudioStreamIndex: 99))
        XCTAssertEqual(actual, expected)
        let snapshot = await recorder.snapshot()
        XCTAssertEqual(snapshot.nativeURLs, [url])
        XCTAssertTrue(snapshot.containerCalls.isEmpty)
    }

    private func assertContainerRouting(extension ext: String, streamID: Int) async throws {
        let expected = try pcm(5)
        let fallback = try pcm(9)
        let (decoder, recorder) = makeDecoder(nativeResult: .success(fallback), containerResult: .success(expected))
        let url = URL(fileURLWithPath: "/tmp/input.\(ext)")
        let actual = try await decoder.decode(request: .init(sourceURL: url, absoluteAudioStreamIndex: streamID))
        XCTAssertEqual(actual, expected)
        let snapshot = await recorder.snapshot()
        XCTAssertTrue(snapshot.nativeURLs.isEmpty)
        XCTAssertEqual(snapshot.containerCalls, [.init(url: url, streamID: streamID)])
    }

    private func assertMissingStreamID(extension ext: String) async throws {
        let value = try pcm()
        let (decoder, recorder) = makeDecoder(nativeResult: .success(value), containerResult: .success(value))
        do {
            _ = try await decoder.decode(request: .init(sourceURL: URL(fileURLWithPath: "/tmp/input.\(ext)")))
            XCTFail("Missing stream ID unexpectedly defaulted")
        } catch let error as AnalysisAudioDecoderError {
            XCTAssertEqual(error, .missingAudioStreamID)
        }
        let counts = await recorder.counts()
        XCTAssertEqual(counts.native, 0)
        XCTAssertEqual(counts.container, 0)
    }
}

private enum TestError: Error { case failed }

private struct ContainerCall: Equatable, Sendable {
    let url: URL
    let streamID: Int
}

private actor DecodeRecorder {
    private var nativeURLs: [URL] = []
    private var containerCalls: [ContainerCall] = []

    func recordNative(_ url: URL) { nativeURLs.append(url) }
    func recordContainer(_ url: URL, streamID: Int) {
        containerCalls.append(.init(url: url, streamID: streamID))
    }
    func counts() -> (native: Int, container: Int) {
        (nativeURLs.count, containerCalls.count)
    }
    func snapshot() -> (nativeURLs: [URL], containerCalls: [ContainerCall]) {
        (nativeURLs, containerCalls)
    }
}

private actor AttemptState {
    private var attempts = 0
    private let success: AnalysisAudioPCM

    init(success: AnalysisAudioPCM) { self.success = success }

    func next() throws -> AnalysisAudioPCM {
        attempts += 1
        if attempts == 1 { throw TestError.failed }
        return success
    }
}
