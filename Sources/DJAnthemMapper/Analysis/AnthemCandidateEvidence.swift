import Foundation

enum AnthemCandidateConfidence: Int, Comparable, Sendable {
    case low
    case medium
    case high

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct AnthemCandidateEvidence: Equatable, Sendable {
    let candidate: AnthemCandidate
    let meanEnergy: Float
    let peakEnergy: Float
    let relativeEnergy: Float
    let consistency: Float
    let surroundingContrast: Float
    let score: Float
    let confidence: AnthemCandidateConfidence
}

enum AnthemCandidateEvidenceAnalyser {
    static func analyse(candidate: AnthemCandidate, frames: [AnthemAnalysisFrame]) -> AnthemCandidateEvidence? {
        guard candidate.startTime.isFinite, candidate.endTime.isFinite,
              candidate.endTime > candidate.startTime else { return nil }
        let valid = frames.filter { $0.startTime.isFinite && $0.duration.isFinite && $0.duration > 0 && $0.energy.isFinite }
        guard !valid.isEmpty else { return nil }
        let inside = valid.filter { overlaps($0, start: candidate.startTime, end: candidate.endTime) }
        guard !inside.isEmpty else { return nil }
        let trackMean = mean(valid.map(\.energy))
        let candidateMean = mean(inside.map(\.energy))
        let peak = inside.map(\.energy).max() ?? 0
        let relative = clamp(candidateMean - trackMean + 0.5)
        let spread = mean(inside.map { abs($0.energy - candidateMean) })
        let consistency = clamp(1 - spread)
        let window = candidate.duration
        let surrounding = valid.filter { frame in
            let midpoint = frame.startTime + frame.duration / 2
            return (midpoint >= candidate.startTime - window && midpoint < candidate.startTime) ||
                   (midpoint >= candidate.endTime && midpoint < candidate.endTime + window)
        }
        let surroundingMean = surrounding.isEmpty ? trackMean : mean(surrounding.map(\.energy))
        let contrast = clamp(candidateMean - surroundingMean + 0.5)
        let score = clamp(candidateMean * 0.30 + peak * 0.15 + relative * 0.20 + consistency * 0.15 + contrast * 0.20)
        let confidence: AnthemCandidateConfidence = score >= 0.75 ? .high : (score >= 0.50 ? .medium : .low)
        return AnthemCandidateEvidence(candidate: candidate, meanEnergy: candidateMean, peakEnergy: peak, relativeEnergy: relative, consistency: consistency, surroundingContrast: contrast, score: score, confidence: confidence)
    }

    private static func overlaps(_ frame: AnthemAnalysisFrame, start: Double, end: Double) -> Bool {
        frame.startTime < end && frame.startTime + frame.duration > start
    }
    private static func mean(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Float(values.count)
    }
    private static func clamp(_ value: Float) -> Float { min(1, max(0, value)) }
}
