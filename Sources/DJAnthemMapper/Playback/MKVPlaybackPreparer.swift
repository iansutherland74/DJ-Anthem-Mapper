@preconcurrency import Foundation

enum MKVPlaybackPreparationError: LocalizedError, Sendable {
    case ffmpegNotFound
    case extractionFailed(String)
    case outputMissing

    var errorDescription: String? {
        switch self {
        case .ffmpegNotFound:
            return "FFmpeg could not be found in /opt/homebrew/bin or /usr/local/bin."
        case .extractionFailed(let detail):
            return detail.isEmpty ? "FFmpeg could not prepare the selected MKV audio track." : detail
        case .outputMissing:
            return "FFmpeg finished without creating the playback audio file."
        }
    }
}

struct MKVPlaybackPreparer {
    static func prepare(
        sourceURL: URL,
        absoluteStreamIndex: Int,
        completion: @escaping @MainActor @Sendable (Result<URL, MKVPlaybackPreparationError>) -> Void
    ) {
        let candidates = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]
        guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            Task { @MainActor in
                completion(.failure(.ffmpegNotFound))
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let manager = FileManager.default
            let cacheDirectory = manager.temporaryDirectory.appendingPathComponent(
                "DJAnthemMapperPlayback",
                isDirectory: true
            )

            do {
                if manager.fileExists(atPath: cacheDirectory.path) {
                    try manager.removeItem(at: cacheDirectory)
                }
                try manager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            } catch {
                Task { @MainActor in
                    completion(.failure(.extractionFailed(error.localizedDescription)))
                }
                return
            }

            let outputURL = cacheDirectory.appendingPathComponent(
                "stream-\(absoluteStreamIndex)-\(UUID().uuidString).wav"
            )
            let process = Process()
            let errorPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = [
                "-hide_banner", "-nostdin", "-y", "-v", "error",
                "-i", sourceURL.path,
                "-map", "0:\(absoluteStreamIndex)",
                "-vn", "-sn", "-dn",
                "-c:a", "pcm_s16le",
                outputURL.path
            ]
            process.standardOutput = Pipe()
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                Task { @MainActor in
                    completion(.failure(.extractionFailed(error.localizedDescription)))
                }
                return
            }

            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let detail = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            let result: Result<URL, MKVPlaybackPreparationError>
            if process.terminationStatus != 0 {
                result = .failure(.extractionFailed(detail))
            } else if !manager.fileExists(atPath: outputURL.path) {
                result = .failure(.outputMissing)
            } else {
                result = .success(outputURL)
            }

            Task { @MainActor in completion(result) }
        }
    }
}
