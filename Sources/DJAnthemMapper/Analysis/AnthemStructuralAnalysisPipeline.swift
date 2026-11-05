import Foundation

struct AnthemStructuralAnalysisConfiguration: Equatable, Sendable {
    var candidateConfiguration = AnthemAnalysisConfiguration()
    var provisionalCandidateCount: Int = 20
    var repetitionConfiguration = AnthemRepetitionConfiguration()
    var compositeConfiguration = AnthemCompositeScoringConfiguration()

    var isValid: Bool {
        candidateConfiguration.isValid &&
        provisionalCandidateCount > 0 &&
        provisionalCandidateCount >= candidateConfiguration.maximumCandidateCount &&
        repetitionConfiguration.isValid &&
        compositeConfiguration.isValid
    }
}

enum AnthemStructuralAnalysisStatus: Equatable, Sendable {
    case analysed
    case noCandidates
    case invalidInput
}

struct AnthemStructuralAnalysisCandidate: Equatable, Sendable {
    let candidate: AnthemCandidate
    let energyEvidence: AnthemCandidateEvidence
    let structuralEvidence: AnthemStructuralEvidence?
    let originalScore: Float
    let structuralStrength: Float
    let compositeScore: Float
}

struct AnthemStructuralAnalysisResult: Equatable, Sendable {
    let status: AnthemStructuralAnalysisStatus
    let candidates: [AnthemStructuralAnalysisCandidate]
}

enum AnthemStructuralAnalysisPipeline {
    static func analyse(
        waveformSamples: [Float],
        trackDuration: TimeInterval,
        configuration: AnthemStructuralAnalysisConfiguration = .init()
    ) -> AnthemStructuralAnalysisResult {
        guard configuration.isValid,
              trackDuration.isFinite, trackDuration > 0,
              !waveformSamples.isEmpty else {
            return .init(status: .invalidInput, candidates: [])
        }

        let frames = AnthemAnalysisFoundation.frames(from: waveformSamples, trackDuration: trackDuration)
        guard !frames.isEmpty else { return .init(status: .noCandidates, candidates: []) }

        let candidates = AnthemCandidateScorer.rankedCandidates(
            from: frames,
            preferredDuration: configuration.candidateConfiguration.preferredCandidateDuration,
            maximumCount: configuration.provisionalCandidateCount,
            maximumOverlapRatio: configuration.candidateConfiguration.maximumOverlapRatio,
            minimumCoverageRatio: configuration.candidateConfiguration.minimumCandidateCoverageRatio
        )
        guard !candidates.isEmpty else { return .init(status: .noCandidates, candidates: []) }

        let energyEvidence = candidates.compactMap {
            AnthemCandidateEvidenceAnalyser.analyse(candidate: $0, frames: frames)
        }
        let transitions = AnthemEnergyTransitionAnalyser.analyse(frames: frames)
        let repetitions = AnthemRepetitionAnalyser.analyse(frames: frames, configuration: configuration.repetitionConfiguration)
        let structuralEvidence = candidates.compactMap {
            AnthemStructuralEvidenceAnalyser.analyse(candidate: $0, frames: frames, transitions: transitions, repetitions: repetitions)
        }
        let composite = AnthemCompositeCandidateScorer.rank(
            candidates: candidates,
            structuralEvidence: structuralEvidence,
            configuration: configuration.compositeConfiguration
        )

        let final = composite
            .prefix(configuration.candidateConfiguration.maximumCandidateCount)
            .compactMap { item -> AnthemStructuralAnalysisCandidate? in
                guard let energy = energyEvidence.first(where: { $0.candidate == item.candidate }) else { return nil }
                return .init(
                    candidate: item.candidate,
                    energyEvidence: energy,
                    structuralEvidence: item.structuralEvidence,
                    originalScore: item.originalScore,
                    structuralStrength: item.structuralStrength,
                    compositeScore: item.compositeScore
                )
            }

        return .init(status: final.isEmpty ? .noCandidates : .analysed, candidates: final)
    }
}
