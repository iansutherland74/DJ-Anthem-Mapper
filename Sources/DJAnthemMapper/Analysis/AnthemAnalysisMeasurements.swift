import Foundation

struct AnthemWeightedEnergyMeasurement: Equatable, Sendable {
    let weightedMean: Float
    let coveredDuration: TimeInterval
    let requestedDuration: TimeInterval
    var coverageRatio: Double { requestedDuration > 0 ? min(1, coveredDuration / requestedDuration) : 0 }
}

enum AnthemAnalysisMeasurements {
    static func weightedEnergy(in range: AnthemAnalysisTimeRange, frames: [AnthemAnalysisFrame]) -> AnthemWeightedEnergyMeasurement? {
        guard range.isValid else { return nil }
        let ordered = AnthemAnalysisTimeline.validOrderedFrames(frames)
        guard !ordered.isEmpty else { return nil }
        var weighted: Double = 0
        var covered: Double = 0
        for (index, frame) in ordered.enumerated() {
            let nextStart = index + 1 < ordered.count ? ordered[index + 1].startTime : frame.startTime + frame.duration
            let effectiveEnd = min(frame.startTime + frame.duration, nextStart)
            guard effectiveEnd > frame.startTime else { continue }
            let effective = AnthemAnalysisFrame(startTime: frame.startTime, duration: effectiveEnd - frame.startTime, energy: frame.energy)
            let overlap = AnthemAnalysisTimeline.overlapDuration(of: effective, with: range)
            guard overlap > 0 else { continue }
            weighted += Double(frame.energy) * overlap
            covered += overlap
        }
        guard covered > 0 else { return nil }
        return .init(weightedMean: Float(weighted / covered), coveredDuration: covered, requestedDuration: range.duration)
    }

    static func weightedDeviation(in range: AnthemAnalysisTimeRange, frames: [AnthemAnalysisFrame], mean: Float) -> Float {
        let ordered = AnthemAnalysisTimeline.validOrderedFrames(frames)
        var weighted: Double = 0
        var covered: Double = 0
        for (index, frame) in ordered.enumerated() {
            let nextStart = index + 1 < ordered.count ? ordered[index + 1].startTime : frame.startTime + frame.duration
            let effectiveEnd = min(frame.startTime + frame.duration, nextStart)
            guard effectiveEnd > frame.startTime else { continue }
            let effective = AnthemAnalysisFrame(startTime: frame.startTime, duration: effectiveEnd - frame.startTime, energy: frame.energy)
            let overlap = AnthemAnalysisTimeline.overlapDuration(of: effective, with: range)
            guard overlap > 0 else { continue }
            weighted += Double(abs(frame.energy - mean)) * overlap
            covered += overlap
        }
        return covered > 0 ? Float(weighted / covered) : 0
    }
}
