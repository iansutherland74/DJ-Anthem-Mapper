import Foundation

struct AnthemVocalTransitionEvidence: Equatable, Sendable {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let riseStrength: Float
    let fallStrength: Float
    let entryStrength: Float
    let exitStrength: Float
}

enum AnthemVocalTransitionAnalyser {
    static func analyse(frames: [AnthemVocalAnalysisFrame]) -> [AnthemVocalTransitionEvidence] {
        let ordered = frames
            .filter { $0.startTime.isFinite && $0.duration.isFinite && $0.duration > 0 && $0.energy.isFinite && $0.activity.isFinite }
            .sorted { lhs, rhs in
                if lhs.startTime == rhs.startTime { return lhs.endTime < rhs.endTime }
                return lhs.startTime < rhs.startTime
            }
        guard !ordered.isEmpty else { return [] }

        return ordered.indices.map { index in
            let current = ordered[index]
            let previous = index > ordered.startIndex ? ordered[index - 1] : current
            let next = index < ordered.index(before: ordered.endIndex) ? ordered[index + 1] : current

            return .init(
                startTime: current.startTime,
                endTime: current.endTime,
                riseStrength: clamp(current.energy - previous.energy),
                fallStrength: clamp(current.energy - next.energy),
                entryStrength: clamp(current.activity - previous.activity),
                exitStrength: clamp(current.activity - next.activity)
            )
        }
    }

    private static func clamp(_ value: Float) -> Float {
        min(1, max(0, value))
    }
}
