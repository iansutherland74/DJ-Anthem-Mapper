import Foundation
import AVFAudio

enum NativeAnalysisAudioDecoderError: Error, Equatable, Sendable {
    case unsupportedFormat
    case unreadableAudio
    case unsupportedChannelCount(UInt32)
    case invalidSampleRate
    case emptyAudio
    case decodeFailed
}

struct NativeAnalysisAudioDecoder: Sendable {
    static let supportedExtensions: Set<String> = ["wav", "mp3", "m4a"]
    static let readChunkFrames: AVAudioFrameCount = 65_536

    static func validateChannelCount(_ channels: AVAudioChannelCount) throws {
        guard channels == 1 || channels == 2 else {
            throw NativeAnalysisAudioDecoderError.unsupportedChannelCount(channels)
        }
    }

    func decode(url: URL) async throws -> AnalysisAudioPCM {
        try Task.checkCancellation()
        guard Self.supportedExtensions.contains(url.pathExtension.lowercased()) else {
            throw NativeAnalysisAudioDecoderError.unsupportedFormat
        }

        let file: AVAudioFile
        do {
            file = try AVAudioFile(
                forReading: url,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
        } catch {
            throw NativeAnalysisAudioDecoderError.unreadableAudio
        }

        let format = file.processingFormat
        let channels = format.channelCount
        try Self.validateChannelCount(channels)
        guard format.sampleRate.isFinite,
              format.sampleRate > 0,
              format.sampleRate <= Double(UInt32.max) else {
            throw NativeAnalysisAudioDecoderError.invalidSampleRate
        }
        let roundedRate = format.sampleRate.rounded()
        guard abs(format.sampleRate - roundedRate) < 0.001 else {
            throw NativeAnalysisAudioDecoderError.invalidSampleRate
        }
        let sampleRate = UInt32(roundedRate)

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: Self.readChunkFrames
        ) else {
            throw NativeAnalysisAudioDecoderError.decodeFailed
        }

        var left: [Float] = []
        var right: [Float] = []
        if file.length > 0, file.length <= AVAudioFramePosition(Int.max) {
            left.reserveCapacity(Int(file.length))
            right.reserveCapacity(Int(file.length))
        }

        do {
            while file.framePosition < file.length {
                try Task.checkCancellation()
                let remaining = file.length - file.framePosition
                let requestedFrames = AVAudioFrameCount(
                    min(AVAudioFramePosition(Self.readChunkFrames), remaining)
                )
                guard requestedFrames > 0 else { break }

                buffer.frameLength = 0
                try file.read(into: buffer, frameCount: requestedFrames)
                let frameCount = Int(buffer.frameLength)
                guard frameCount > 0 else {
                    throw NativeAnalysisAudioDecoderError.decodeFailed
                }
                guard let channelData = buffer.floatChannelData else {
                    throw NativeAnalysisAudioDecoderError.decodeFailed
                }

                left.append(contentsOf: UnsafeBufferPointer(start: channelData[0], count: frameCount))
                if channels == 1 {
                    right.append(contentsOf: UnsafeBufferPointer(start: channelData[0], count: frameCount))
                } else {
                    right.append(contentsOf: UnsafeBufferPointer(start: channelData[1], count: frameCount))
                }
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as NativeAnalysisAudioDecoderError {
            throw error
        } catch {
            throw NativeAnalysisAudioDecoderError.decodeFailed
        }

        try Task.checkCancellation()
        guard !left.isEmpty else { throw NativeAnalysisAudioDecoderError.emptyAudio }
        do {
            return try AnalysisAudioPCM(left: left, right: right, sampleRate: sampleRate)
        } catch {
            throw NativeAnalysisAudioDecoderError.decodeFailed
        }
    }
}
