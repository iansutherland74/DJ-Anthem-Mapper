import XCTest
@testable import DJAnthemMapper

final class AnthemVocalEvidenceAssociationTests: XCTestCase {
    private func transition(_ start: Double, _ end: Double, strength: Float = 0.5) -> AnthemVocalTransitionEvidence {
        .init(
            startTime: start,
            endTime: end,
            riseStrength: strength,
            fallStrength: strength,
            entryStrength: strength,
            exitStrength: strength
        )
    }

    private func sustained(_ start: Double, _ end: Double, strength: Float = 0.5) -> AnthemSustainedVocalEvidence {
        .init(
            startTime: start,
            endTime: end,
            energyStrength: strength,
            activityStrength: strength,
            sustainedStrength: strength
        )
    }

    private func associate(
        transitions: [AnthemVocalTransitionEvidence] = [],
        sustained: [AnthemSustainedVocalEvidence] = []
    ) -> AnthemCandidateVocalEvidence? {
        AnthemVocalEvidenceAssociation.associate(
            candidateStartTime: 10,
            candidateEndTime: 20,
            transitionEvidence: transitions,
            sustainedEvidence: sustained
        )
    }

    func testEvidenceCompletelyInsideCandidateAssociates() {
        XCTAssertEqual(associate(transitions: [transition(12, 13)])?.transitionEvidence.count, 1)
    }

    func testEvidenceSpanningCandidateStartAssociates() {
        XCTAssertEqual(associate(transitions: [transition(9, 11)])?.transitionEvidence.count, 1)
    }

    func testEvidenceSpanningCandidateEndAssociates() {
        XCTAssertEqual(associate(transitions: [transition(19, 21)])?.transitionEvidence.count, 1)
    }

    func testEvidenceEncompassingCandidateAssociates() {
        XCTAssertEqual(associate(transitions: [transition(5, 25)])?.transitionEvidence.count, 1)
    }

    func testEvidenceEndingAtCandidateStartDoesNotAssociate() {
        XCTAssertTrue(associate(transitions: [transition(9, 10)])?.transitionEvidence.isEmpty == true)
    }

    func testEvidenceStartingAtCandidateEndDoesNotAssociate() {
        XCTAssertTrue(associate(transitions: [transition(20, 21)])?.transitionEvidence.isEmpty == true)
    }

    func testEvidenceStartingAtCandidateStartAssociates() {
        XCTAssertEqual(associate(transitions: [transition(10, 11)])?.transitionEvidence.count, 1)
    }

    func testEvidenceEndingAtCandidateEndAssociates() {
        XCTAssertEqual(associate(transitions: [transition(19, 20)])?.transitionEvidence.count, 1)
    }

    func testTransitionEvidenceAssociatesIndependently() {
        let result = associate(transitions: [transition(11, 12)])
        XCTAssertEqual(result?.transitionEvidence.count, 1)
        XCTAssertTrue(result?.sustainedEvidence.isEmpty == true)
    }

    func testSustainedEvidenceAssociatesIndependently() {
        let result = associate(sustained: [sustained(11, 12)])
        XCTAssertTrue(result?.transitionEvidence.isEmpty == true)
        XCTAssertEqual(result?.sustainedEvidence.count, 1)
    }

    func testBothEvidenceFormsCanCoexist() {
        let result = associate(
            transitions: [transition(11, 12)],
            sustained: [sustained(13, 14)]
        )
        XCTAssertEqual(result?.transitionEvidence.count, 1)
        XCTAssertEqual(result?.sustainedEvidence.count, 1)
    }

    func testEmptyEvidenceReturnsValidEmptyAssociation() {
        let result = associate()
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.transitionEvidence.isEmpty == true)
        XCTAssertTrue(result?.sustainedEvidence.isEmpty == true)
    }

    func testInvalidCandidateRangesAreRejected() {
        let invalid: [(Double, Double)] = [
            (20, 10), (10, 10), (-1, 10), (.nan, 10), (10, .infinity)
        ]
        for (start, end) in invalid {
            XCTAssertNil(AnthemVocalEvidenceAssociation.associate(
                candidateStartTime: start,
                candidateEndTime: end,
                transitionEvidence: [],
                sustainedEvidence: []
            ))
        }
    }

    func testInvalidEvidenceRangesAreIgnored() {
        let result = associate(
            transitions: [transition(11, 11), transition(-1, 12)],
            sustained: [sustained(13, 13), sustained(-1, 14)]
        )
        XCTAssertTrue(result?.transitionEvidence.isEmpty == true)
        XCTAssertTrue(result?.sustainedEvidence.isEmpty == true)
    }

    func testTransitionEvidenceIsOrderedDeterministically() {
        let input = [transition(15, 16), transition(11, 12), transition(13, 14)]
        XCTAssertEqual(associate(transitions: input)?.transitionEvidence.map(\.startTime), [11, 13, 15])
        XCTAssertEqual(associate(transitions: input)?.transitionEvidence, associate(transitions: input.reversed())?.transitionEvidence)
    }

    func testSustainedEvidenceIsOrderedDeterministically() {
        let input = [sustained(15, 16), sustained(11, 12), sustained(13, 14)]
        XCTAssertEqual(associate(sustained: input)?.sustainedEvidence.map(\.startTime), [11, 13, 15])
        XCTAssertEqual(associate(sustained: input)?.sustainedEvidence, associate(sustained: input.reversed())?.sustainedEvidence)
    }

    func testSameStartUsesEndTimeTieBreaker() {
        let transitions = [transition(11, 14), transition(11, 12), transition(11, 13)]
        let sustainedEvidence = [sustained(15, 18), sustained(15, 16), sustained(15, 17)]
        XCTAssertEqual(associate(transitions: transitions)?.transitionEvidence.map(\.endTime), [12, 13, 14])
        XCTAssertEqual(associate(sustained: sustainedEvidence)?.sustainedEvidence.map(\.endTime), [16, 17, 18])
    }

    func testRepeatedAssociationIsDeterministic() {
        let transitions = [transition(11, 12, strength: 0.8)]
        let sustainedEvidence = [sustained(13, 14, strength: 0.9)]
        XCTAssertEqual(
            associate(transitions: transitions, sustained: sustainedEvidence),
            associate(transitions: transitions, sustained: sustainedEvidence)
        )
    }

    func testAssociationPreservesOriginalEvidenceRangesAndStrengths() {
        let sourceTransition = transition(9.5, 10.5, strength: 0.8)
        let sourceSustained = sustained(19.5, 20.5, strength: 0.9)
        let result = associate(transitions: [sourceTransition], sustained: [sourceSustained])
        XCTAssertEqual(result?.transitionEvidence, [sourceTransition])
        XCTAssertEqual(result?.sustainedEvidence, [sourceSustained])
    }

    func testCandidateRangeIsPreserved() {
        let result = associate()
        XCTAssertEqual(result?.candidateStartTime, 10)
        XCTAssertEqual(result?.candidateEndTime, 20)
    }
}
