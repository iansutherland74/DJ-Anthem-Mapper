import Foundation

enum AnalysisAudioDecoderError: Error, Equatable, Sendable {
    case unsupportedFormat
    case missingAudioStreamID
    case nativeDecodeFailed
    case containerDecodeFailed
}

struct AnalysisAudioDecodeRequest: Equatable, Sendable {
    let sourceURL: URL
    let absoluteAudioStreamIndex: Int?

    init(sourceURL: URL, absoluteAudioStreamIndex: Int? = nil) {
        self.sourceURL = sourceURL
        self.absoluteAudioStreamIndex = absoluteAudioStreamIndex
    }
}

struct AnalysisAudioDecoder: Sendable {
    typealias NativeDecode = @Sendable (URL) async throws -> AnalysisAudioPCM
    typealias ContainerDecode = @Sendable (URL, Int) async throws -> AnalysisAudioPCM

    private let nativeDecode: NativeDecode
    private let containerDecode: ContainerDecode

    init(
        nativeDecode: @escaping NativeDecode = { url in
            try await NativeAnalysisAudioDecoder().decode(url: url)
        },
        containerDecode: @escaping ContainerDecode = { url, streamID in
            let request = try FFmpegAnalysisAudioDecodeRequest(
                sourceURL: url,
                absoluteStreamIndex: streamID
            )
            return try await FFmpegAnalysisAudioDecoder().decode(request: request)
        }
    ) {
        self.nativeDecode = nativeDecode
        self.containerDecode = containerDecode
    }

    func decode(request: AnalysisAudioDecodeRequest) async throws -> AnalysisAudioPCM {
        try Task.checkCancellation()

        switch request.sourceURL.pathExtension.lowercased() {
        case "wav", "mp3", "m4a":
            do {
                return try await nativeDecode(request.sourceURL)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw AnalysisAudioDecoderError.nativeDecodeFailed
            }

        case "mp4", "mkv":
            guard let streamID = request.absoluteAudioStreamIndex else {
                throw AnalysisAudioDecoderError.missingAudioStreamID
            }
            do {
                return try await containerDecode(request.sourceURL, streamID)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw AnalysisAudioDecoderError.containerDecodeFailed
            }

        default:
            throw AnalysisAudioDecoderError.unsupportedFormat
        }
    }
}
