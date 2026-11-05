import Foundation

struct AnthemEnergyTransitionEvidence: Equatable, Sendable {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let riseStrength: Float
    let fallStrength: Float
    let sustainStrength: Float
    let localPeakStrength: Float
    let plateauStrength: Float
}

enum AnthemEnergyTransitionAnalyser {
    static func analyse(frames: [AnthemAnalysisFrame]) -> [AnthemEnergyTransitionEvidence] {
        let ordered = frames
            .filter { $0.startTime.isFinite && $0.duration.isFinite && $0.duration > 0 && $0.energy.isFinite }
            .sorted { $0.startTime < $1.startTime }
        guard !ordered.isEmpty else { return [] }
        return ordered.indices.map { index in
            let energy = ordered[index].energy
            let previous = index > ordered.startIndex ? ordered[index - 1].energy : energy
            let next = index < ordered.index(before: ordered.endIndex) ? ordered[index + 1].energy : energy
            let rise = clamp(energy - previous)
            let fall = clamp(energy - next)
            let localPeak = clamp(energy - max(previous, next))
            let neighbours = [previous, energy, next]
            let neighbourhoodMean = neighbours.reduce(0, +) / Float(neighbours.count)
            let deviation = neighbours.reduce(Float(0)) { $0 + abs($1 - neighbourhoodMean) } / Float(neighbours.count)
            let sustain = clamp(neighbourhoodMean * (1 - deviation))
            let plateau = clamp(min(energy, min(previous, next)))
            return .init(startTime: ordered[index].startTime, endTime: ordered[index].startTime + ordered[index].duration, riseStrength: rise, fallStrength: fall, sustainStrength: sustain, localPeakStrength: localPeak, plateauStrength: plateau)
        }
    }

    private static func clamp(_ value: Float) -> Float { min(1, max(0, value)) }
}
