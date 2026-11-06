import Foundation

struct AnthemSustainedVocalEvidence: Equatable, Sendable {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let energyStrength: Float
    let activityStrength: Float
    let sustainedStrength: Float
}

enum AnthemSustainedVocalAnalyser {
    static func analyse(frames: [AnthemVocalAnalysisFrame]) -> [AnthemSustainedVocalEvidence] {
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
            let energy = clamp((previous.energy + current.energy + next.energy) / 3)
            let activity = clamp((previous.activity + current.activity + next.activity) / 3)
            return .init(
                startTime: current.startTime,
                endTime: current.endTime,
                energyStrength: energy,
                activityStrength: activity,
                sustainedStrength: clamp(min(energy, activity))
            )
        }
    }

    private static func clamp(_ value: Float) -> Float { min(1, max(0, value)) }
}
