import XCTest
@testable import DJAnthemMapper

final class AnthemEvidenceAssociationTests: XCTestCase {
    private func candidate(_ start: Double, _ end: Double) -> AnthemCandidate { .init(startTime: start, endTime: end, score: 0.7) }
    private func transition(_ start: Double, _ end: Double, rise: Float) -> AnthemEnergyTransitionEvidence {
        .init(startTime: start, endTime: end, riseStrength: rise, fallStrength: 0, sustainStrength: 0, localPeakStrength: 0, plateauStrength: 0)
    }
    private func repetition(_ start: Double, _ end: Double, strength: Float = 1) -> AnthemRepetitionEvidence {
        .init(sourceStartTime: start, sourceEndTime: end, bestSimilarity: strength, repetitionStrength: strength, matches: [])
    }
    private let frames = [AnthemAnalysisFrame(startTime: 0, duration: 40, energy: 0.5)]

    func testReorderedTransitionEvidenceProducesIdenticalResult() {
        let c = candidate(10, 30)
        let t = [transition(0,10,rise:0.1), transition(10,20,rise:0.8), transition(20,30,rise:0.4)]
        XCTAssertEqual(
            AnthemStructuralEvidenceAnalyser.analyse(candidate: c, frames: frames, transitions: t, repetitions: []),
            AnthemStructuralEvidenceAnalyser.analyse(candidate: c, frames: frames, transitions: t.reversed(), repetitions: [])
        )
    }

    func testMissingMiddleTransitionDoesNotShiftLaterEvidence() {
        let c = candidate(20, 30)
        let result = AnthemStructuralEvidenceAnalyser.analyse(candidate: c, frames: frames, transitions: [transition(0,10,rise:0.9), transition(20,30,rise:0.4)], repetitions: [])
        XCTAssertEqual(result?.riseStrength ?? -1, 0.4, accuracy: 0.0001)
    }

    func testTinyRepetitionOverlapIsRejected() {
        let c = candidate(10, 30)
        let result = AnthemStructuralEvidenceAnalyser.analyse(candidate: c, frames: frames, transitions: [], repetitions: [repetition(29,33)])
        XCTAssertEqual(result?.repetitionStrength ?? -1, 0, accuracy: 0.0001)
    }

    func testFullShorterRangeCoverageIsAccepted() {
        let c = candidate(10, 30)
        let result = AnthemStructuralEvidenceAnalyser.analyse(candidate: c, frames: frames, transitions: [], repetitions: [repetition(26,30)])
        XCTAssertEqual(result?.repetitionStrength ?? -1, 1, accuracy: 0.0001)
    }

    func testExactCoverageThresholdIsAccepted() {
        let c = candidate(10, 30)
        let result = AnthemStructuralEvidenceAnalyser.analyse(candidate: c, frames: frames, transitions: [], repetitions: [repetition(28,32)])
        XCTAssertEqual(result?.repetitionStrength ?? -1, 1, accuracy: 0.0001)
    }

    func testInvalidCoverageConfigurationRejected() {
        var config = AnthemStructuralEvidenceConfiguration()
        config.minimumRepetitionCoverageRatio = 0
        XCTAssertNil(AnthemStructuralEvidenceAnalyser.analyse(candidate: candidate(10,30), frames: frames, transitions: [], repetitions: [], configuration: config))
    }
}
