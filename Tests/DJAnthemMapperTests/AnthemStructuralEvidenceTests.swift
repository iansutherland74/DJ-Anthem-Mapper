import XCTest
@testable import DJAnthemMapper

final class AnthemStructuralEvidenceTests: XCTestCase {
    private func candidate(_ start: Double, _ end: Double) -> AnthemCandidate {
        AnthemCandidate(startTime: start, endTime: end, score: 0.8)
    }

    private func frames(_ values: [Float]) -> [AnthemAnalysisFrame] {
        AnthemAnalysisFoundation.frames(from: values, trackDuration: Double(max(1, values.count)))
    }

    func testCandidateReceivesTransitionMeasurements() {
        let f = frames([0.1, 0.1, 0.8, 0.9, 0.8])
        let t = AnthemEnergyTransitionAnalyser.analyse(frames: f)
        let result = AnthemStructuralEvidenceAnalyser.analyse(candidate: candidate(2, 5), frames: f, transitions: t, repetitions: [])
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result?.riseStrength ?? 0, 0.6)
        XCTAssertGreaterThan(result?.sustainStrength ?? 0, 0.5)
    }

    func testRepetitionEvidenceIsAssociated() {
        let f = frames([0.1,0.4,0.9,0.5,0.2,0.2,0.2,0.2,0.1,0.4,0.9,0.5])
        let t = AnthemEnergyTransitionAnalyser.analyse(frames: f)
        let r = AnthemRepetitionAnalyser.analyse(frames: f)
        let result = AnthemStructuralEvidenceAnalyser.analyse(candidate: candidate(0, 4), frames: f, transitions: t, repetitions: r)
        XCTAssertGreaterThan(result?.repetitionSimilarity ?? 0, 0.9)
        XCTAssertGreaterThan(result?.repetitionMatchCount ?? 0, 0)
    }

    func testUniqueSpikeHasPeakButNoRequiredRepetition() {
        let f = frames([0.1,0.1,1.0,0.1,0.2,0.3])
        let t = AnthemEnergyTransitionAnalyser.analyse(frames: f)
        let result = AnthemStructuralEvidenceAnalyser.analyse(candidate: candidate(1, 4), frames: f, transitions: t, repetitions: [])
        XCTAssertGreaterThan(result?.localPeakStrength ?? 0, 0.8)
        XCTAssertEqual(result?.repetitionStrength ?? -1, 0, accuracy: 0.0001)
    }

    func testMissingTransitionEvidenceIsNeutral() {
        let f = frames([0.2,0.8,0.2])
        let result = AnthemStructuralEvidenceAnalyser.analyse(candidate: candidate(0, 3), frames: f, transitions: [], repetitions: [])
        XCTAssertEqual(result?.riseStrength ?? -1, 0, accuracy: 0.0001)
        XCTAssertEqual(result?.sustainStrength ?? -1, 0, accuracy: 0.0001)
    }

    func testFlatLoudSectionHasNoFalseRise() {
        let f = frames([0.9,0.9,0.9,0.9])
        let t = AnthemEnergyTransitionAnalyser.analyse(frames: f)
        let result = AnthemStructuralEvidenceAnalyser.analyse(candidate: candidate(0, 4), frames: f, transitions: t, repetitions: [])
        XCTAssertEqual(result?.riseStrength ?? -1, 0, accuracy: 0.0001)
    }

    func testSilenceIsSafeAndBounded() {
        let f = frames([0,0,0,0])
        let t = AnthemEnergyTransitionAnalyser.analyse(frames: f)
        let result = AnthemStructuralEvidenceAnalyser.analyse(candidate: candidate(0, 4), frames: f, transitions: t, repetitions: [])
        XCTAssertNotNil(result)
        XCTAssertTrue((0...1).contains(result?.structuralStrength ?? -1))
    }

    func testTrackStartAndEndCandidatesWork() {
        let f = frames([0.8,0.2,0.2,0.8])
        let t = AnthemEnergyTransitionAnalyser.analyse(frames: f)
        XCTAssertNotNil(AnthemStructuralEvidenceAnalyser.analyse(candidate: candidate(0, 1), frames: f, transitions: t, repetitions: []))
        XCTAssertNotNil(AnthemStructuralEvidenceAnalyser.analyse(candidate: candidate(3, 4), frames: f, transitions: t, repetitions: []))
    }

    func testInvalidCandidateIsRejected() {
        let f = frames([0.5])
        XCTAssertNil(AnthemStructuralEvidenceAnalyser.analyse(candidate: candidate(1, 1), frames: f, transitions: [], repetitions: []))
    }

    func testAllNormalisedOutputsStayBounded() {
        let f = frames([0,1,0.2,0.9,0])
        let t = AnthemEnergyTransitionAnalyser.analyse(frames: f)
        let result = AnthemStructuralEvidenceAnalyser.analyse(candidate: candidate(0, 5), frames: f, transitions: t, repetitions: [])!
        let values = [result.riseStrength, result.fallStrength, result.sustainStrength, result.localPeakStrength, result.plateauStrength, result.repetitionSimilarity, result.repetitionStrength, result.structuralStrength]
        XCTAssertTrue(values.allSatisfy { $0.isFinite && (0...1).contains($0) })
    }

    func testAnalysisIsDeterministic() {
        let f = frames([0.1,0.8,0.9,0.2])
        let t = AnthemEnergyTransitionAnalyser.analyse(frames: f)
        let c = candidate(0, 4)
        XCTAssertEqual(AnthemStructuralEvidenceAnalyser.analyse(candidate: c, frames: f, transitions: t, repetitions: []), AnthemStructuralEvidenceAnalyser.analyse(candidate: c, frames: f, transitions: t, repetitions: []))
    }

    func testCandidateIsPreservedExactly() {
        let f = frames([0.1,0.8,0.9,0.2])
        let t = AnthemEnergyTransitionAnalyser.analyse(frames: f)
        let c = candidate(1, 3)
        XCTAssertEqual(AnthemStructuralEvidenceAnalyser.analyse(candidate: c, frames: f, transitions: t, repetitions: [])?.candidate, c)
    }

    func testMismatchedTransitionCountIsSafe() {
        let f = frames([0.1,0.8,0.2])
        let t = Array(AnthemEnergyTransitionAnalyser.analyse(frames: f).prefix(1))
        XCTAssertNotNil(AnthemStructuralEvidenceAnalyser.analyse(candidate: candidate(0, 3), frames: f, transitions: t, repetitions: []))
    }
}
