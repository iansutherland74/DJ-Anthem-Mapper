import XCTest
@testable import DJAnthemMapper

final class AnthemCandidateEvidenceTests: XCTestCase {
    private func candidate(_ start: Double, _ end: Double, score: Float = 0.8) -> AnthemCandidate {
        AnthemCandidate(startTime: start, endTime: end, score: score)
    }

    func testObviousHighEnergySectionHasStrongEvidence() {
        let frames = AnthemAnalysisFoundation.frames(from: [0.1, 0.1, 0.9, 1.0, 0.1, 0.1], trackDuration: 60)
        let result = AnthemCandidateEvidenceAnalyser.analyse(candidate: candidate(20, 40), frames: frames)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.meanEnergy ?? 0, 0.95, accuracy: 0.0001)
        XCTAssertEqual(result?.peakEnergy ?? 0, 1.0, accuracy: 0.0001)
        XCTAssertGreaterThan(result?.surroundingContrast ?? 0, 0.9)
        XCTAssertGreaterThanOrEqual(result?.confidence ?? .low, .medium)
    }

    func testUniformlyLoudTrackHasWeakContrast() {
        let frames = AnthemAnalysisFoundation.frames(from: [0.9, 0.9, 0.9, 0.9], trackDuration: 40)
        let result = AnthemCandidateEvidenceAnalyser.analyse(candidate: candidate(10, 30), frames: frames)
        XCTAssertEqual(result?.surroundingContrast ?? -1, 0.5, accuracy: 0.0001)
    }

    func testSilenceProducesBoundedEvidence() {
        let frames = AnthemAnalysisFoundation.frames(from: [0, 0, 0], trackDuration: 30)
        let result = AnthemCandidateEvidenceAnalyser.analyse(candidate: candidate(0, 10), frames: frames)
        XCTAssertNotNil(result)
        XCTAssertTrue((0...1).contains(result?.score ?? -1))
        XCTAssertEqual(result?.meanEnergy ?? -1, 0, accuracy: 0.0001)
    }

    func testScoreAlwaysNormalised() {
        let frames = AnthemAnalysisFoundation.frames(from: [0, 1, 1, 0], trackDuration: 40)
        let result = AnthemCandidateEvidenceAnalyser.analyse(candidate: candidate(10, 30), frames: frames)
        XCTAssertTrue((0...1).contains(result?.score ?? -1))
    }

    func testIdenticalInputIsDeterministic() {
        let frames = AnthemAnalysisFoundation.frames(from: [0.2, 0.8, 0.8, 0.2], trackDuration: 40)
        let item = candidate(10, 30)
        XCTAssertEqual(AnthemCandidateEvidenceAnalyser.analyse(candidate: item, frames: frames), AnthemCandidateEvidenceAnalyser.analyse(candidate: item, frames: frames))
    }

    func testBeginningAndEndCandidatesAreSupported() {
        let frames = AnthemAnalysisFoundation.frames(from: [0.8, 0.2, 0.2, 0.8], trackDuration: 40)
        XCTAssertNotNil(AnthemCandidateEvidenceAnalyser.analyse(candidate: candidate(0, 10), frames: frames))
        XCTAssertNotNil(AnthemCandidateEvidenceAnalyser.analyse(candidate: candidate(30, 40), frames: frames))
    }

    func testInvalidCandidateOrFramesAreRejected() {
        let frames = AnthemAnalysisFoundation.frames(from: [1], trackDuration: 1)
        XCTAssertNil(AnthemCandidateEvidenceAnalyser.analyse(candidate: candidate(1, 1), frames: frames))
        XCTAssertNil(AnthemCandidateEvidenceAnalyser.analyse(candidate: candidate(0, 1), frames: []))
    }

    func testConfidenceThresholdsAreOrdered() {
        XCTAssertLessThan(AnthemCandidateConfidence.low, .medium)
        XCTAssertLessThan(AnthemCandidateConfidence.medium, .high)
    }
}

extension AnthemCandidateEvidenceTests {
    func testEvidenceMeanEnergyUsesDurationWeighting() {
        let frames = [AnthemAnalysisFrame(startTime: 0, duration: 1, energy: 1), AnthemAnalysisFrame(startTime: 1, duration: 3, energy: 0)]
        let c = AnthemCandidate(startTime: 0, endTime: 4, score: 0.25)
        let result = AnthemCandidateEvidenceAnalyser.analyse(candidate: c, frames: frames)
        XCTAssertEqual(result?.meanEnergy ?? -1, 0.25, accuracy: 0.0001)
    }
}
