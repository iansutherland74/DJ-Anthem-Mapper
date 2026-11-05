import Foundation

struct AnthemAnalysisConfiguration: Equatable, Sendable {
    var preferredCandidateDuration: TimeInterval = 20
    var maximumCandidateCount: Int = 5
    var maximumOverlapRatio: Double = 0.50
    var minimumCandidateCoverageRatio: Double = 0.75

    var isValid: Bool {
        preferredCandidateDuration.isFinite && preferredCandidateDuration > 0 &&
        maximumCandidateCount > 0 &&
        maximumOverlapRatio.isFinite &&
        (0...1).contains(maximumOverlapRatio) &&
        minimumCandidateCoverageRatio.isFinite &&
        minimumCandidateCoverageRatio > 0 &&
        minimumCandidateCoverageRatio <= 1
    }
}

struct AnalysedAnthemCandidate: Equatable, Sendable {
    let candidate: AnthemCandidate
    let evidence: AnthemCandidateEvidence
}

enum AnthemAnalysisPipelineStatus: Equatable, Sendable {
    case analysed
    case noCandidates
    case invalidInput
}

struct AnthemAnalysisPipelineResult: Equatable, Sendable {
    let status: AnthemAnalysisPipelineStatus
    let candidates: [AnalysedAnthemCandidate]
}

enum AnthemAnalysisPipeline {
    static func analyse(
        waveformSamples: [Float],
        trackDuration: TimeInterval,
        configuration: AnthemAnalysisConfiguration = .init()
    ) -> AnthemAnalysisPipelineResult {
        guard configuration.isValid,
              trackDuration.isFinite, trackDuration > 0,
              !waveformSamples.isEmpty else {
            return .init(status: .invalidInput, candidates: [])
        }

        let frames = AnthemAnalysisFoundation.frames(
            from: waveformSamples,
            trackDuration: trackDuration
        )
        guard let inputQuality = AnthemAnalysisInputQualityAnalyser.analyse(frames: frames),
              inputQuality.hasMeaningfulSignal else {
            return .init(status: .noCandidates, candidates: [])
        }

        guard !frames.isEmpty else {
            return .init(status: .noCandidates, candidates: [])
        }

        let candidates = AnthemCandidateScorer.rankedCandidates(
            from: frames,
            preferredDuration: configuration.preferredCandidateDuration,
            maximumCount: configuration.maximumCandidateCount,
            maximumOverlapRatio: configuration.maximumOverlapRatio,
            minimumCoverageRatio: configuration.minimumCandidateCoverageRatio
        )

        let analysed = candidates.compactMap { candidate -> AnalysedAnthemCandidate? in
            guard let evidence = AnthemCandidateEvidenceAnalyser.analyse(
                candidate: candidate,
                frames: frames
            ) else { return nil }
            return .init(candidate: candidate, evidence: evidence)
        }

        return .init(
            status: analysed.isEmpty ? .noCandidates : .analysed,
            candidates: analysed
        )
    }
}
