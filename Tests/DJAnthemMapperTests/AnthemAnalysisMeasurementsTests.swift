import XCTest
@testable import DJAnthemMapper

final class AnthemAnalysisMeasurementsTests: XCTestCase {
    func testUnequalDurationsAreWeightedByTime() {
        let frames = [AnthemAnalysisFrame(startTime: 0, duration: 1, energy: 1), AnthemAnalysisFrame(startTime: 1, duration: 3, energy: 0)]
        let result = AnthemAnalysisMeasurements.weightedEnergy(in: .init(startTime: 0, endTime: 4), frames: frames)
        XCTAssertEqual(result?.weightedMean ?? -1, 0.25, accuracy: 0.0001)
        XCTAssertEqual(result?.coveredDuration ?? -1, 4, accuracy: 0.0001)
    }

    func testPartialFramesUseOnlyOverlapDuration() {
        let frames = [AnthemAnalysisFrame(startTime: 0, duration: 1, energy: 0), AnthemAnalysisFrame(startTime: 1, duration: 1, energy: 1)]
        let result = AnthemAnalysisMeasurements.weightedEnergy(in: .init(startTime: 0.5, endTime: 1.5), frames: frames)
        XCTAssertEqual(result?.weightedMean ?? -1, 0.5, accuracy: 0.0001)
        XCTAssertEqual(result?.coveredDuration ?? -1, 1, accuracy: 0.0001)
    }

    func testTouchingBoundaryHasZeroOverlap() {
        let frame = AnthemAnalysisFrame(startTime: 0, duration: 1, energy: 1)
        XCTAssertEqual(AnthemAnalysisTimeline.overlapDuration(of: frame, with: .init(startTime: 1, endTime: 2)), 0, accuracy: 0.0001)
    }

    func testOverlappingFramesDoNotDoubleCountTime() {
        let frames = [AnthemAnalysisFrame(startTime: 0, duration: 2, energy: 1), AnthemAnalysisFrame(startTime: 1, duration: 2, energy: 0)]
        let result = AnthemAnalysisMeasurements.weightedEnergy(in: .init(startTime: 0, endTime: 3), frames: frames)
        XCTAssertEqual(result?.coveredDuration ?? -1, 3, accuracy: 0.0001)
        XCTAssertEqual(result?.weightedMean ?? -1, 1.0 / 3.0, accuracy: 0.0001)
    }

    func testEquivalentCoarseAndFineRepresentationsAgree() {
        let coarse = [AnthemAnalysisFrame(startTime: 0, duration: 2, energy: 0.25), AnthemAnalysisFrame(startTime: 2, duration: 2, energy: 0.75)]
        let fine = [AnthemAnalysisFrame(startTime: 0, duration: 1, energy: 0.25), AnthemAnalysisFrame(startTime: 1, duration: 1, energy: 0.25), AnthemAnalysisFrame(startTime: 2, duration: 1, energy: 0.75), AnthemAnalysisFrame(startTime: 3, duration: 1, energy: 0.75)]
        let range = AnthemAnalysisTimeRange(startTime: 0, endTime: 4)
        XCTAssertEqual(AnthemAnalysisMeasurements.weightedEnergy(in: range, frames: coarse)?.weightedMean ?? -1, AnthemAnalysisMeasurements.weightedEnergy(in: range, frames: fine)?.weightedMean ?? -2, accuracy: 0.0001)
    }
}
