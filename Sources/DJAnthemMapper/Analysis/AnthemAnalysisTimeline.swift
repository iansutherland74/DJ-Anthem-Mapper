import Foundation

struct AnthemAnalysisTimeRange: Equatable, Sendable {
    let startTime: TimeInterval
    let endTime: TimeInterval
    var duration: TimeInterval { endTime - startTime }
    var isValid: Bool { startTime.isFinite && endTime.isFinite && startTime >= 0 && endTime > startTime }
}

enum AnthemAnalysisTimeline {
    static func validOrderedFrames(_ frames: [AnthemAnalysisFrame]) -> [AnthemAnalysisFrame] {
        frames.enumerated().filter { _, frame in
            frame.startTime.isFinite && frame.startTime >= 0 && frame.duration.isFinite && frame.duration > 0 && frame.energy.isFinite
        }.sorted {
            if $0.element.startTime != $1.element.startTime { return $0.element.startTime < $1.element.startTime }
            if $0.element.duration != $1.element.duration { return $0.element.duration < $1.element.duration }
            return $0.offset < $1.offset
        }.map(\.element)
    }

    static func frames(overlapping range: AnthemAnalysisTimeRange, in frames: [AnthemAnalysisFrame]) -> [AnthemAnalysisFrame] {
        guard range.isValid else { return [] }
        return validOrderedFrames(frames).filter {
            $0.startTime < range.endTime && $0.startTime + $0.duration > range.startTime
        }
    }
}

extension AnthemAnalysisTimeline {
    static func overlapDuration(of frame: AnthemAnalysisFrame, with range: AnthemAnalysisTimeRange) -> TimeInterval {
        guard range.isValid,
              frame.startTime.isFinite, frame.duration.isFinite, frame.duration > 0 else { return 0 }
        let start = max(frame.startTime, range.startTime)
        let end = min(frame.startTime + frame.duration, range.endTime)
        return max(0, end - start)
    }
}
