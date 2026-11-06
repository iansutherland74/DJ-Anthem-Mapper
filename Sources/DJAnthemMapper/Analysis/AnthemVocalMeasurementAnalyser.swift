import Foundation

enum AnthemVocalMeasurementAnalyser {
    static let defaultActivityThreshold: Float = 0.02

    static func measure(
        left: ArraySlice<Float>,
        right: ArraySlice<Float>,
        activityThreshold: Float = defaultActivityThreshold
    ) -> (energy: Float, activity: Float)? {
        guard !left.isEmpty, left.count == right.count,
              activityThreshold.isFinite, activityThreshold >= 0 else { return nil }

        var squaredSum: Double = 0
        var activeFrames = 0
        var rightIndex = right.startIndex

        for leftSample in left {
            let rightSample = right[rightIndex]
            right.formIndex(after: &rightIndex)
            guard leftSample.isFinite, rightSample.isFinite else { return nil }

            let monoMagnitude = (abs(leftSample) + abs(rightSample)) * 0.5
            let clampedMagnitude = min(Float(1), monoMagnitude)
            squaredSum += Double(clampedMagnitude * clampedMagnitude)
            if clampedMagnitude >= activityThreshold { activeFrames += 1 }
        }

        let count = Double(left.count)
        let rms = Float((squaredSum / count).squareRoot())
        let activity = Float(activeFrames) / Float(left.count)
        return (energy: min(1, max(0, rms)), activity: min(1, max(0, activity)))
    }
}
