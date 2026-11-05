import XCTest
@testable import DJAnthemMapper

final class AnthemProvisionalCandidatePoolTests: XCTestCase {
    func testDefaultProvisionalPoolIsBroaderThanFinalLimit() {
        let c = AnthemStructuralAnalysisConfiguration()
        XCTAssertGreaterThan(c.provisionalCandidateCount, c.candidateConfiguration.maximumCandidateCount)
        XCTAssertTrue(c.isValid)
    }

    func testEqualProvisionalAndFinalLimitsAreValid() {
        var c = AnthemStructuralAnalysisConfiguration()
        c.candidateConfiguration.maximumCandidateCount = 5
        c.provisionalCandidateCount = 5
        XCTAssertTrue(c.isValid)
    }

    func testProvisionalPoolBelowFinalLimitIsInvalid() {
        var c = AnthemStructuralAnalysisConfiguration()
        c.candidateConfiguration.maximumCandidateCount = 5
        c.provisionalCandidateCount = 4
        XCTAssertFalse(c.isValid)
    }

    func testZeroAndNegativeProvisionalLimitsAreInvalid() {
        var c = AnthemStructuralAnalysisConfiguration()
        c.provisionalCandidateCount = 0
        XCTAssertFalse(c.isValid)
        c.provisionalCandidateCount = -1
        XCTAssertFalse(c.isValid)
    }

    func testFinalResultCountRemainsBounded() {
        var c = AnthemStructuralAnalysisConfiguration()
        c.provisionalCandidateCount = 20
        c.candidateConfiguration.maximumCandidateCount = 3
        let samples = (0..<40).map { Float(($0 % 7) + 1) / 8 }
        let result = AnthemStructuralAnalysisPipeline.analyse(waveformSamples: samples, trackDuration: 400, configuration: c)
        XCTAssertLessThanOrEqual(result.candidates.count, 3)
    }

    func testCompositeScorerCanPromoteSixthEnergyCandidate() {
        let candidates = [
            AnthemCandidate(startTime: 0, endTime: 10, score: 0.90),
            AnthemCandidate(startTime: 20, endTime: 30, score: 0.86),
            AnthemCandidate(startTime: 40, endTime: 50, score: 0.82),
            AnthemCandidate(startTime: 60, endTime: 70, score: 0.78),
            AnthemCandidate(startTime: 80, endTime: 90, score: 0.74),
            AnthemCandidate(startTime: 100, endTime: 110, score: 0.70)
        ]
        let strengths: [Float] = [0.20,0.20,0.20,0.20,0.20,1.00]
        let structural = zip(candidates, strengths).map { candidate, strength in
            AnthemStructuralEvidence(candidate: candidate, riseStrength: 0, fallStrength: 0, sustainStrength: strength, localPeakStrength: 0, plateauStrength: strength, repetitionSimilarity: strength, repetitionStrength: strength, repetitionMatchCount: 2, structuralStrength: strength)
        }
        let ranked = AnthemCompositeCandidateScorer.rank(candidates: candidates, structuralEvidence: structural)
        let final = Array(ranked.prefix(5))
        XCTAssertFalse(Array(candidates.prefix(5)).contains(candidates[5]))
        XCTAssertTrue(final.contains(where: { $0.candidate == candidates[5] }))
    }

    func testPipelineIsDeterministicWithBroaderPool() {
        var c = AnthemStructuralAnalysisConfiguration()
        c.provisionalCandidateCount = 10
        let samples = (0..<40).map { Float(($0 % 9) + 1) / 10 }
        XCTAssertEqual(
            AnthemStructuralAnalysisPipeline.analyse(waveformSamples: samples, trackDuration: 400, configuration: c),
            AnthemStructuralAnalysisPipeline.analyse(waveformSamples: samples, trackDuration: 400, configuration: c)
        )
    }
}
