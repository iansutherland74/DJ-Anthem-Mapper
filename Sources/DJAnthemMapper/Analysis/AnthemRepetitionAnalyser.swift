import Foundation

struct AnthemRepetitionConfiguration: Equatable, Sendable {
    var windowFrameCount: Int = 4
    var similarityThreshold: Float = 0.80
    var maximumOverlapRatio: Double = 0.25
    var maximumMatches: Int = 4

    var isValid: Bool {
        windowFrameCount > 1 && maximumMatches > 0 &&
        similarityThreshold.isFinite && (0...1).contains(similarityThreshold) &&
        maximumOverlapRatio.isFinite && (0...1).contains(maximumOverlapRatio)
    }
}

struct AnthemRepetitionMatch: Equatable, Sendable {
    let sourceStartTime: TimeInterval
    let sourceEndTime: TimeInterval
    let matchStartTime: TimeInterval
    let matchEndTime: TimeInterval
    let similarity: Float
}

struct AnthemRepetitionEvidence: Equatable, Sendable {
    let sourceStartTime: TimeInterval
    let sourceEndTime: TimeInterval
    let bestSimilarity: Float
    let repetitionStrength: Float
    let matches: [AnthemRepetitionMatch]
}

enum AnthemRepetitionAnalyser {
    static func analyse(
        frames: [AnthemAnalysisFrame],
        configuration: AnthemRepetitionConfiguration = .init()
    ) -> [AnthemRepetitionEvidence] {
        guard configuration.isValid else { return [] }
        let ordered = frames.filter {
            $0.startTime.isFinite && $0.duration.isFinite && $0.duration > 0 && $0.energy.isFinite
        }.sorted { $0.startTime < $1.startTime }
        guard ordered.count >= configuration.windowFrameCount else { return [] }

        let lastStart = ordered.count - configuration.windowFrameCount
        var results: [AnthemRepetitionEvidence] = []
        for sourceIndex in 0...lastStart {
            let source = Array(ordered[sourceIndex..<(sourceIndex + configuration.windowFrameCount)])
            let sourceStart = source.first!.startTime
            let sourceEnd = source.last!.startTime + source.last!.duration
            guard meaningful(source) else {
                results.append(.init(sourceStartTime: sourceStart, sourceEndTime: sourceEnd, bestSimilarity: 0, repetitionStrength: 0, matches: []))
                continue
            }
            var matches: [AnthemRepetitionMatch] = []
            for matchIndex in 0...lastStart where matchIndex != sourceIndex {
                let match = Array(ordered[matchIndex..<(matchIndex + configuration.windowFrameCount)])
                let matchStart = match.first!.startTime
                let matchEnd = match.last!.startTime + match.last!.duration
                guard overlapRatio(sourceStart, sourceEnd, matchStart, matchEnd) <= configuration.maximumOverlapRatio else { continue }
                guard meaningful(match) else { continue }
                let similarity = shapeSimilarity(source, match)
                guard similarity >= configuration.similarityThreshold else { continue }
                matches.append(.init(sourceStartTime: sourceStart, sourceEndTime: sourceEnd, matchStartTime: matchStart, matchEndTime: matchEnd, similarity: similarity))
            }
            matches.sort {
                if $0.similarity != $1.similarity { return $0.similarity > $1.similarity }
                if $0.matchStartTime != $1.matchStartTime { return $0.matchStartTime < $1.matchStartTime }
                return $0.matchEndTime < $1.matchEndTime
            }
            matches = Array(matches.prefix(configuration.maximumMatches))
            let best = matches.first?.similarity ?? 0
            let strength = matches.isEmpty ? 0 : min(1, best * min(1, Float(matches.count) / 2))
            results.append(.init(sourceStartTime: sourceStart, sourceEndTime: sourceEnd, bestSimilarity: best, repetitionStrength: strength, matches: matches))
        }
        return results
    }

    private static func meaningful(_ frames: [AnthemAnalysisFrame]) -> Bool {
        guard let minEnergy = frames.map(\.energy).min(), let maxEnergy = frames.map(\.energy).max() else { return false }
        return maxEnergy - minEnergy > 0.02
    }

    private static func shapeSimilarity(_ lhs: [AnthemAnalysisFrame], _ rhs: [AnthemAnalysisFrame]) -> Float {
        let a = normalisedShape(lhs.map(\.energy))
        let b = normalisedShape(rhs.map(\.energy))
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let error = zip(a, b).reduce(Float(0)) { $0 + abs($1.0 - $1.1) } / Float(a.count)
        return min(1, max(0, 1 - error))
    }

    private static func normalisedShape(_ values: [Float]) -> [Float] {
        guard let low = values.min(), let high = values.max(), high > low else { return Array(repeating: 0, count: values.count) }
        return values.map { ($0 - low) / (high - low) }
    }

    private static func overlapRatio(_ aStart: Double, _ aEnd: Double, _ bStart: Double, _ bEnd: Double) -> Double {
        let overlap = max(0, min(aEnd, bEnd) - max(aStart, bStart))
        let shorter = min(aEnd - aStart, bEnd - bStart)
        return shorter > 0 ? overlap / shorter : 0
    }
}
