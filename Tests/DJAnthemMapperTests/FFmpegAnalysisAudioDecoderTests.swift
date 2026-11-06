import XCTest
@testable import DJAnthemMapper

final class FFmpegAnalysisAudioDecoderTests: XCTestCase {
    private let ffmpeg = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
    private let source = URL(fileURLWithPath: "/tmp/example multi stream.mkv")
    private let output = URL(fileURLWithPath: "/tmp/output.f32le")

    private func floatData(_ samples: [Float]) -> Data {
        samples.withUnsafeBytes { Data($0) }
    }

    func testRequestPreservesAbsoluteStreamIndex() throws {
        let request = try FFmpegAnalysisAudioDecodeRequest(sourceURL: source, absoluteStreamIndex: 7)
        XCTAssertEqual(request.absoluteStreamIndex, 7)
        XCTAssertEqual(request.sourceURL, source)
        XCTAssertEqual(request.sampleRate, 44_100)
    }

    func testRejectsNegativeStreamIndex() {
        XCTAssertThrowsError(try FFmpegAnalysisAudioDecodeRequest(sourceURL: source, absoluteStreamIndex: -1)) {
            XCTAssertEqual($0 as? FFmpegAnalysisAudioDecoderError, .invalidStreamID)
        }
    }

    func testRejectsNativeAudioExtensions() {
        for ext in ["wav", "mp3", "m4a"] {
            let url = URL(fileURLWithPath: "/tmp/file.\(ext)")
            XCTAssertThrowsError(try FFmpegAnalysisAudioDecodeRequest(sourceURL: url, absoluteStreamIndex: 0)) {
                XCTAssertEqual($0 as? FFmpegAnalysisAudioDecoderError, .unsupportedFormat)
            }
        }
    }

    func testAcceptsMP4AndMKV() throws {
        XCTAssertNoThrow(try FFmpegAnalysisAudioDecodeRequest(sourceURL: URL(fileURLWithPath: "/tmp/a.mp4"), absoluteStreamIndex: 1))
        XCTAssertNoThrow(try FFmpegAnalysisAudioDecodeRequest(sourceURL: URL(fileURLWithPath: "/tmp/a.mkv"), absoluteStreamIndex: 2))
    }

    func testCommandUsesAbsoluteMapAndSafeRawFloatOutput() throws {
        let request = try FFmpegAnalysisAudioDecodeRequest(sourceURL: source, absoluteStreamIndex: 7, sampleRate: 48_000)
        let command = FFmpegAnalysisAudioCommandBuilder().command(request: request, executableURL: ffmpeg, outputURL: output)
        XCTAssertEqual(command.executableURL, ffmpeg)
        XCTAssertEqual(command.outputURL, output)
        XCTAssertTrue(command.arguments.contains("0:7"))
        XCTAssertFalse(command.arguments.contains("0:a:7"))
        XCTAssertTrue(command.arguments.contains("pcm_f32le"))
        XCTAssertTrue(command.arguments.contains("f32le"))
        XCTAssertTrue(command.arguments.contains("48000"))
        XCTAssertEqual(command.arguments.last, output.path)
        let inputIndex = try XCTUnwrap(command.arguments.firstIndex(of: "-i"))
        XCTAssertEqual(command.arguments[inputIndex + 1], source.path)
    }

    func testInterleavedFloatDataBecomesStereoPCMExactly() throws {
        let data = floatData([1, 10, 2, 20, 3, 30])
        let pcm = try FFmpegAnalysisAudioDecoder.decodeInterleavedStereoFloat32(data: data, sampleRate: 44_100)
        XCTAssertEqual(pcm.left, [1, 2, 3])
        XCTAssertEqual(pcm.right, [10, 20, 30])
        XCTAssertEqual(pcm.sampleRate, 44_100)
    }

    func testEmptyAndMisalignedPCMRejected() {
        XCTAssertThrowsError(try FFmpegAnalysisAudioDecoder.decodeInterleavedStereoFloat32(data: Data(), sampleRate: 44_100)) {
            XCTAssertEqual($0 as? FFmpegAnalysisAudioDecoderError, .emptyAudio)
        }
        XCTAssertThrowsError(try FFmpegAnalysisAudioDecoder.decodeInterleavedStereoFloat32(data: Data(repeating: 0, count: 7), sampleRate: 44_100)) {
            XCTAssertEqual($0 as? FFmpegAnalysisAudioDecoderError, .malformedPCM)
        }
    }

    func testDecoderPassesExactCommandToInjectedRunner() async throws {
        let request = try FFmpegAnalysisAudioDecodeRequest(sourceURL: source, absoluteStreamIndex: 5)
        let recorder = CommandRecorder(data: floatData([0.1, 0.2, 0.3, 0.4]))
        let decoder = FFmpegAnalysisAudioDecoder(executableFinder: { self.ffmpeg }, runner: { command in
            await recorder.record(command)
            return recorder.data
        })
        let pcm = try await decoder.decode(request: request)
        let command = await recorder.command
        XCTAssertEqual(command?.executableURL, ffmpeg)
        XCTAssertTrue(command?.arguments.contains("0:5") == true)
        XCTAssertEqual(pcm.left, [0.1, 0.3])
        XCTAssertEqual(pcm.right, [0.2, 0.4])
    }

    func testMissingFFmpegFailsBeforeRunner() async throws {
        let recorder = CommandRecorder(data: Data())
        let decoder = FFmpegAnalysisAudioDecoder(executableFinder: { nil }, runner: { command in
            await recorder.record(command)
            return Data()
        })
        let request = try FFmpegAnalysisAudioDecodeRequest(sourceURL: source, absoluteStreamIndex: 1)
        do {
            _ = try await decoder.decode(request: request)
            XCTFail("Missing FFmpeg unexpectedly succeeded")
        } catch let error as FFmpegAnalysisAudioDecoderError {
            XCTAssertEqual(error, .ffmpegNotFound)
        }
        let recordedCommand = await recorder.command
        XCTAssertNil(recordedCommand)
    }

    func testPreCancelledDecodeStopsBeforeRunner() async throws {
        let recorder = CommandRecorder(data: floatData([0, 0]))
        let gate = CancellationStartGate()
        let request = try FFmpegAnalysisAudioDecodeRequest(sourceURL: source, absoluteStreamIndex: 1)
        let decoder = FFmpegAnalysisAudioDecoder(executableFinder: { self.ffmpeg }, runner: { command in
            await recorder.record(command)
            return recorder.data
        })

        let task = Task {
            await gate.waitUntilReleased()
            return try await decoder.decode(request: request)
        }

        await gate.waitUntilWaiting()
        task.cancel()
        await gate.release()

        do {
            _ = try await task.value
            XCTFail("Cancelled decode unexpectedly succeeded")
        } catch is CancellationError {}

        let recordedCommand = await recorder.command
        XCTAssertNil(recordedCommand)
    }
}

private actor CommandRecorder {
    private(set) var command: FFmpegAnalysisAudioCommand?
    let data: Data
    init(data: Data) { self.data = data }
    func record(_ command: FFmpegAnalysisAudioCommand) { self.command = command }
}


private actor CancellationStartGate {
    private var waiting = false
    private var released = false
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var waitingContinuation: CheckedContinuation<Void, Never>?

    func waitUntilReleased() async {
        waiting = true
        waitingContinuation?.resume()
        waitingContinuation = nil
        if released { return }
        await withCheckedContinuation { continuation in
            startContinuation = continuation
        }
    }

    func waitUntilWaiting() async {
        if waiting { return }
        await withCheckedContinuation { continuation in
            waitingContinuation = continuation
        }
    }

    func release() {
        released = true
        startContinuation?.resume()
        startContinuation = nil
    }
}
