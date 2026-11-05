import XCTest
@testable import DJAnthemMapper

final class AnthemEnergyTransitionAnalyserTests: XCTestCase {
    private func evidence(_ values: [Float]) -> [AnthemEnergyTransitionEvidence] {
        AnthemEnergyTransitionAnalyser.analyse(frames: AnthemAnalysisFoundation.frames(from: values, trackDuration: Double(max(1, values.count))))
    }

    func testSustainedLiftHasRiseAndSustainEvidence() {
        let result = evidence([0.1, 0.1, 0.8, 0.9, 0.8])
        XCTAssertGreaterThan(result[2].riseStrength, 0.6)
        XCTAssertGreaterThan(result[3].sustainStrength, 0.6)
    }

    func testSingleSpikeHasPeakButWeakerPlateau() {
        let result = evidence([0.1, 0.1, 1.0, 0.1, 0.1])
        XCTAssertGreaterThan(result[2].localPeakStrength, 0.8)
        XCTAssertLessThan(result[2].plateauStrength, 0.2)
    }

    func testUniformEnergyHasNoRiseFallOrPeak() {
        let result = evidence([0.9, 0.9, 0.9, 0.9])
        XCTAssertTrue(result.allSatisfy { $0.riseStrength == 0 && $0.fallStrength == 0 && $0.localPeakStrength == 0 })
    }

    func testProgressiveBuildContainsPositiveRiseEvidence() {
        let result = evidence([0.1, 0.25, 0.45, 0.7, 0.9])
        XCTAssertTrue(result.dropFirst().allSatisfy { $0.riseStrength > 0 })
    }

    func testProgressiveDropContainsPositiveFallEvidence() {
        let result = evidence([0.9, 0.8, 0.3, 0.1])
        XCTAssertTrue(result.dropLast().contains { $0.fallStrength > 0 })
    }

    func testSilenceIsFiniteAndNeutral() {
        let result = evidence([0, 0, 0, 0])
        XCTAssertTrue(result.allSatisfy { evidence in
            evidence.riseStrength == 0 && evidence.fallStrength == 0 &&
            evidence.sustainStrength == 0 && evidence.localPeakStrength == 0 &&
            evidence.plateauStrength == 0 &&
            evidence.startTime.isFinite && evidence.endTime > evidence.startTime
        })
    }

    func testEmptyInputReturnsEmptyOutput() {
        XCTAssertTrue(AnthemEnergyTransitionAnalyser.analyse(frames: []).isEmpty)
    }

    func testOneFrameInputIsSafe() {
        let result = evidence([0.7])
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].sustainStrength.isFinite)
    }

    func testNonFiniteAndInvalidFramesAreIgnored() {
        let frames = [
            AnthemAnalysisFrame(startTime: 0, duration: 1, energy: 0.5),
            AnthemAnalysisFrame(startTime: 1, duration: .nan, energy: 0.8)
        ]
        let result = AnthemEnergyTransitionAnalyser.analyse(frames: frames)
        XCTAssertEqual(result.count, 1)
    }

    func testUnsortedFramesAreHandledDeterministically() {
        let frames = [
            AnthemAnalysisFrame(startTime: 2, duration: 1, energy: 0.8),
            AnthemAnalysisFrame(startTime: 0, duration: 1, energy: 0.1),
            AnthemAnalysisFrame(startTime: 1, duration: 1, energy: 0.4)
        ]
        XCTAssertEqual(AnthemEnergyTransitionAnalyser.analyse(frames: frames), AnthemEnergyTransitionAnalyser.analyse(frames: frames.reversed()))
    }

    func testRepeatedAnalysisIsDeterministic() {
        let frames = AnthemAnalysisFoundation.frames(from: [0.1, 0.8, 0.9, 0.2], trackDuration: 4)
        XCTAssertEqual(AnthemEnergyTransitionAnalyser.analyse(frames: frames), AnthemEnergyTransitionAnalyser.analyse(frames: frames))
    }

    func testAllOutputsAreNormalised() {
        let result = evidence([0, 1, 0.2, 0.9, 0])
        XCTAssertTrue(result.allSatisfy {
            (0...1).contains($0.riseStrength) && (0...1).contains($0.fallStrength) && (0...1).contains($0.sustainStrength) && (0...1).contains($0.localPeakStrength) && (0...1).contains($0.plateauStrength)
        })
    }
}
