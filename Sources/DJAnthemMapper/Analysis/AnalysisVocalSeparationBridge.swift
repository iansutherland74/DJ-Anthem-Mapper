import Foundation

@MainActor
protocol AnalysisAudioDecoding: AnyObject {
    func decode(request: AnalysisAudioDecodeRequest) async throws -> AnalysisAudioPCM
}

@MainActor
protocol AnalysisVocalSeparating: AnyObject {
    func separate(left: [Float], right: [Float], sampleRate: UInt32) async throws -> VocalSeparationPCM
}

@MainActor
final class AnalysisVocalSeparationBridge {
    private let decode: (AnalysisAudioDecodeRequest) async throws -> AnalysisAudioPCM
    private let separate: ([Float], [Float], UInt32) async throws -> VocalSeparationPCM

    init(
        decode: @escaping (AnalysisAudioDecodeRequest) async throws -> AnalysisAudioPCM,
        separate: @escaping ([Float], [Float], UInt32) async throws -> VocalSeparationPCM
    ) {
        self.decode = decode
        self.separate = separate
    }

    func separateVocals(request: AnalysisAudioDecodeRequest) async throws -> VocalSeparationPCM {
        try Task.checkCancellation()
        let pcm = try await decode(request)
        try Task.checkCancellation()
        return try await separate(pcm.left, pcm.right, pcm.sampleRate)
    }
}
