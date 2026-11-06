import Foundation

struct AnthemVocalCandidateScore: Equatable, Sendable {
    let transitionStrength: Float
    let sustainedStrength: Float
    let overallStrength: Float
}

enum AnthemVocalCandidateScorer {
    static func score(evidence: AnthemCandidateVocalEvidence) -> AnthemVocalCandidateScore {
        let transition = clamp(evidence.transitionEvidence.reduce(Float(0)) { strongest, item in
            max(strongest, item.riseStrength, item.fallStrength, item.entryStrength, item.exitStrength)
        })
        let sustained: Float
        if evidence.sustainedEvidence.isEmpty {
            sustained = 0
        } else {
            let total = evidence.sustainedEvidence.reduce(Float(0)) { $0 + clamp($1.sustainedStrength) }
            sustained = clamp(total / Float(evidence.sustainedEvidence.count))
        }
        let overall: Float
        switch (evidence.transitionEvidence.isEmpty, evidence.sustainedEvidence.isEmpty) {
        case (false, false): overall = clamp((transition + sustained) / 2)
        case (false, true): overall = transition
        case (true, false): overall = sustained
        case (true, true): overall = 0
        }
        return .init(transitionStrength: transition, sustainedStrength: sustained, overallStrength: overall)
    }

    private static func clamp(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }
}
