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
        let candidateRange = AnthemAnalysisTimeRange(startTime: candidate.startTime, endTime: candidate.endTime)
        guard let candidateMeasurement = AnthemAnalysisMeasurements.weightedEnergy(in: candidateRange, frames: valid) else { return nil }
        let trackStart = valid.map(\.startTime).min() ?? 0
        let trackEnd = valid.map { $0.startTime + $0.duration }.max() ?? trackStart
        let trackRange = AnthemAnalysisTimeRange(startTime: trackStart, endTime: trackEnd)
        let trackMean = AnthemAnalysisMeasurements.weightedEnergy(in: trackRange, frames: valid)?.weightedMean ?? 0
        let candidateMean = candidateMeasurement.weightedMean
        let peak = inside.map(\.energy).max() ?? 0
        let relative = clamp(candidateMean - trackMean + 0.5)
        let spread = AnthemAnalysisMeasurements.weightedDeviation(in: candidateRange, frames: valid, mean: candidateMean)
        let consistency = clamp(1 - spread)
        let window = candidate.duration
        let preRange = AnthemAnalysisTimeRange(startTime: max(0, candidate.startTime - window), endTime: candidate.startTime)
        let postRange = AnthemAnalysisTimeRange(startTime: candidate.endTime, endTime: min(trackEnd, candidate.endTime + window))
        let pre = preRange.isValid ? AnthemAnalysisMeasurements.weightedEnergy(in: preRange, frames: valid) : nil
        let post = postRange.isValid ? AnthemAnalysisMeasurements.weightedEnergy(in: postRange, frames: valid) : nil
        let surroundingParts = [pre, post].compactMap { $0 }
        let surroundingMean: Float
        if surroundingParts.isEmpty { surroundingMean = trackMean }
        else {
            let totalDuration = surroundingParts.reduce(0.0) { $0 + $1.coveredDuration }
            surroundingMean = totalDuration > 0 ? Float(surroundingParts.reduce(0.0) { $0 + Double($1.weightedMean) * $1.coveredDuration } / totalDuration) : trackMean
        }
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
