import XCTest
@testable import DJAnthemMapper

final class AnthemAnalysisAcceptanceHarnessTests: XCTestCase {
    private func manifest(
        expected: [AnthemAcceptanceRange],
        alternatives: [AnthemAcceptanceRange] = [],
        nonHooks: [AnthemAcceptanceRange] = [],
        noCandidates: Bool = false
    ) -> AnthemAcceptanceManifestEntry {
        .init(
            identifier: "local-test-track",
            variant: .djEdit,
            expectedRanges: expected,
            acceptableAlternativeRanges: alternatives,
            knownNonHookRanges: nonHooks,
            expectedNoCandidates: noCandidates,
            minimumOverlapRatio: 0.5,
            notes: "Local metadata only; no copyrighted media in Git."
        )
    }

    func testManifestRoundTripsThroughDeterministicJSON() throws {
        let entry = manifest(expected: [.init(startTime: 20, endTime: 40)])
        let first = try AnthemAnalysisAcceptanceHarness.encodeManifest([entry])
        let second = try AnthemAnalysisAcceptanceHarness.encodeManifest([entry])
        XCTAssertEqual(first, second)
        XCTAssertEqual(try AnthemAnalysisAcceptanceHarness.decodeManifest(first), [entry])
    }

    func testInvalidManifestIsRejected() {
        let invalid = AnthemAcceptanceManifestEntry(
            identifier: " ", variant: .original, expectedRanges: [],
            acceptableAlternativeRanges: [], knownNonHookRanges: [],
            expectedNoCandidates: false, minimumOverlapRatio: 0.5, notes: nil
        )
        XCTAssertNil(AnthemAnalysisAcceptanceHarness.evaluate(
            manifest: invalid, waveformSamples: [0.5], trackDuration: 1
        ))
    }

    func testExpectedRangeHitReportsRankAndDiagnostics() {
        let samples: [Float] = [0.1,0.1,0.9,1.0,0.1,0.1]
        let result = AnthemAnalysisAcceptanceHarness.evaluate(
            manifest: manifest(expected: [.init(startTime: 20, endTime: 40)]),
            waveformSamples: samples,
            trackDuration: 60
        )!
        XCTAssertEqual(result.status, .analysed)
        XCTAssertTrue(result.topCandidateHit)
        XCTAssertEqual(result.bestAcceptableRank, 1)
        XCTAssertFalse(result.candidates.isEmpty)
        XCTAssertTrue(result.candidates.allSatisfy {
            $0.rank > 0 && $0.originalScore.isFinite &&
            $0.energyEvidenceScore.isFinite && $0.structuralStrength.isFinite &&
            $0.compositeScore.isFinite
        })
    }

    func testAcceptableAlternativeCanProduceHit() {
        let samples: [Float] = [0.1,0.1,0.9,1.0,0.1,0.1]
        let result = AnthemAnalysisAcceptanceHarness.evaluate(
            manifest: manifest(
                expected: [.init(startTime: 0, endTime: 10)],
                alternatives: [.init(startTime: 20, endTime: 40)]
            ),
            waveformSamples: samples,
            trackDuration: 60
        )!
        XCTAssertTrue(result.topCandidateHit)
    }

    func testKnownNonHookOverlapIsReportedSeparately() {
        let samples: [Float] = [0.1,0.1,0.9,1.0,0.1,0.1]
        let result = AnthemAnalysisAcceptanceHarness.evaluate(
            manifest: manifest(
                expected: [.init(startTime: 20, endTime: 40)],
                nonHooks: [.init(startTime: 20, endTime: 40)]
            ),
            waveformSamples: samples,
            trackDuration: 60
        )!
        XCTAssertTrue(result.candidates.first?.overlapsKnownNonHookRange ?? false)
    }

    func testExpectedNoCandidatesPassesForSilence() {
        let result = AnthemAnalysisAcceptanceHarness.evaluate(
            manifest: manifest(expected: [], noCandidates: true),
            waveformSamples: [0,0,0,0],
            trackDuration: 40
        )!
        XCTAssertEqual(result.status, .noCandidates)
        XCTAssertTrue(result.topCandidateHit)
        XCTAssertTrue(result.candidates.isEmpty)
    }

    func testRepeatedEvaluationIsDeterministic() {
        let entry = manifest(expected: [.init(startTime: 20, endTime: 40)])
        let samples: [Float] = [0.1,0.1,0.9,1.0,0.1,0.1]
        XCTAssertEqual(
            AnthemAnalysisAcceptanceHarness.evaluate(manifest: entry, waveformSamples: samples, trackDuration: 60),
            AnthemAnalysisAcceptanceHarness.evaluate(manifest: entry, waveformSamples: samples, trackDuration: 60)
        )
    }

    func testRealisticSevenHundredTwentyFrameWorkloadCompletesWithFiniteDiagnostics() {
        let samples = (0..<720).map { index -> Float in
            let phase = index % 120
            return phase < 40 ? 0.2 : (phase < 80 ? 0.85 : 0.35)
        }
        let result = AnthemAnalysisAcceptanceHarness.evaluate(
            manifest: manifest(expected: [.init(startTime: 40, endTime: 80)]),
            waveformSamples: samples,
            trackDuration: 720
        )!
        XCTAssertNotEqual(result.status, .invalidInput)
        XCTAssertTrue(result.candidates.allSatisfy { $0.compositeScore.isFinite })
    }

    func testLongFourteenHundredFortyFrameWorkloadCompletesDeterministically() {
        let samples = (0..<1440).map { Float(($0 % 32) + 1) / 33 }
        let entry = manifest(expected: [.init(startTime: 100, endTime: 130)])
        let first = AnthemAnalysisAcceptanceHarness.evaluate(
            manifest: entry, waveformSamples: samples, trackDuration: 1440
        )
        let second = AnthemAnalysisAcceptanceHarness.evaluate(
            manifest: entry, waveformSamples: samples, trackDuration: 1440
        )
        XCTAssertEqual(first, second)
        XCTAssertTrue(first?.candidates.allSatisfy { $0.compositeScore.isFinite } ?? false)
    }
}
