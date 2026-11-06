import XCTest
@testable import DJAnthemMapper

final class AnthemVocalCandidateScorerTests: XCTestCase {
    private func transition(rise: Float = 0, fall: Float = 0, entry: Float = 0, exit: Float = 0, start: Double = 0) -> AnthemVocalTransitionEvidence {
        .init(startTime: start, endTime: start + 1, riseStrength: rise, fallStrength: fall, entryStrength: entry, exitStrength: exit)
    }
    private func sustained(_ strength: Float, start: Double = 0) -> AnthemSustainedVocalEvidence {
        .init(startTime: start, endTime: start + 1, energyStrength: strength, activityStrength: strength, sustainedStrength: strength)
    }
    private func evidence(transitions: [AnthemVocalTransitionEvidence] = [], sustained: [AnthemSustainedVocalEvidence] = [], start: Double = 0, end: Double = 10) -> AnthemCandidateVocalEvidence {
        .init(candidateStartTime: start, candidateEndTime: end, transitionEvidence: transitions, sustainedEvidence: sustained)
    }

    func testRiseFallEntryAndExitCanEachDriveTransitionStrength() {
        XCTAssertEqual(AnthemVocalCandidateScorer.score(evidence: evidence(transitions: [transition(rise: 0.8)])).transitionStrength, 0.8, accuracy: 0.000001)
        XCTAssertEqual(AnthemVocalCandidateScorer.score(evidence: evidence(transitions: [transition(fall: 0.7)])).transitionStrength, 0.7, accuracy: 0.000001)
        XCTAssertEqual(AnthemVocalCandidateScorer.score(evidence: evidence(transitions: [transition(entry: 0.6)])).transitionStrength, 0.6, accuracy: 0.000001)
        XCTAssertEqual(AnthemVocalCandidateScorer.score(evidence: evidence(transitions: [transition(exit: 0.5)])).transitionStrength, 0.5, accuracy: 0.000001)
    }
    func testStrongestTransitionWinsAcrossRecords() {
        let score = AnthemVocalCandidateScorer.score(evidence: evidence(transitions: [transition(rise: 0.2), transition(entry: 0.9), transition(exit: 0.4)]))
        XCTAssertEqual(score.transitionStrength, 0.9, accuracy: 0.000001)
    }
    func testNoTransitionEvidenceScoresZero() { XCTAssertEqual(AnthemVocalCandidateScorer.score(evidence: evidence()).transitionStrength, 0) }
    func testSustainedScoreIsArithmeticMean() {
        let score = AnthemVocalCandidateScorer.score(evidence: evidence(sustained: [sustained(0.2), sustained(0.8), sustained(0.5)]))
        XCTAssertEqual(score.sustainedStrength, 0.5, accuracy: 0.000001)
    }
    func testNoSustainedEvidenceScoresZero() { XCTAssertEqual(AnthemVocalCandidateScorer.score(evidence: evidence()).sustainedStrength, 0) }
    func testBothFamiliesAreEquallyCombined() {
        let score = AnthemVocalCandidateScorer.score(evidence: evidence(transitions: [transition(rise: 0.8)], sustained: [sustained(0.4)]))
        XCTAssertEqual(score.overallStrength, 0.6, accuracy: 0.000001)
    }
    func testTransitionOnlyIsNotDiluted() {
        let score = AnthemVocalCandidateScorer.score(evidence: evidence(transitions: [transition(entry: 0.8)]))
        XCTAssertEqual(score.overallStrength, 0.8, accuracy: 0.000001)
    }
    func testSustainedOnlyIsNotDiluted() {
        let score = AnthemVocalCandidateScorer.score(evidence: evidence(sustained: [sustained(0.7)]))
        XCTAssertEqual(score.overallStrength, 0.7, accuracy: 0.000001)
    }
    func testEmptyAssociationScoresZero() {
        let score = AnthemVocalCandidateScorer.score(evidence: evidence())
        XCTAssertEqual(score, .init(transitionStrength: 0, sustainedStrength: 0, overallStrength: 0))
    }
    func testInputOrderingDoesNotAffectScore() {
        let t = [transition(rise: 0.2, start: 2), transition(entry: 0.9, start: 0), transition(exit: 0.4, start: 1)]
        let s = [sustained(0.2, start: 2), sustained(0.8, start: 0), sustained(0.5, start: 1)]
        XCTAssertEqual(AnthemVocalCandidateScorer.score(evidence: evidence(transitions: t, sustained: s)), AnthemVocalCandidateScorer.score(evidence: evidence(transitions: t.reversed(), sustained: s.reversed())))
    }
    func testCandidateTimeRangeDoesNotChangeStrength() {
        let t = [transition(rise: 0.8)]
        let s = [sustained(0.4)]
        XCTAssertEqual(AnthemVocalCandidateScorer.score(evidence: evidence(transitions: t, sustained: s, start: 0, end: 10)), AnthemVocalCandidateScorer.score(evidence: evidence(transitions: t, sustained: s, start: 100, end: 200)))
    }
    func testRepeatedScoringIsDeterministic() {
        let e = evidence(transitions: [transition(rise: 0.8)], sustained: [sustained(0.4)])
        XCTAssertEqual(AnthemVocalCandidateScorer.score(evidence: e), AnthemVocalCandidateScorer.score(evidence: e))
    }
    func testAllOutputsAreBounded() {
        let score = AnthemVocalCandidateScorer.score(evidence: evidence(transitions: [transition(rise: 2, fall: -2, entry: .infinity, exit: .nan)], sustained: [sustained(2), sustained(-1)]))
        XCTAssertTrue((0...1).contains(score.transitionStrength))
        XCTAssertTrue((0...1).contains(score.sustainedStrength))
        XCTAssertTrue((0...1).contains(score.overallStrength))
        XCTAssertTrue(score.transitionStrength.isFinite && score.sustainedStrength.isFinite && score.overallStrength.isFinite)
    }
}
