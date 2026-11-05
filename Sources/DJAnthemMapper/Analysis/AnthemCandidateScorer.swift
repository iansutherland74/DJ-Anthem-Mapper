import Foundation

struct AnthemCandidate: Equatable, Sendable {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let score: Float

    var duration: TimeInterval {
        max(0, endTime - startTime)
    }
}

enum AnthemCandidateScorer {
    static func rankedCandidates(
        from frames: [AnthemAnalysisFrame],
        preferredDuration: TimeInterval = 20,
        maximumCount: Int = 5,
        maximumOverlapRatio: Double = 0.50
    ) -> [AnthemCandidate] {
        guard
            !frames.isEmpty,
            preferredDuration > 0,
            maximumCount > 0,
            maximumOverlapRatio.isFinite,
            maximumOverlapRatio >= 0,
            maximumOverlapRatio <= 1
        else {
            return []
        }

        let orderedFrames = frames
            .filter {
                $0.startTime.isFinite &&
                $0.duration.isFinite &&
                $0.duration > 0 &&
                $0.energy.isFinite
            }
            .sorted {
                if $0.startTime != $1.startTime {
                    return $0.startTime < $1.startTime
                }
                return $0.duration < $1.duration
            }

        guard !orderedFrames.isEmpty else { return [] }

        var candidates: [AnthemCandidate] = []

        for startIndex in orderedFrames.indices {
            let startTime = orderedFrames[startIndex].startTime
            let targetEnd = startTime + preferredDuration
            let availableEnd = orderedFrames.map { $0.startTime + $0.duration }.max() ?? startTime
            let endTime = min(targetEnd, availableEnd)
            let range = AnthemAnalysisTimeRange(startTime: startTime, endTime: endTime)
            guard let measurement = AnthemAnalysisMeasurements.weightedEnergy(in: range, frames: orderedFrames) else { continue }
            candidates.append(
                AnthemCandidate(
                    startTime: startTime,
                    endTime: endTime,
                    score: measurement.weightedMean
                )
            )
        }

        candidates.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.startTime != $1.startTime { return $0.startTime < $1.startTime }
            return $0.endTime < $1.endTime
        }

        var accepted: [AnthemCandidate] = []
        for candidate in candidates {
            guard !accepted.contains(where: {
                overlapRatio(candidate, $0) > maximumOverlapRatio
            }) else {
                continue
            }

            accepted.append(candidate)
            if accepted.count == maximumCount { break }
        }

        return accepted
    }

    private static func overlapRatio(
        _ lhs: AnthemCandidate,
        _ rhs: AnthemCandidate
    ) -> Double {
        let overlapStart = max(lhs.startTime, rhs.startTime)
        let overlapEnd = min(lhs.endTime, rhs.endTime)
        let overlap = max(0, overlapEnd - overlapStart)
        let shorterDuration = min(lhs.duration, rhs.duration)
        guard shorterDuration > 0 else { return 0 }
        return overlap / shorterDuration
    }
}
