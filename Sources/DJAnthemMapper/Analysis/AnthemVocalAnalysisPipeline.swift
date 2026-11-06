import Foundation

enum AnthemVocalAnalysisPipelineStatus: Equatable, Sendable {
    case adjusted
    case structuralFallback
    case noCandidates
    case invalidInput
}

struct AnthemVocalAnalysisCandidate: Equatable, Sendable {
    let baseline: AnthemStructuralAnalysisCandidate
    let vocalEvidence: AnthemCandidateVocalEvidence?
    let vocalScore: AnthemVocalCandidateScore?
    let vocalAdjustment: Float
    let finalScore: Float
}

struct AnthemVocalAnalysisPipelineResult: Equatable, Sendable {
    let status: AnthemVocalAnalysisPipelineStatus
    let candidates: [AnthemVocalAnalysisCandidate]
}

@MainActor
enum AnthemVocalAnalysisPipeline {
    typealias SeparateVocals = (AnalysisAudioDecodeRequest) async throws -> VocalSeparationPCM

    static func analyse(
        waveformSamples: [Float],
        trackDuration: TimeInterval,
        request: AnalysisAudioDecodeRequest,
        structuralConfiguration: AnthemStructuralAnalysisConfiguration = .init(),
        vocalAdjustmentConfiguration: AnthemVocalAdjustmentConfiguration = .init(),
        separateVocals: SeparateVocals
    ) async throws -> AnthemVocalAnalysisPipelineResult {
        let structural = AnthemStructuralAnalysisPipeline.analyse(
            waveformSamples: waveformSamples,
            trackDuration: trackDuration,
            configuration: structuralConfiguration
        )

        switch structural.status {
        case .invalidInput:
            return .init(status: .invalidInput, candidates: [])
        case .noCandidates:
            return .init(status: .noCandidates, candidates: [])
        case .analysed:
            break
        }

        try Task.checkCancellation()

        do {
            let vocalPCM = try await separateVocals(request)
            try Task.checkCancellation()

            let frames = AnthemVocalAnalysisTimeline.frames(from: vocalPCM)
            guard !frames.isEmpty else { return structuralFallback(structural) }
            let hasUsefulVocalSignal = frames.contains { $0.energy > 0 || $0.activity > 0 }
            guard hasUsefulVocalSignal else { return structuralFallback(structural) }
            let transitions = AnthemVocalTransitionAnalyser.analyse(frames: frames)
            let sustained = AnthemSustainedVocalAnalyser.analyse(frames: frames)

            let associated = structural.candidates.compactMap { item -> AnthemCandidateVocalEvidence? in
                AnthemVocalEvidenceAssociation.associate(
                    candidateStartTime: item.candidate.startTime,
                    candidateEndTime: item.candidate.endTime,
                    transitionEvidence: transitions,
                    sustainedEvidence: sustained
                )
            }

            let baseline = structural.candidates.map { item in
                AnthemCompositeCandidate(
                    candidate: item.candidate,
                    structuralEvidence: item.structuralEvidence,
                    originalScore: item.originalScore,
                    structuralStrength: item.structuralStrength,
                    compositeScore: item.compositeScore
                )
            }

            let adjusted = AnthemVocalAdjustedCompositeScorer.rank(
                baseline: baseline,
                vocalEvidence: associated,
                configuration: vocalAdjustmentConfiguration
            )
            guard adjusted.count == structural.candidates.count else { return structuralFallback(structural) }

            let final = adjusted.compactMap { item -> AnthemVocalAnalysisCandidate? in
                guard let source = structural.candidates.first(where: { $0.candidate == item.baseline.candidate }) else { return nil }
                let evidence = associated.first {
                    $0.candidateStartTime == source.candidate.startTime && $0.candidateEndTime == source.candidate.endTime
                }
                return .init(
                    baseline: source,
                    vocalEvidence: evidence,
                    vocalScore: item.vocalScore,
                    vocalAdjustment: item.vocalAdjustment,
                    finalScore: item.adjustedCompositeScore
                )
            }
            guard final.count == structural.candidates.count else { return structuralFallback(structural) }
            let hasAdjustment = final.contains { $0.vocalScore != nil }
            return .init(status: hasAdjustment ? .adjusted : .structuralFallback, candidates: final)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return structuralFallback(structural)
        }
    }

    static func analyse(
        waveformSamples: [Float],
        trackDuration: TimeInterval,
        request: AnalysisAudioDecodeRequest,
        structuralConfiguration: AnthemStructuralAnalysisConfiguration = .init(),
        vocalAdjustmentConfiguration: AnthemVocalAdjustmentConfiguration = .init(),
        bridge: AnalysisVocalSeparationBridge
    ) async throws -> AnthemVocalAnalysisPipelineResult {
        try await analyse(
            waveformSamples: waveformSamples,
            trackDuration: trackDuration,
            request: request,
            structuralConfiguration: structuralConfiguration,
            vocalAdjustmentConfiguration: vocalAdjustmentConfiguration,
            separateVocals: { request in try await bridge.separateVocals(request: request) }
        )
    }

    private static func structuralFallback(_ structural: AnthemStructuralAnalysisResult) -> AnthemVocalAnalysisPipelineResult {
        .init(
            status: .structuralFallback,
            candidates: structural.candidates.map {
                .init(baseline: $0, vocalEvidence: nil, vocalScore: nil, vocalAdjustment: 0, finalScore: $0.compositeScore)
            }
        )
    }
}
