import XCTest
@testable import DJAnthemMapper

final class AnthemSustainedVocalAnalyserTests: XCTestCase {
    private func frame(_ start: Double, energy: Float, activity: Float, duration: Double = 1) -> AnthemVocalAnalysisFrame {
        .init(startTime: start, duration: duration, energy: energy, activity: activity)
    }

    func testSilenceIsNeutral() {
        let r = AnthemSustainedVocalAnalyser.analyse(frames: [frame(0, energy: 0, activity: 0), frame(1, energy: 0, activity: 0)])
        XCTAssertTrue(r.allSatisfy { $0.energyStrength == 0 && $0.activityStrength == 0 && $0.sustainedStrength == 0 })
    }

    func testSustainedHighVocalsProduceStrongEvidence() {
        let r = AnthemSustainedVocalAnalyser.analyse(frames: [frame(0, energy: 0.9, activity: 0.9), frame(1, energy: 0.9, activity: 0.9), frame(2, energy: 0.9, activity: 0.9)])
        XCTAssertTrue(r.allSatisfy { $0.sustainedStrength > 0.89 })
    }

    func testLowActivityLimitsSustainedStrength() {
        let r = AnthemSustainedVocalAnalyser.analyse(frames: [frame(0, energy: 1, activity: 0.2), frame(1, energy: 1, activity: 0.2), frame(2, energy: 1, activity: 0.2)])
        XCTAssertEqual(r[1].sustainedStrength, 0.2, accuracy: 0.000001)
    }

    func testLowEnergyLimitsSustainedStrength() {
        let r = AnthemSustainedVocalAnalyser.analyse(frames: [frame(0, energy: 0.2, activity: 1), frame(1, energy: 0.2, activity: 1), frame(2, energy: 0.2, activity: 1)])
        XCTAssertEqual(r[1].sustainedStrength, 0.2, accuracy: 0.000001)
    }

    func testIsolatedSpikeIsWeakerThanSustainedRun() {
        let spike = AnthemSustainedVocalAnalyser.analyse(frames: [frame(0, energy: 0, activity: 0), frame(1, energy: 1, activity: 1), frame(2, energy: 0, activity: 0)])
        let run = AnthemSustainedVocalAnalyser.analyse(frames: [frame(0, energy: 1, activity: 1), frame(1, energy: 1, activity: 1), frame(2, energy: 1, activity: 1)])
        XCTAssertLessThan(spike[1].sustainedStrength, run[1].sustainedStrength)
    }

    func testConstantInputProducesStableEvidence() {
        let r = AnthemSustainedVocalAnalyser.analyse(frames: [frame(0, energy: 0.6, activity: 0.7), frame(1, energy: 0.6, activity: 0.7), frame(2, energy: 0.6, activity: 0.7)])
        XCTAssertTrue(r.allSatisfy { abs($0.energyStrength - 0.6) < 0.000001 && abs($0.activityStrength - 0.7) < 0.000001 && abs($0.sustainedStrength - 0.6) < 0.000001 })
    }

    func testEmptyInputReturnsEmpty() { XCTAssertTrue(AnthemSustainedVocalAnalyser.analyse(frames: []).isEmpty) }

    func testSingleFrameIsSafeAndKeepsRange() {
        let r = AnthemSustainedVocalAnalyser.analyse(frames: [frame(2, energy: 0.8, activity: 0.7, duration: 0.5)])
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r[0].startTime, 2, accuracy: 0.000001)
        XCTAssertEqual(r[0].endTime, 2.5, accuracy: 0.000001)
        XCTAssertEqual(r[0].sustainedStrength, 0.7, accuracy: 0.000001)
    }

    func testZeroDurationFrameIsIgnored() {
        let r = AnthemSustainedVocalAnalyser.analyse(frames: [frame(0, energy: 0.4, activity: 0.5), frame(1, energy: 1, activity: 1, duration: 0)])
        XCTAssertEqual(r.count, 1)
    }

    func testUnsortedInputIsDeterministic() {
        let f = [frame(2, energy: 0.8, activity: 0.7), frame(0, energy: 0.1, activity: 0.2), frame(1, energy: 0.5, activity: 0.9)]
        XCTAssertEqual(AnthemSustainedVocalAnalyser.analyse(frames: f), AnthemSustainedVocalAnalyser.analyse(frames: f.reversed()))
    }

    func testRepeatedAnalysisIsDeterministic() {
        let f = [frame(0, energy: 0.1, activity: 0.2), frame(1, energy: 0.9, activity: 0.8)]
        XCTAssertEqual(AnthemSustainedVocalAnalyser.analyse(frames: f), AnthemSustainedVocalAnalyser.analyse(frames: f))
    }

    func testAllStrengthsAreBounded() {
        let r = AnthemSustainedVocalAnalyser.analyse(frames: [frame(0, energy: -10, activity: 10), frame(1, energy: 10, activity: -10)])
        XCTAssertTrue(r.allSatisfy { (0...1).contains($0.energyStrength) && (0...1).contains($0.activityStrength) && (0...1).contains($0.sustainedStrength) })
    }

    func testEvidenceRangesMatchSourceFrames() {
        let r = AnthemSustainedVocalAnalyser.analyse(frames: [frame(0.25, energy: 0.2, activity: 0.3, duration: 0.5), frame(0.75, energy: 0.8, activity: 0.9, duration: 0.25)])
        XCTAssertEqual(r[0].startTime, 0.25, accuracy: 0.000001)
        XCTAssertEqual(r[0].endTime, 0.75, accuracy: 0.000001)
        XCTAssertEqual(r[1].startTime, 0.75, accuracy: 0.000001)
        XCTAssertEqual(r[1].endTime, 1.0, accuracy: 0.000001)
    }

    func testBoundariesDoNotCreateSyntheticRanges() {
        let r = AnthemSustainedVocalAnalyser.analyse(frames: [frame(3, energy: 0.8, activity: 0.9, duration: 0.5)])
        XCTAssertEqual(r.map(\.startTime), [3])
        XCTAssertEqual(r.map(\.endTime), [3.5])
    }
}
