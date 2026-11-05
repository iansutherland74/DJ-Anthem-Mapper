import Foundation

struct AnthemAnalysisInputQuality: Equatable, Sendable {
    let minimumEnergy: Float
    let peakEnergy: Float
    let meanEnergy: Float
    let dynamicRange: Float
    let hasMeaningfulSignal: Bool
}

enum AnthemAnalysisInputQualityAnalyser {
    static let minimumMeaningfulPeakEnergy: Float = 0.001

    static func analyse(frames: [AnthemAnalysisFrame]) -> AnthemAnalysisInputQuality? {
        let valid = AnthemAnalysisTimeline.validOrderedFrames(frames)
        guard !valid.isEmpty else { return nil }
        let energies = valid.map(\.energy)
        let minimum = energies.min() ?? 0
        let peak = energies.max() ?? 0
        let start = valid.map(\.startTime).min() ?? 0
        let end = valid.map { $0.startTime + $0.duration }.max() ?? start
        let range = AnthemAnalysisTimeRange(startTime: start, endTime: end)
        let mean = AnthemAnalysisMeasurements.weightedEnergy(in: range, frames: valid)?.weightedMean ?? 0
        let dynamicRange = max(0, peak - minimum)
        return .init(
            minimumEnergy: minimum,
            peakEnergy: peak,
            meanEnergy: mean,
            dynamicRange: dynamicRange,
            hasMeaningfulSignal: peak >= minimumMeaningfulPeakEnergy
        )
    }
}
