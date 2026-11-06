import XCTest
@testable import DJAnthemMapper

final class AnthemVocalTransitionAnalyserTests: XCTestCase {
    private func frame(_ start: Double, energy: Float, activity: Float, duration: Double = 1) -> AnthemVocalAnalysisFrame {
        .init(startTime: start, duration: duration, energy: energy, activity: activity)
    }

    func testRisingVocalEnergyProducesRiseEvidence() {
        let result = AnthemVocalTransitionAnalyser.analyse(frames: [
            frame(0, energy: 0.1, activity: 0.5),
            frame(1, energy: 0.8, activity: 0.5)
        ])
        XCTAssertEqual(result[1].riseStrength, 0.7, accuracy: 0.000001)
        XCTAssertEqual(result[1].entryStrength, 0, accuracy: 0.000001)
    }

    func testFallingVocalEnergyProducesFallEvidence() {
        let result = AnthemVocalTransitionAnalyser.analyse(frames: [
            frame(0, energy: 0.9, activity: 0.5),
            frame(1, energy: 0.2, activity: 0.5)
        ])
        XCTAssertEqual(result[0].fallStrength, 0.7, accuracy: 0.000001)
    }

    func testIncreasingActivityProducesEntryEvidence() {
        let result = AnthemVocalTransitionAnalyser.analyse(frames: [
            frame(0, energy: 0.4, activity: 0.1),
            frame(1, energy: 0.4, activity: 0.9)
        ])
        XCTAssertEqual(result[1].entryStrength, 0.8, accuracy: 0.000001)
    }

    func testDecreasingActivityProducesExitEvidence() {
        let result = AnthemVocalTransitionAnalyser.analyse(frames: [
            frame(0, energy: 0.4, activity: 0.9),
            frame(1, energy: 0.4, activity: 0.1)
        ])
        XCTAssertEqual(result[0].exitStrength, 0.8, accuracy: 0.000001)
    }

    func testConstantVocalsProduceNoTransitionEvidence() {
        let result = AnthemVocalTransitionAnalyser.analyse(frames: [
            frame(0, energy: 0.6, activity: 0.7),
            frame(1, energy: 0.6, activity: 0.7),
            frame(2, energy: 0.6, activity: 0.7)
        ])
        XCTAssertTrue(result.allSatisfy { $0.riseStrength == 0 && $0.fallStrength == 0 && $0.entryStrength == 0 && $0.exitStrength == 0 })
    }

    func testSilenceIsFiniteAndNeutral() {
        let result = AnthemVocalTransitionAnalyser.analyse(frames: [frame(0, energy: 0, activity: 0), frame(1, energy: 0, activity: 0)])
        XCTAssertTrue(result.allSatisfy { $0.riseStrength == 0 && $0.fallStrength == 0 && $0.entryStrength == 0 && $0.exitStrength == 0 && $0.startTime.isFinite && $0.endTime.isFinite })
    }

    func testSingleFrameIsNeutralAndKeepsRange() {
        let result = AnthemVocalTransitionAnalyser.analyse(frames: [frame(2, energy: 0.8, activity: 0.9, duration: 0.5)])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].startTime, 2, accuracy: 0.000001)
        XCTAssertEqual(result[0].endTime, 2.5, accuracy: 0.000001)
        XCTAssertEqual(result[0].riseStrength, 0)
        XCTAssertEqual(result[0].fallStrength, 0)
        XCTAssertEqual(result[0].entryStrength, 0)
        XCTAssertEqual(result[0].exitStrength, 0)
    }

    func testEmptyInputReturnsEmptyOutput() {
        XCTAssertTrue(AnthemVocalTransitionAnalyser.analyse(frames: []).isEmpty)
    }

    func testZeroDurationFramesAreIgnored() {
        let result = AnthemVocalTransitionAnalyser.analyse(frames: [
            frame(0, energy: 0.2, activity: 0.2),
            frame(1, energy: 1, activity: 1, duration: 0)
        ])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].startTime, 0, accuracy: 0.000001)
    }

    func testUnsortedInputIsHandledDeterministically() {
        let frames = [
            frame(2, energy: 0.8, activity: 0.7),
            frame(0, energy: 0.1, activity: 0.1),
            frame(1, energy: 0.5, activity: 0.9)
        ]
        XCTAssertEqual(AnthemVocalTransitionAnalyser.analyse(frames: frames), AnthemVocalTransitionAnalyser.analyse(frames: frames.reversed()))
    }

    func testRepeatedAnalysisIsDeterministic() {
        let frames = [frame(0, energy: 0.1, activity: 0.2), frame(1, energy: 0.9, activity: 0.8), frame(2, energy: 0.3, activity: 0.1)]
        let first = AnthemVocalTransitionAnalyser.analyse(frames: frames)
        let second = AnthemVocalTransitionAnalyser.analyse(frames: frames)
        XCTAssertEqual(first, second)
    }

    func testAllStrengthsAreBounded() {
        let result = AnthemVocalTransitionAnalyser.analyse(frames: [
            frame(0, energy: -10, activity: -10),
            frame(1, energy: 10, activity: 10),
            frame(2, energy: 0, activity: 0)
        ])
        XCTAssertTrue(result.allSatisfy {
            (0...1).contains($0.riseStrength) &&
            (0...1).contains($0.fallStrength) &&
            (0...1).contains($0.entryStrength) &&
            (0...1).contains($0.exitStrength)
        })
    }

    func testEvidenceRangesMatchSourceFrames() {
        let frames = [frame(0.25, energy: 0.2, activity: 0.3, duration: 0.5), frame(0.75, energy: 0.8, activity: 0.9, duration: 0.25)]
        let result = AnthemVocalTransitionAnalyser.analyse(frames: frames)
        XCTAssertEqual(result[0].startTime, 0.25, accuracy: 0.000001)
        XCTAssertEqual(result[0].endTime, 0.75, accuracy: 0.000001)
        XCTAssertEqual(result[1].startTime, 0.75, accuracy: 0.000001)
        XCTAssertEqual(result[1].endTime, 1.0, accuracy: 0.000001)
    }

    func testTrackBoundariesDoNotInventEntryOrExit() {
        let result = AnthemVocalTransitionAnalyser.analyse(frames: [
            frame(0, energy: 0.8, activity: 0.9),
            frame(1, energy: 0.8, activity: 0.9)
        ])
        XCTAssertEqual(result.first?.entryStrength ?? -1, 0, accuracy: 0.000001)
        XCTAssertEqual(result.last?.exitStrength ?? -1, 0, accuracy: 0.000001)
    }
}
