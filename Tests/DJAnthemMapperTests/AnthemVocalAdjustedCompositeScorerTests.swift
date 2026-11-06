import XCTest
@testable import DJAnthemMapper

final class AnthemVocalAdjustedCompositeScorerTests: XCTestCase {
    private func candidate(_ start: Double, _ score: Float) -> AnthemCandidate { .init(startTime: start, endTime: start + 10, score: score) }
    private func structural(_ c: AnthemCandidate, _ strength: Float) -> AnthemStructuralEvidence {
        .init(candidate: c, riseStrength: 0, fallStrength: 0, sustainStrength: 0, localPeakStrength: 0, plateauStrength: 0, repetitionSimilarity: 0, repetitionStrength: 0, repetitionMatchCount: 0, structuralStrength: strength)
    }
    private func baseline(_ c: AnthemCandidate, structural strength: Float = 0.6) -> AnthemCompositeCandidate {
        AnthemCompositeCandidateScorer.rank(candidates: [c], structuralEvidence: [structural(c, strength)])[0]
    }
    private func transition(_ strength: Float, start: Double) -> AnthemVocalTransitionEvidence {
        .init(startTime: start, endTime: start + 1, riseStrength: strength, fallStrength: 0, entryStrength: 0, exitStrength: 0)
    }
    private func vocal(_ c: AnthemCandidate, strength: Float) -> AnthemCandidateVocalEvidence {
        .init(candidateStartTime: c.startTime, candidateEndTime: c.endTime, transitionEvidence: [transition(strength, start: c.startTime)], sustainedEvidence: [])
    }
    func testMissingVocalEvidenceReproducesBaselineExactly() {
        let a = candidate(0, 0.8), b = candidate(20, 0.7)
        let base = AnthemCompositeCandidateScorer.rank(candidates: [a,b], structuralEvidence: [structural(a,0.6), structural(b,0.9)])
        let result = AnthemVocalAdjustedCompositeScorer.rank(baseline: base, vocalEvidence: [])
        XCTAssertEqual(result.map(\.baseline), base)
        XCTAssertEqual(result.map(\.adjustedCompositeScore), base.map(\.compositeScore))
        XCTAssertTrue(result.allSatisfy { $0.vocalScore == nil && $0.vocalAdjustment == 0 })
    }
    func testNeutralVocalStrengthProducesZeroAdjustment() {
        let c = candidate(0,0.8); let result = AnthemVocalAdjustedCompositeScorer.rank(baseline:[baseline(c)], vocalEvidence:[vocal(c,strength:0.5)])[0]
        XCTAssertEqual(result.vocalAdjustment,0,accuracy:0.000001); XCTAssertEqual(result.adjustedCompositeScore,result.baseline.compositeScore,accuracy:0.000001)
    }
    func testStrongVocalEvidenceRaisesByMaximum() {
        let c=candidate(0,0.6); let r=AnthemVocalAdjustedCompositeScorer.rank(baseline:[baseline(c)],vocalEvidence:[vocal(c,strength:1)])[0]
        XCTAssertEqual(r.vocalAdjustment,0.10,accuracy:0.000001)
    }
    func testWeakRealVocalEvidenceLowersByMaximum() {
        let c=candidate(0,0.6); let r=AnthemVocalAdjustedCompositeScorer.rank(baseline:[baseline(c)],vocalEvidence:[vocal(c,strength:0)])[0]
        XCTAssertEqual(r.vocalAdjustment,-0.10,accuracy:0.000001)
    }
    func testQuarterAndThreeQuarterStrengthUseHalfAdjustment() {
        let a=candidate(0,0.6), b=candidate(20,0.6)
        let r=AnthemVocalAdjustedCompositeScorer.rank(baseline:[baseline(a),baseline(b)],vocalEvidence:[vocal(a,strength:0.75),vocal(b,strength:0.25)])
        let ar=r.first{$0.baseline.candidate==a}!, br=r.first{$0.baseline.candidate==b}!
        XCTAssertEqual(ar.vocalAdjustment,0.05,accuracy:0.000001); XCTAssertEqual(br.vocalAdjustment,-0.05,accuracy:0.000001)
    }
    func testFinalScoreIsClampedToUnitRange() {
        let high=candidate(0,1), low=candidate(20,0)
        let r=AnthemVocalAdjustedCompositeScorer.rank(baseline:[baseline(high,structural:1),baseline(low,structural:0)],vocalEvidence:[vocal(high,strength:1),vocal(low,strength:0)])
        XCTAssertTrue(r.allSatisfy{(0...1).contains($0.adjustedCompositeScore)})
    }
    func testEmptyAssociationCountsAsMissingNotNegative() {
        let c=candidate(0,0.8); let empty=AnthemCandidateVocalEvidence(candidateStartTime:c.startTime,candidateEndTime:c.endTime,transitionEvidence:[],sustainedEvidence:[])
        let r=AnthemVocalAdjustedCompositeScorer.rank(baseline:[baseline(c)],vocalEvidence:[empty])[0]
        XCTAssertNil(r.vocalScore); XCTAssertEqual(r.vocalAdjustment,0); XCTAssertEqual(r.adjustedCompositeScore,r.baseline.compositeScore)
    }
    func testAdjustmentCanRerankCloseCandidates() {
        let a=candidate(0,0.70), b=candidate(20,0.69)
        let base=AnthemCompositeCandidateScorer.rank(candidates:[a,b],structuralEvidence:[structural(a,0.5),structural(b,0.5)])
        let r=AnthemVocalAdjustedCompositeScorer.rank(baseline:base,vocalEvidence:[vocal(a,strength:0),vocal(b,strength:1)])
        XCTAssertEqual(r.first?.baseline.candidate,b)
    }
    func testInputOrderCannotChangeRanking() {
        let a=candidate(0,0.7), b=candidate(20,0.7); let base=[baseline(a),baseline(b)]; let vocals=[vocal(a,strength:0.8),vocal(b,strength:0.2)]
        XCTAssertEqual(AnthemVocalAdjustedCompositeScorer.rank(baseline:base,vocalEvidence:vocals),AnthemVocalAdjustedCompositeScorer.rank(baseline:base.reversed(),vocalEvidence:vocals.reversed()))
    }
    func testInvalidConfigurationIsRejected() {
        let c=candidate(0,0.8); var config=AnthemVocalAdjustmentConfiguration(); config.maximumAdjustment = -1
        XCTAssertTrue(AnthemVocalAdjustedCompositeScorer.rank(baseline:[baseline(c)],vocalEvidence:[],configuration:config).isEmpty)
        config = .init(); config.neutralStrength = 1
        XCTAssertTrue(AnthemVocalAdjustedCompositeScorer.rank(baseline:[baseline(c)],vocalEvidence:[],configuration:config).isEmpty)
    }
    func testRepeatedScoringIsDeterministic() {
        let c=candidate(0,0.8), base=[baseline(c)], vocals=[vocal(c,strength:0.8)]
        XCTAssertEqual(AnthemVocalAdjustedCompositeScorer.rank(baseline:base,vocalEvidence:vocals),AnthemVocalAdjustedCompositeScorer.rank(baseline:base,vocalEvidence:vocals))
    }
}
