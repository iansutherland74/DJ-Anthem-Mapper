import Foundation

struct AnthemCandidateVocalEvidence: Equatable, Sendable {
    let candidateStartTime: TimeInterval
    let candidateEndTime: TimeInterval
    let transitionEvidence: [AnthemVocalTransitionEvidence]
    let sustainedEvidence: [AnthemSustainedVocalEvidence]
}

enum AnthemVocalEvidenceAssociation {
    static func associate(
        candidateStartTime: TimeInterval,
        candidateEndTime: TimeInterval,
        transitionEvidence: [AnthemVocalTransitionEvidence],
        sustainedEvidence: [AnthemSustainedVocalEvidence]
    ) -> AnthemCandidateVocalEvidence? {
        guard candidateStartTime.isFinite,
              candidateEndTime.isFinite,
              candidateStartTime >= 0,
              candidateEndTime > candidateStartTime else { return nil }

        let transitions = transitionEvidence
            .filter {
                validRange(start: $0.startTime, end: $0.endTime) &&
                overlaps(
                    start: $0.startTime,
                    end: $0.endTime,
                    candidateStart: candidateStartTime,
                    candidateEnd: candidateEndTime
                )
            }
            .sorted(by: transitionOrder)

        let sustained = sustainedEvidence
            .filter {
                validRange(start: $0.startTime, end: $0.endTime) &&
                overlaps(
                    start: $0.startTime,
                    end: $0.endTime,
                    candidateStart: candidateStartTime,
                    candidateEnd: candidateEndTime
                )
            }
            .sorted(by: sustainedOrder)

        return .init(
            candidateStartTime: candidateStartTime,
            candidateEndTime: candidateEndTime,
            transitionEvidence: transitions,
            sustainedEvidence: sustained
        )
    }

    private static func validRange(start: TimeInterval, end: TimeInterval) -> Bool {
        start.isFinite && end.isFinite && start >= 0 && end > start
    }

    private static func overlaps(
        start: TimeInterval,
        end: TimeInterval,
        candidateStart: TimeInterval,
        candidateEnd: TimeInterval
    ) -> Bool {
        start < candidateEnd && end > candidateStart
    }

    private static func transitionOrder(
        _ lhs: AnthemVocalTransitionEvidence,
        _ rhs: AnthemVocalTransitionEvidence
    ) -> Bool {
        if lhs.startTime == rhs.startTime { return lhs.endTime < rhs.endTime }
        return lhs.startTime < rhs.startTime
    }

    private static func sustainedOrder(
        _ lhs: AnthemSustainedVocalEvidence,
        _ rhs: AnthemSustainedVocalEvidence
    ) -> Bool {
        if lhs.startTime == rhs.startTime { return lhs.endTime < rhs.endTime }
        return lhs.startTime < rhs.startTime
    }
}
