import Foundation

struct AnthemAnalysisFrame: Equatable, Sendable {
    let startTime: TimeInterval
    let duration: TimeInterval
    let energy: Float

    init(startTime: TimeInterval, duration: TimeInterval, energy: Float) {
        self.startTime = max(0, startTime)
        self.duration = max(0, duration)
        self.energy = min(1, max(0, energy))
    }
}

struct AnthemAnalysisWindow: Equatable, Sendable {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let score: Float
}

enum AnthemAnalysisFoundation {
    static func frames(
        from waveformSamples: [Float],
        trackDuration: TimeInterval
    ) -> [AnthemAnalysisFrame] {
        guard trackDuration > 0, !waveformSamples.isEmpty else { return [] }
        let frameDuration = trackDuration / Double(waveformSamples.count)
        return waveformSamples.enumerated().map { index, sample in
            AnthemAnalysisFrame(
                startTime: Double(index) * frameDuration,
                duration: frameDuration,
                energy: sample.isFinite ? abs(sample) : 0
            )
        }
    }

    static func strongestWindow(
        in frames: [AnthemAnalysisFrame],
        preferredDuration: TimeInterval = 20
    ) -> AnthemAnalysisWindow? {
        guard !frames.isEmpty, preferredDuration > 0 else { return nil }
        var best: AnthemAnalysisWindow?
        for start in frames.indices {
            let startTime = frames[start].startTime
            var total: Float = 0
            var count = 0
            var endTime = startTime
            for index in start..<frames.endIndex {
                let frame = frames[index]
                if frame.startTime >= startTime + preferredDuration { break }
                total += frame.energy
                count += 1
                endTime = frame.startTime + frame.duration
            }
            guard count > 0 else { continue }
            let score = total / Float(count)
            let candidate = AnthemAnalysisWindow(startTime: startTime, endTime: endTime, score: score)
            if best == nil || score > best!.score { best = candidate }
        }
        return best
    }
}
