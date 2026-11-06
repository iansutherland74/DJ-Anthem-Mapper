import Foundation

struct AnthemVocalAnalysisFrame: Equatable, Sendable {
    let startTime: TimeInterval
    let duration: TimeInterval
    let energy: Float
    let activity: Float

    var endTime: TimeInterval { startTime + duration }

    init(startTime: TimeInterval, duration: TimeInterval, energy: Float, activity: Float) {
        self.startTime = Self.nonNegativeFinite(startTime)
        self.duration = Self.nonNegativeFinite(duration)
        self.energy = Self.unitFinite(energy)
        self.activity = Self.unitFinite(activity)
    }

    private static func nonNegativeFinite(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return max(0, value)
    }

    private static func unitFinite(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }
}
