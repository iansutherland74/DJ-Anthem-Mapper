import Foundation

enum FFmpegAnalysisAudioDecoderError: Error, Equatable, Sendable {
    case unsupportedFormat
    case invalidStreamID
    case ffmpegNotFound
    case launchFailed
    case decodingFailed
    case emptyAudio
    case malformedPCM
}

struct FFmpegAnalysisAudioDecodeRequest: Equatable, Sendable {
    let sourceURL: URL
    let absoluteStreamIndex: Int
    let sampleRate: UInt32

    init(sourceURL: URL, absoluteStreamIndex: Int, sampleRate: UInt32 = 44_100) throws {
        guard ["mp4", "mkv"].contains(sourceURL.pathExtension.lowercased()) else {
            throw FFmpegAnalysisAudioDecoderError.unsupportedFormat
        }
        guard absoluteStreamIndex >= 0 else {
            throw FFmpegAnalysisAudioDecoderError.invalidStreamID
        }
        guard sampleRate > 0 else {
            throw FFmpegAnalysisAudioDecoderError.decodingFailed
        }
        self.sourceURL = sourceURL
        self.absoluteStreamIndex = absoluteStreamIndex
        self.sampleRate = sampleRate
    }
}

struct FFmpegAnalysisAudioCommand: Equatable, Sendable {
    let executableURL: URL
    let arguments: [String]
    let outputURL: URL
}

struct FFmpegAnalysisAudioCommandBuilder: Sendable {
    static let executablePaths = ["/usr/local/bin/ffmpeg", "/opt/homebrew/bin/ffmpeg"]

    func command(
        request: FFmpegAnalysisAudioDecodeRequest,
        executableURL: URL,
        outputURL: URL
    ) -> FFmpegAnalysisAudioCommand {
        FFmpegAnalysisAudioCommand(
            executableURL: executableURL,
            arguments: [
                "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
                "-i", request.sourceURL.path,
                "-map", "0:\(request.absoluteStreamIndex)",
                "-vn", "-sn", "-dn",
                "-ac", "2",
                "-ar", String(request.sampleRate),
                "-c:a", "pcm_f32le",
                "-f", "f32le",
                outputURL.path
            ],
            outputURL: outputURL
        )
    }
}

struct FFmpegAnalysisAudioDecoder: Sendable {
    typealias Runner = @Sendable (FFmpegAnalysisAudioCommand) async throws -> Data

    private let executableFinder: @Sendable () -> URL?
    private let runner: Runner
    private let commandBuilder: FFmpegAnalysisAudioCommandBuilder

    init(
        executableFinder: @escaping @Sendable () -> URL? = {
            FFmpegAnalysisAudioCommandBuilder.executablePaths
                .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
                .map { URL(fileURLWithPath: $0) }
        },
        runner: Runner? = nil,
        commandBuilder: FFmpegAnalysisAudioCommandBuilder = .init()
    ) {
        self.executableFinder = executableFinder
        self.runner = runner ?? { command in
            try await Self.run(command: command)
        }
        self.commandBuilder = commandBuilder
    }

    func decode(request: FFmpegAnalysisAudioDecodeRequest) async throws -> AnalysisAudioPCM {
        try Task.checkCancellation()
        guard let executable = executableFinder() else {
            throw FFmpegAnalysisAudioDecoderError.ffmpegNotFound
        }
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DJAM-analysis-\(UUID().uuidString).f32le")
        defer { try? FileManager.default.removeItem(at: outputURL) }
        let command = commandBuilder.command(request: request, executableURL: executable, outputURL: outputURL)
        let data = try await runner(command)
        try Task.checkCancellation()
        return try Self.decodeInterleavedStereoFloat32(data: data, sampleRate: request.sampleRate)
    }

    static func decodeInterleavedStereoFloat32(data: Data, sampleRate: UInt32) throws -> AnalysisAudioPCM {
        guard !data.isEmpty else { throw FFmpegAnalysisAudioDecoderError.emptyAudio }
        let bytesPerStereoFrame = MemoryLayout<Float>.size * 2
        guard data.count.isMultiple(of: bytesPerStereoFrame) else {
            throw FFmpegAnalysisAudioDecoderError.malformedPCM
        }
        let frameCount = data.count / bytesPerStereoFrame
        var left = [Float]()
        var right = [Float]()
        left.reserveCapacity(frameCount)
        right.reserveCapacity(frameCount)
        data.withUnsafeBytes { raw in
            for frame in 0..<frameCount {
                let base = frame * bytesPerStereoFrame
                var l: Float = 0
                var r: Float = 0
                _ = withUnsafeMutableBytes(of: &l) { raw.copyBytes(to: $0, from: base..<(base + 4)) }
                _ = withUnsafeMutableBytes(of: &r) { raw.copyBytes(to: $0, from: (base + 4)..<(base + 8)) }
                left.append(l)
                right.append(r)
            }
        }
        do {
            return try AnalysisAudioPCM(left: left, right: right, sampleRate: sampleRate)
        } catch {
            throw FFmpegAnalysisAudioDecoderError.malformedPCM
        }
    }

    private static func run(command: FFmpegAnalysisAudioCommand) async throws -> Data {
        try Task.checkCancellation()
        let process = Process()
        process.executableURL = command.executableURL
        process.arguments = command.arguments
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw FFmpegAnalysisAudioDecoderError.launchFailed
        }
        process.waitUntilExit()
        try Task.checkCancellation()
        guard process.terminationStatus == 0 else {
            throw FFmpegAnalysisAudioDecoderError.decodingFailed
        }
        do {
            return try Data(contentsOf: command.outputURL, options: .mappedIfSafe)
        } catch {
            throw FFmpegAnalysisAudioDecoderError.decodingFailed
        }
    }
}
