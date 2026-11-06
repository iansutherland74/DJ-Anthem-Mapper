import Foundation

enum AnthemVocalAnalysisTimeline {
    static let defaultWindowDuration: TimeInterval = 1

    static func frames(
        from pcm: VocalSeparationPCM,
        windowDuration: TimeInterval = defaultWindowDuration,
        activityThreshold: Float = AnthemVocalMeasurementAnalyser.defaultActivityThreshold
    ) -> [AnthemVocalAnalysisFrame] {
        guard windowDuration.isFinite, windowDuration > 0,
              activityThreshold.isFinite, activityThreshold >= 0 else { return [] }

        let rate = Double(pcm.sampleRate)
        let exactFrames = windowDuration * rate
        guard exactFrames.isFinite, exactFrames >= 1, exactFrames <= Double(Int.max) else { return [] }
        let windowFrames = max(1, Int(exactFrames.rounded()))
        var result: [AnthemVocalAnalysisFrame] = []
        result.reserveCapacity((pcm.left.count + windowFrames - 1) / windowFrames)

        var startFrame = 0
        while startFrame < pcm.left.count {
            let endFrame = min(startFrame + windowFrames, pcm.left.count)
            guard let measurement = AnthemVocalMeasurementAnalyser.measure(
                left: pcm.left[startFrame..<endFrame],
                right: pcm.right[startFrame..<endFrame],
                activityThreshold: activityThreshold
            ) else { return [] }

            let startTime = Double(startFrame) / rate
            let duration = Double(endFrame - startFrame) / rate
            result.append(.init(
                startTime: startTime,
                duration: duration,
                energy: measurement.energy,
                activity: measurement.activity
            ))
            startFrame = endFrame
        }
        return result
    }
}
