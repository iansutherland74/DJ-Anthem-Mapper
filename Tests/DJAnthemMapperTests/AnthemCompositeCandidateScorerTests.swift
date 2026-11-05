import XCTest
@testable import DJAnthemMapper

final class AnthemCompositeCandidateScorerTests: XCTestCase {
    private func candidate(_ start: Double, _ end: Double, score: Float) -> AnthemCandidate {
        AnthemCandidate(startTime: start, endTime: end, score: score)
    }

    private func evidence(for candidate: AnthemCandidate, strength: Float) -> AnthemStructuralEvidence {
        AnthemStructuralEvidence(
            candidate: candidate,
            riseStrength: 0,
            fallStrength: 0,
            sustainStrength: 0,
            localPeakStrength: 0,
            plateauStrength: 0,
            repetitionSimilarity: 0,
            repetitionStrength: 0,
            repetitionMatchCount: 0,
            structuralStrength: strength
        )
    }

    func testDefaultScoringUsesSixtyFiveThirtyFiveBlend() {
        let c = candidate(0, 10, score: 0.8)
        let result = AnthemCompositeCandidateScorer.rank(candidates: [c], structuralEvidence: [evidence(for: c, strength: 0.6)])
        XCTAssertEqual(result[0].compositeScore, 0.73, accuracy: 0.0001)
    }

    func testCompositeScoreRemainsNormalised() {
        let c = candidate(0, 10, score: 1)
        let result = AnthemCompositeCandidateScorer.rank(candidates: [c], structuralEvidence: [evidence(for: c, strength: 1)])
        XCTAssertTrue((0...1).contains(result[0].compositeScore))
    }

    func testStrongStructureCanRerankSlightlyLowerOriginalCandidate() {
        let spike = candidate(0, 10, score: 0.85)
        let repeated = candidate(20, 30, score: 0.75)
        let result = AnthemCompositeCandidateScorer.rank(
            candidates: [spike, repeated],
            structuralEvidence: [evidence(for: spike, strength: 0.1), evidence(for: repeated, strength: 0.9)]
        )
        XCTAssertEqual(result.first?.candidate, repeated)
    }

    func testClearlySuperiorOriginalCandidateRemainsCompetitive() {
        let strong = candidate(0, 10, score: 1.0)
        let weak = candidate(20, 30, score: 0.2)
        let result = AnthemCompositeCandidateScorer.rank(
            candidates: [weak, strong],
            structuralEvidence: [evidence(for: weak, strength: 1), evidence(for: strong, strength: 0)]
        )
        XCTAssertEqual(result.first?.candidate, strong)
    }

    func testMissingStructuralEvidenceUsesZeroWithoutDroppingCandidate() {
        let c = candidate(0, 10, score: 0.8)
        let result = AnthemCompositeCandidateScorer.rank(candidates: [c], structuralEvidence: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].structuralStrength, 0, accuracy: 0.0001)
        XCTAssertNil(result[0].structuralEvidence)
    }

    func testCompositeTieUsesOriginalScore() {
        var config = AnthemCompositeScoringConfiguration()
        config.candidateWeight = 0.5
        config.structuralWeight = 0.5
        let a = candidate(0, 10, score: 0.8)
        let b = candidate(20, 30, score: 0.7)
        let result = AnthemCompositeCandidateScorer.rank(
            candidates: [b, a],
            structuralEvidence: [evidence(for: a, strength: 0.2), evidence(for: b, strength: 0.3)],
            configuration: config
        )
        XCTAssertEqual(result.first?.candidate, a)
    }

    func testFullTieUsesEarlierTimelinePosition() {
        let early = candidate(0, 10, score: 0.5)
        let late = candidate(20, 30, score: 0.5)
        let result = AnthemCompositeCandidateScorer.rank(candidates: [late, early], structuralEvidence: [])
        XCTAssertEqual(result.map(\.candidate), [early, late])
    }

    func testInputOrderCannotChangeResult() {
        let a = candidate(0, 10, score: 0.7)
        let b = candidate(20, 30, score: 0.8)
        let evidenceList = [evidence(for: a, strength: 0.8), evidence(for: b, strength: 0.4)]
        XCTAssertEqual(
            AnthemCompositeCandidateScorer.rank(candidates: [a, b], structuralEvidence: evidenceList),
            AnthemCompositeCandidateScorer.rank(candidates: [b, a], structuralEvidence: evidenceList)
        )
    }

    func testInvalidWeightsAreRejected() {
        let c = candidate(0, 10, score: 0.8)
        var zero = AnthemCompositeScoringConfiguration()
        zero.candidateWeight = 0
        zero.structuralWeight = 0
        XCTAssertTrue(AnthemCompositeCandidateScorer.rank(candidates: [c], structuralEvidence: [], configuration: zero).isEmpty)

        var negative = AnthemCompositeScoringConfiguration()
        negative.candidateWeight = -1
        XCTAssertTrue(AnthemCompositeCandidateScorer.rank(candidates: [c], structuralEvidence: [], configuration: negative).isEmpty)
    }

    func testCustomWeightsAreNormalised() {
        let c = candidate(0, 10, score: 0.8)
        var config = AnthemCompositeScoringConfiguration()
        config.candidateWeight = 65
        config.structuralWeight = 35
        let result = AnthemCompositeCandidateScorer.rank(candidates: [c], structuralEvidence: [evidence(for: c, strength: 0.6)], configuration: config)
        XCTAssertEqual(result[0].compositeScore, 0.73, accuracy: 0.0001)
    }

    func testRepeatedScoringIsDeterministic() {
        let c = candidate(0, 10, score: 0.8)
        let e = evidence(for: c, strength: 0.6)
        XCTAssertEqual(
            AnthemCompositeCandidateScorer.rank(candidates: [c], structuralEvidence: [e]),
            AnthemCompositeCandidateScorer.rank(candidates: [c], structuralEvidence: [e])
        )
    }

    func testOriginalCandidateAndEvidenceArePreserved() {
        let c = candidate(0, 10, score: 0.8)
        let e = evidence(for: c, strength: 0.6)
        let result = AnthemCompositeCandidateScorer.rank(candidates: [c], structuralEvidence: [e])[0]
        XCTAssertEqual(result.candidate, c)
        XCTAssertEqual(result.structuralEvidence, e)
        XCTAssertEqual(result.originalScore, c.score, accuracy: 0.0001)
    }

    func testNonFiniteCandidateIsDiscardedSafely() {
        let bad = candidate(0, 10, score: .nan)
        XCTAssertTrue(AnthemCompositeCandidateScorer.rank(candidates: [bad], structuralEvidence: []).isEmpty)
    }
}
