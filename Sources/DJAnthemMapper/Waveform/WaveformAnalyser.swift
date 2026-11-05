@preconcurrency import Foundation

enum WaveformAnalysisError: LocalizedError, Sendable {
    case ffmpegNotFound
    case extractionFailed(String)
    case noSamples

    var errorDescription: String? {
        switch self {
        case .ffmpegNotFound:
            return "FFmpeg could not be found for waveform analysis."
        case .extractionFailed(let detail):
            return detail.isEmpty ? "Waveform analysis failed." : detail
        case .noSamples:
            return "No audio samples were available for the waveform."
        }
    }
}

struct WaveformAnalyser {
    static func analyse(
        sourceURL: URL,
        absoluteStreamIndex: Int?,
        targetColumns: Int = 720,
        completion: @escaping @MainActor @Sendable (Result<[Float], WaveformAnalysisError>) -> Void
    ) {
        let candidates = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]
        guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            Task { @MainActor in completion(.failure(.ffmpegNotFound)) }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            var arguments = ["-hide_banner", "-nostdin", "-v", "error", "-i", sourceURL.path]
            if let absoluteStreamIndex {
                arguments += ["-map", "0:\(absoluteStreamIndex)"]
            } else {
                arguments += ["-map", "0:a:0"]
            }
            arguments += ["-vn", "-sn", "-dn", "-ac", "1", "-ar", "400", "-f", "s16le", "-acodec", "pcm_s16le", "pipe:1"]
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                let sampleData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let detail = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard process.terminationStatus == 0 else {
                    Task { @MainActor in completion(.failure(.extractionFailed(detail))) }
                    return
                }
                guard sampleData.count >= 2 else {
                    Task { @MainActor in completion(.failure(.noSamples)) }
                    return
                }

                let sampleCount = sampleData.count / 2
                let columns = max(64, min(targetColumns, sampleCount))
                let samplesPerColumn = max(1, sampleCount / columns)
                var peaks = [Float]()
                peaks.reserveCapacity(columns)

                sampleData.withUnsafeBytes { rawBuffer in
                    let bytes = rawBuffer.bindMemory(to: UInt8.self)
                    for column in 0..<columns {
                        let start = column * samplesPerColumn
                        let end = min(sampleCount, start + samplesPerColumn)
                        var peak: Int32 = 0
                        if start < end {
                            for index in start..<end {
                                let offset = index * 2
                                let word = UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
                                let signed = Int16(bitPattern: word)
                                let amplitude = signed == Int16.min ? Int32(Int16.max) : abs(Int32(signed))
                                if amplitude > peak { peak = amplitude }
                            }
                        }
                        peaks.append(Float(peak) / Float(Int16.max))
                    }
                }

                let maximum = peaks.max() ?? 0
                if maximum > 0 {
                    peaks = peaks.map { min(1, max(0.015, $0 / maximum)) }
                }
                Task { @MainActor in completion(.success(peaks)) }
            } catch {
                Task { @MainActor in completion(.failure(.extractionFailed(error.localizedDescription))) }
            }
        }
    }
}
