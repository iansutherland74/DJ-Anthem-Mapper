import Foundation

struct AnthemStructuralEvidence: Equatable, Sendable {
    let candidate: AnthemCandidate
    let riseStrength: Float
    let fallStrength: Float
    let sustainStrength: Float
    let localPeakStrength: Float
    let plateauStrength: Float
    let repetitionSimilarity: Float
    let repetitionStrength: Float
    let repetitionMatchCount: Int
    let structuralStrength: Float
}

enum AnthemStructuralEvidenceAnalyser {
    static func analyse(
        candidate: AnthemCandidate,
        frames: [AnthemAnalysisFrame],
        transitions: [AnthemEnergyTransitionEvidence],
        repetitions: [AnthemRepetitionEvidence]
    ) -> AnthemStructuralEvidence? {
        guard candidate.startTime.isFinite, candidate.endTime.isFinite,
              candidate.endTime > candidate.startTime else { return nil }

        let orderedFrames = frames.filter {
            $0.startTime.isFinite && $0.duration.isFinite && $0.duration > 0 && $0.energy.isFinite
        }.sorted { $0.startTime < $1.startTime }
        guard !orderedFrames.isEmpty else { return nil }

        let pairedCount = min(orderedFrames.count, transitions.count)
        var applicableTransitions: [AnthemEnergyTransitionEvidence] = []
        if pairedCount > 0 {
            for index in 0..<pairedCount {
                let frame = orderedFrames[index]
                if frame.startTime < candidate.endTime && frame.startTime + frame.duration > candidate.startTime {
                    applicableTransitions.append(transitions[index])
                }
            }
        }

        let rise = applicableTransitions.map(\.riseStrength).max() ?? 0
        let fall = applicableTransitions.map(\.fallStrength).max() ?? 0
        let peak = applicableTransitions.map(\.localPeakStrength).max() ?? 0
        let sustain = mean(applicableTransitions.map(\.sustainStrength))
        let plateau = mean(applicableTransitions.map(\.plateauStrength))

        let applicableRepetitions = repetitions.filter {
            $0.sourceStartTime.isFinite && $0.sourceEndTime.isFinite &&
            $0.sourceStartTime < candidate.endTime && $0.sourceEndTime > candidate.startTime
        }.sorted {
            if $0.repetitionStrength != $1.repetitionStrength { return $0.repetitionStrength > $1.repetitionStrength }
            if $0.bestSimilarity != $1.bestSimilarity { return $0.bestSimilarity > $1.bestSimilarity }
            return $0.sourceStartTime < $1.sourceStartTime
        }

        let repetition = applicableRepetitions.first
        let repetitionSimilarity = clamp(repetition?.bestSimilarity ?? 0)
        let repetitionStrength = clamp(repetition?.repetitionStrength ?? 0)
        let repetitionMatchCount = repetition?.matches.count ?? 0

        let structuralStrength = clamp(
            rise * 0.15 +
            fall * 0.05 +
            sustain * 0.20 +
            peak * 0.10 +
            plateau * 0.15 +
            repetitionStrength * 0.35
        )

        return .init(
            candidate: candidate,
            riseStrength: clamp(rise),
            fallStrength: clamp(fall),
            sustainStrength: clamp(sustain),
            localPeakStrength: clamp(peak),
            plateauStrength: clamp(plateau),
            repetitionSimilarity: repetitionSimilarity,
            repetitionStrength: repetitionStrength,
            repetitionMatchCount: repetitionMatchCount,
            structuralStrength: structuralStrength
        )
    }

    private static func mean(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Float(values.count)
    }

    private static func clamp(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }
}
