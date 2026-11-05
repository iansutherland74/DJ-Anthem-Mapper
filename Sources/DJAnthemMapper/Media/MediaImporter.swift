import Foundation

protocol MediaImporting {
    func inspect(url: URL, completion: @escaping (Result<MediaDescription, MediaImportError>) -> Void)
}

enum MediaImportError: LocalizedError {
    case unsupportedFormat
    case ffprobeNotFound
    case launchFailed(String)
    case inspectionFailed(String)
    case invalidResponse
    case noAudio

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "DJ Anthem Mapper currently supports MP3, M4A, MP4, MKV and WAV."
        case .ffprobeNotFound: return "FFprobe could not be found in /usr/local/bin or /opt/homebrew/bin."
        case .launchFailed(let detail): return "FFprobe could not be launched: \(detail)"
        case .inspectionFailed(let detail): return detail.isEmpty ? "The media file could not be inspected." : detail
        case .invalidResponse: return "FFprobe returned media information that could not be read."
        case .noAudio: return "This file contains no usable audio stream."
        }
    }
}

private struct FFprobeResponse: Decodable {
    let streams: [FFprobeStream]?
    let format: FFprobeFormat?
}

private struct FFprobeFormat: Decodable {
    let formatName: String?
    let duration: String?
    let bitRate: String?
    let tags: [String: String]?

    enum CodingKeys: String, CodingKey {
        case formatName = "format_name"
        case duration
        case bitRate = "bit_rate"
        case tags
    }
}

private struct FFprobeDisposition: Decodable {
    let `default`: Int?
    let commentary: Int?
}

private struct FFprobeStream: Decodable {
    let index: Int?
    let codecType: String?
    let codecName: String?
    let codecLongName: String?
    let sampleRate: String?
    let channels: Int?
    let channelLayout: String?
    let bitRate: String?
    let tags: [String: String]?
    let disposition: FFprobeDisposition?

    enum CodingKeys: String, CodingKey {
        case index
        case codecType = "codec_type"
        case codecName = "codec_name"
        case codecLongName = "codec_long_name"
        case sampleRate = "sample_rate"
        case channels
        case channelLayout = "channel_layout"
        case bitRate = "bit_rate"
        case tags
        case disposition
    }
}

final class FFprobeMediaImporter: MediaImporting {
    func inspect(url: URL, completion: @escaping (Result<MediaDescription, MediaImportError>) -> Void) {
        let allowed = ["mp3", "m4a", "mp4", "mkv", "wav"]
        guard allowed.contains(url.pathExtension.lowercased()) else {
            completion(.failure(.unsupportedFormat))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let paths = ["/usr/local/bin/ffprobe", "/opt/homebrew/bin/ffprobe"]
            guard let executable = paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
                DispatchQueue.main.async { completion(.failure(.ffprobeNotFound)) }
                return
            }

            let process = Process()
            let output = Pipe()
            let errors = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = [
                "-v", "error",
                "-show_format",
                "-show_streams",
                "-of", "json",
                url.path
            ]
            process.standardOutput = output
            process.standardError = errors

            do {
                try process.run()
            } catch {
                DispatchQueue.main.async { completion(.failure(.launchFailed(error.localizedDescription))) }
                return
            }

            process.waitUntilExit()
            let stdout = output.fileHandleForReading.readDataToEndOfFile()
            let stderr = errors.fileHandleForReading.readDataToEndOfFile()
            let errorText = String(data: stderr, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard process.terminationStatus == 0 else {
                DispatchQueue.main.async { completion(.failure(.inspectionFailed(errorText))) }
                return
            }

            do {
                let response = try JSONDecoder().decode(FFprobeResponse.self, from: stdout)
                let streams = response.streams ?? []
                let audio = streams.filter { $0.codecType == "audio" }.map { stream in
                    AudioStreamDescription(
                        id: stream.index ?? 0,
                        codecName: stream.codecName?.uppercased() ?? "Unknown",
                        codecLongName: stream.codecLongName,
                        sampleRate: stream.sampleRate.flatMap(Int.init),
                        channels: stream.channels,
                        channelLayout: stream.channelLayout,
                        bitRate: stream.bitRate.flatMap(Int.init),
                        language: Self.tag("language", in: stream.tags),
                        title: Self.tag("title", in: stream.tags),
                        isDefault: stream.disposition?.default == 1,
                        isCommentary: stream.disposition?.commentary == 1
                    )
                }

                guard !audio.isEmpty else {
                    DispatchQueue.main.async { completion(.failure(.noAudio)) }
                    return
                }

                let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
                let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
                let tags = response.format?.tags
                let description = MediaDescription(
                    sourceURL: url,
                    fileSize: size,
                    container: response.format?.formatName?.uppercased() ?? url.pathExtension.uppercased(),
                    duration: response.format?.duration.flatMap(Double.init),
                    overallBitRate: response.format?.bitRate.flatMap(Int.init),
                    metadata: MediaMetadata(
                        title: Self.tag("title", in: tags),
                        artist: Self.tag("artist", in: tags),
                        album: Self.tag("album", in: tags),
                        genre: Self.tag("genre", in: tags)
                    ),
                    audioStreams: audio,
                    hasVideo: streams.contains(where: { $0.codecType == "video" })
                )
                DispatchQueue.main.async { completion(.success(description)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(.invalidResponse)) }
            }
        }
    }

    private static func tag(_ name: String, in tags: [String: String]?) -> String? {
        tags?.first(where: { $0.key.caseInsensitiveCompare(name) == .orderedSame })?.value
    }
}
