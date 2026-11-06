import Foundation

struct AnthemVocalAdjustmentConfiguration: Equatable, Sendable {
    var maximumAdjustment: Float = 0.10
    var neutralStrength: Float = 0.50

    var isValid: Bool {
        maximumAdjustment.isFinite && neutralStrength.isFinite &&
        maximumAdjustment >= 0 && maximumAdjustment <= 1 &&
        neutralStrength > 0 && neutralStrength < 1
    }
}

struct AnthemVocalAdjustedCompositeCandidate: Equatable, Sendable {
    let baseline: AnthemCompositeCandidate
    let vocalScore: AnthemVocalCandidateScore?
    let vocalAdjustment: Float
    let adjustedCompositeScore: Float
}

enum AnthemVocalAdjustedCompositeScorer {
    static func rank(
        baseline: [AnthemCompositeCandidate],
        vocalEvidence: [AnthemCandidateVocalEvidence],
        configuration: AnthemVocalAdjustmentConfiguration = .init()
    ) -> [AnthemVocalAdjustedCompositeCandidate] {
        guard configuration.isValid else { return [] }
        let scored = baseline.map { item -> AnthemVocalAdjustedCompositeCandidate in
            let evidence = vocalEvidence.first {
                $0.candidateStartTime == item.candidate.startTime &&
                $0.candidateEndTime == item.candidate.endTime
            }
            let hasVocalEvidence = evidence.map { !$0.transitionEvidence.isEmpty || !$0.sustainedEvidence.isEmpty } ?? false
            let vocalScore = hasVocalEvidence ? evidence.map(AnthemVocalCandidateScorer.score) : nil
            let adjustment = vocalScore.map {
                boundedAdjustment(strength: $0.overallStrength, configuration: configuration)
            } ?? 0
            return .init(
                baseline: item,
                vocalScore: vocalScore,
                vocalAdjustment: adjustment,
                adjustedCompositeScore: clamp(item.compositeScore + adjustment)
            )
        }
        return scored.sorted(by: rankedBefore)
    }

    private static func boundedAdjustment(strength: Float, configuration: AnthemVocalAdjustmentConfiguration) -> Float {
        let strength = clamp(strength)
        let neutral = configuration.neutralStrength
        let raw: Float
        if strength >= neutral {
            raw = ((strength - neutral) / (1 - neutral)) * configuration.maximumAdjustment
        } else {
            raw = -((neutral - strength) / neutral) * configuration.maximumAdjustment
        }
        return min(configuration.maximumAdjustment, max(-configuration.maximumAdjustment, raw))
    }

    private static func rankedBefore(_ lhs: AnthemVocalAdjustedCompositeCandidate, _ rhs: AnthemVocalAdjustedCompositeCandidate) -> Bool {
        if lhs.adjustedCompositeScore != rhs.adjustedCompositeScore { return lhs.adjustedCompositeScore > rhs.adjustedCompositeScore }
        if lhs.baseline.compositeScore != rhs.baseline.compositeScore { return lhs.baseline.compositeScore > rhs.baseline.compositeScore }
        if lhs.baseline.originalScore != rhs.baseline.originalScore { return lhs.baseline.originalScore > rhs.baseline.originalScore }
        if lhs.baseline.structuralStrength != rhs.baseline.structuralStrength { return lhs.baseline.structuralStrength > rhs.baseline.structuralStrength }
        if lhs.baseline.candidate.startTime != rhs.baseline.candidate.startTime { return lhs.baseline.candidate.startTime < rhs.baseline.candidate.startTime }
        return lhs.baseline.candidate.endTime < rhs.baseline.candidate.endTime
    }

    private static func clamp(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }
}
