import Foundation

struct AnthemAcceptanceRange: Codable, Equatable, Sendable {
    let startTime: TimeInterval
    let endTime: TimeInterval
    var isValid: Bool { startTime.isFinite && endTime.isFinite && startTime >= 0 && endTime > startTime }
}

enum AnthemAcceptanceTrackVariant: String, Codable, Equatable, Sendable {
    case original
    case djEdit
    case live
    case remix
    case other
}

struct AnthemAcceptanceManifestEntry: Codable, Equatable, Sendable {
    let identifier: String
    let variant: AnthemAcceptanceTrackVariant
    let expectedRanges: [AnthemAcceptanceRange]
    let acceptableAlternativeRanges: [AnthemAcceptanceRange]
    let knownNonHookRanges: [AnthemAcceptanceRange]
    let expectedNoCandidates: Bool
    let minimumOverlapRatio: Double
    let notes: String?

    var isValid: Bool {
        !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        minimumOverlapRatio.isFinite && (0...1).contains(minimumOverlapRatio) &&
        expectedRanges.allSatisfy(\.isValid) &&
        acceptableAlternativeRanges.allSatisfy(\.isValid) &&
        knownNonHookRanges.allSatisfy(\.isValid) &&
        (expectedNoCandidates || !expectedRanges.isEmpty || !acceptableAlternativeRanges.isEmpty)
    }
}

struct AnthemAcceptanceCandidateDiagnostic: Equatable, Sendable {
    let rank: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
    let originalScore: Float
    let energyEvidenceScore: Float
    let structuralStrength: Float
    let compositeScore: Float
    let overlapsExpectedRange: Bool
    let overlapsKnownNonHookRange: Bool
}

struct AnthemAcceptanceEvaluation: Equatable, Sendable {
    let identifier: String
    let status: AnthemStructuralAnalysisStatus
    let expectedNoCandidates: Bool
    let topCandidateHit: Bool
    let bestAcceptableRank: Int?
    let candidates: [AnthemAcceptanceCandidateDiagnostic]
}

enum AnthemAnalysisAcceptanceHarness {
    static func evaluate(
        manifest: AnthemAcceptanceManifestEntry,
        waveformSamples: [Float],
        trackDuration: TimeInterval,
        configuration: AnthemStructuralAnalysisConfiguration = .init()
    ) -> AnthemAcceptanceEvaluation? {
        guard manifest.isValid else { return nil }
        let result = AnthemStructuralAnalysisPipeline.analyse(
            waveformSamples: waveformSamples,
            trackDuration: trackDuration,
            configuration: configuration
        )
        let acceptable = manifest.expectedRanges + manifest.acceptableAlternativeRanges
        let diagnostics = result.candidates.enumerated().map { index, item in
            let candidateRange = AnthemAcceptanceRange(
                startTime: item.candidate.startTime,
                endTime: item.candidate.endTime
            )
            return AnthemAcceptanceCandidateDiagnostic(
                rank: index + 1,
                startTime: item.candidate.startTime,
                endTime: item.candidate.endTime,
                originalScore: item.originalScore,
                energyEvidenceScore: item.energyEvidence.score,
                structuralStrength: item.structuralStrength,
                compositeScore: item.compositeScore,
                overlapsExpectedRange: acceptable.contains {
                    overlapRatio(candidateRange, $0) >= manifest.minimumOverlapRatio
                },
                overlapsKnownNonHookRange: manifest.knownNonHookRanges.contains {
                    overlapRatio(candidateRange, $0) >= manifest.minimumOverlapRatio
                }
            )
        }
        return .init(
            identifier: manifest.identifier,
            status: result.status,
            expectedNoCandidates: manifest.expectedNoCandidates,
            topCandidateHit: manifest.expectedNoCandidates
                ? result.candidates.isEmpty
                : (diagnostics.first?.overlapsExpectedRange ?? false),
            bestAcceptableRank: diagnostics.first(where: \.overlapsExpectedRange)?.rank,
            candidates: diagnostics
        )
    }

    static func encodeManifest(_ entries: [AnthemAcceptanceManifestEntry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(entries)
    }

    static func decodeManifest(_ data: Data) throws -> [AnthemAcceptanceManifestEntry] {
        try JSONDecoder().decode([AnthemAcceptanceManifestEntry].self, from: data)
    }

    private static func overlapRatio(
        _ lhs: AnthemAcceptanceRange,
        _ rhs: AnthemAcceptanceRange
    ) -> Double {
        guard lhs.isValid, rhs.isValid else { return 0 }
        let overlap = max(0, min(lhs.endTime, rhs.endTime) - max(lhs.startTime, rhs.startTime))
        let shorter = min(lhs.endTime - lhs.startTime, rhs.endTime - rhs.startTime)
        return shorter > 0 ? overlap / shorter : 0
    }
}
