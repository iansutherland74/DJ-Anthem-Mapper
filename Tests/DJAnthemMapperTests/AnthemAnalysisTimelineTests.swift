import XCTest
@testable import DJAnthemMapper

final class AnthemAnalysisTimelineTests: XCTestCase {
    func testRangeDurationAndValidation() {
        XCTAssertEqual(AnthemAnalysisTimeRange(startTime: 2, endTime: 6).duration, 4, accuracy: 0.0001)
        XCTAssertTrue(AnthemAnalysisTimeRange(startTime: 0, endTime: 1).isValid)
        XCTAssertFalse(AnthemAnalysisTimeRange(startTime: -1, endTime: 1).isValid)
        XCTAssertFalse(AnthemAnalysisTimeRange(startTime: 1, endTime: 1).isValid)
        XCTAssertFalse(AnthemAnalysisTimeRange(startTime: 0, endTime: .nan).isValid)
    }

    func testHalfOpenBoundaryDoesNotIncludeTouchingFrame() {
        let frames = [AnthemAnalysisFrame(startTime: 0, duration: 1, energy: 0.2), AnthemAnalysisFrame(startTime: 1, duration: 1, energy: 0.8)]
        let selected = AnthemAnalysisTimeline.frames(overlapping: .init(startTime: 0, endTime: 1), in: frames)
        XCTAssertEqual(selected.count, 1)
        XCTAssertEqual(selected[0].startTime, 0, accuracy: 0.0001)
    }

    func testFramesAreOrderedDeterministically() {
        let frames = [AnthemAnalysisFrame(startTime: 2, duration: 1, energy: 0.2), AnthemAnalysisFrame(startTime: 0, duration: 1, energy: 0.1), AnthemAnalysisFrame(startTime: 1, duration: 1, energy: 0.3)]
        XCTAssertEqual(AnthemAnalysisTimeline.validOrderedFrames(frames).map(\.startTime), [0,1,2])
    }

    func testGapsAreNotInvented() {
        let frames = [AnthemAnalysisFrame(startTime: 0, duration: 1, energy: 0.2), AnthemAnalysisFrame(startTime: 3, duration: 1, energy: 0.8)]
        XCTAssertEqual(AnthemAnalysisTimeline.frames(overlapping: .init(startTime: 1, endTime: 3), in: frames).count, 0)
    }

    func testComparisonWindowDurationIsTimeBasedAcrossResolutions() {
        let coarse = AnthemAnalysisFoundation.frames(from: [0.1,0.4,0.9,0.5,0.1,0.4,0.9,0.5], trackDuration: 8)
        let fine = AnthemAnalysisFoundation.frames(from: [0.1,0.1,0.4,0.4,0.9,0.9,0.5,0.5,0.1,0.1,0.4,0.4,0.9,0.9,0.5,0.5], trackDuration: 8)
        var config = AnthemRepetitionConfiguration()
        config.comparisonWindowDuration = 4
        let coarseResult = AnthemRepetitionAnalyser.analyse(frames: coarse, configuration: config)
        let fineResult = AnthemRepetitionAnalyser.analyse(frames: fine, configuration: config)
        XCTAssertEqual(coarseResult.first?.sourceEndTime ?? -1, 4, accuracy: 0.0001)
        XCTAssertEqual(fineResult.first?.sourceEndTime ?? -1, 4, accuracy: 0.0001)
    }

    func testTrackEndWindowReportsActualClippedRange() {
        let frames = AnthemAnalysisFoundation.frames(from: [0.1,0.5,0.9], trackDuration: 3)
        var config = AnthemRepetitionConfiguration()
        config.comparisonWindowDuration = 4
        let result = AnthemRepetitionAnalyser.analyse(frames: frames, configuration: config)
        XCTAssertEqual(result.last?.sourceEndTime ?? -1, 3, accuracy: 0.0001)
    }
}
