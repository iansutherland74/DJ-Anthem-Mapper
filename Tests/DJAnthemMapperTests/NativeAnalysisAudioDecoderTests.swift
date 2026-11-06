import XCTest
import AVFAudio
@testable import DJAnthemMapper

final class NativeAnalysisAudioDecoderTests: XCTestCase {
    private func temporaryURL(extension ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("DJAM-C2-\(UUID().uuidString)")
            .appendingPathExtension(ext)
    }

    private func writeWAV(channels: AVAudioChannelCount, sampleRate: Double, frames: Int) throws -> (URL, [[Float]]) {
        let url = temporaryURL(extension: "wav")
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        ), let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
           let data = buffer.floatChannelData else {
            throw NSError(
                domain: "NativeAnalysisAudioDecoderTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not construct AVAudio PCM test fixture"]
            )
        }
        buffer.frameLength = AVAudioFrameCount(frames)
        var expected = Array(repeating: [Float](repeating: 0, count: frames), count: Int(channels))
        for channel in 0..<Int(channels) {
            for frame in 0..<frames {
                let value = Float(channel + 1) * Float(frame % 97) / 100.0
                data[channel][frame] = value
                expected[channel][frame] = value
            }
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        try file.write(from: buffer)
        file.close()
        return (url, expected)
    }

    func testSupportedExtensionPolicyIsExplicit() {
        XCTAssertEqual(NativeAnalysisAudioDecoder.supportedExtensions, ["wav", "mp3", "m4a"])
    }

    func testRejectsMKVWithoutOpeningIt() async {
        do {
            _ = try await NativeAnalysisAudioDecoder().decode(url: temporaryURL(extension: "mkv"))
            XCTFail("MKV unexpectedly accepted by native decoder")
        } catch let error as NativeAnalysisAudioDecoderError {
            XCTAssertEqual(error, .unsupportedFormat)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRejectsMP4WithoutOpeningIt() async {
        do {
            _ = try await NativeAnalysisAudioDecoder().decode(url: temporaryURL(extension: "mp4"))
            XCTFail("MP4 unexpectedly accepted by native decoder")
        } catch let error as NativeAnalysisAudioDecoderError {
            XCTAssertEqual(error, .unsupportedFormat)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMissingSupportedFileIsUnreadable() async {
        do {
            _ = try await NativeAnalysisAudioDecoder().decode(url: temporaryURL(extension: "wav"))
            XCTFail("Missing WAV unexpectedly decoded")
        } catch let error as NativeAnalysisAudioDecoderError {
            XCTAssertEqual(error, .unreadableAudio)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMonoWAVIsDuplicatedToStereoExactly() async throws {
        let (url, expected) = try writeWAV(channels: 1, sampleRate: 44_100, frames: 1_003)
        defer { try? FileManager.default.removeItem(at: url) }
        let pcm = try await NativeAnalysisAudioDecoder().decode(url: url)
        XCTAssertEqual(pcm.sampleRate, 44_100)
        XCTAssertEqual(pcm.frameCount, 1_003)
        XCTAssertEqual(pcm.left, expected[0])
        XCTAssertEqual(pcm.right, expected[0])
    }

    func testStereoWAVPreservesChannelsExactly() async throws {
        let (url, expected) = try writeWAV(channels: 2, sampleRate: 48_000, frames: 2_057)
        defer { try? FileManager.default.removeItem(at: url) }
        let pcm = try await NativeAnalysisAudioDecoder().decode(url: url)
        XCTAssertEqual(pcm.sampleRate, 48_000)
        XCTAssertEqual(pcm.frameCount, 2_057)
        XCTAssertEqual(pcm.left, expected[0])
        XCTAssertEqual(pcm.right, expected[1])
    }

    func testThreeChannelPolicyIsRejectedWithoutFixtureSkip() {
        XCTAssertThrowsError(try NativeAnalysisAudioDecoder.validateChannelCount(3)) {
            XCTAssertEqual($0 as? NativeAnalysisAudioDecoderError, .unsupportedChannelCount(3))
        }
    }

    func testMultiChunkWAVDecodesCompletely() async throws {
        let frames = Int(NativeAnalysisAudioDecoder.readChunkFrames) * 2 + 137
        let (url, expected) = try writeWAV(channels: 2, sampleRate: 44_100, frames: frames)
        defer { try? FileManager.default.removeItem(at: url) }
        let pcm = try await NativeAnalysisAudioDecoder().decode(url: url)
        XCTAssertEqual(pcm.frameCount, frames)
        XCTAssertEqual(pcm.left, expected[0])
        XCTAssertEqual(pcm.right, expected[1])
    }

    func testPreCancelledDecodeThrowsCancellation() async throws {
        let (url, _) = try writeWAV(channels: 2, sampleRate: 44_100, frames: 512)
        defer { try? FileManager.default.removeItem(at: url) }
        let task = Task { try await NativeAnalysisAudioDecoder().decode(url: url) }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Pre-cancelled decode unexpectedly succeeded")
        } catch is CancellationError {
            // Expected.
        }
    }

    func testRepeatedDecodeIsDeterministic() async throws {
        let (url, _) = try writeWAV(channels: 2, sampleRate: 32_000, frames: 777)
        defer { try? FileManager.default.removeItem(at: url) }
        let decoder = NativeAnalysisAudioDecoder()
        let first = try await decoder.decode(url: url)
        let second = try await decoder.decode(url: url)
        XCTAssertEqual(first, second)
    }
}
