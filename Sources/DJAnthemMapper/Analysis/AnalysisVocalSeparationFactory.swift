import Foundation

@MainActor
enum AnalysisVocalSeparationFactory {
    typealias Decode =
        (AnalysisAudioDecodeRequest) async throws -> AnalysisAudioPCM

    typealias Separate =
        ([Float], [Float], UInt32) async throws -> VocalSeparationPCM

    static func makeProduction() -> AnalysisVocalSeparationBridge {
        let decoder = AnalysisAudioDecoder()
        let separator = HTDemucsVocalSeparator()

        return AnalysisVocalSeparationBridge(
            decode: { request in
                try await decoder.decode(request: request)
            },
            separate: { left, right, sampleRate in
                try await separator.separate(
                    left: left,
                    right: right,
                    sampleRate: sampleRate
                )
            }
        )
    }

    static func make(
        decode: @escaping Decode,
        separate: @escaping Separate
    ) -> AnalysisVocalSeparationBridge {
        AnalysisVocalSeparationBridge(
            decode: decode,
            separate: separate
        )
    }
}
