import Foundation

struct AnthemCompositeScoringConfiguration: Equatable, Sendable {
    var candidateWeight: Float = 0.65
    var structuralWeight: Float = 0.35

    var isValid: Bool {
        candidateWeight.isFinite && structuralWeight.isFinite &&
        candidateWeight >= 0 && structuralWeight >= 0 &&
        candidateWeight + structuralWeight > 0
    }

    var normalisedWeights: (candidate: Float, structural: Float)? {
        guard isValid else { return nil }
        let total = candidateWeight + structuralWeight
        return (candidateWeight / total, structuralWeight / total)
    }
}

struct AnthemCompositeCandidate: Equatable, Sendable {
    let candidate: AnthemCandidate
    let structuralEvidence: AnthemStructuralEvidence?
    let originalScore: Float
    let structuralStrength: Float
    let compositeScore: Float
}

enum AnthemCompositeCandidateScorer {
    static func rank(
        candidates: [AnthemCandidate],
        structuralEvidence: [AnthemStructuralEvidence],
        configuration: AnthemCompositeScoringConfiguration = .init()
    ) -> [AnthemCompositeCandidate] {
        guard let weights = configuration.normalisedWeights else { return [] }

        let scored = candidates.compactMap { candidate -> AnthemCompositeCandidate? in
            guard candidate.startTime.isFinite, candidate.endTime.isFinite,
                  candidate.endTime > candidate.startTime,
                  candidate.score.isFinite else { return nil }

            let evidence = structuralEvidence.first { $0.candidate == candidate }
            let original = clamp(candidate.score)
            let structural = clamp(evidence?.structuralStrength ?? 0)
            let composite = clamp(original * weights.candidate + structural * weights.structural)
            return .init(
                candidate: candidate,
                structuralEvidence: evidence,
                originalScore: original,
                structuralStrength: structural,
                compositeScore: composite
            )
        }

        return scored.sorted {
            if $0.compositeScore != $1.compositeScore { return $0.compositeScore > $1.compositeScore }
            if $0.originalScore != $1.originalScore { return $0.originalScore > $1.originalScore }
            if $0.structuralStrength != $1.structuralStrength { return $0.structuralStrength > $1.structuralStrength }
            if $0.candidate.startTime != $1.candidate.startTime { return $0.candidate.startTime < $1.candidate.startTime }
            return $0.candidate.endTime < $1.candidate.endTime
        }
    }

    private static func clamp(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }
}
