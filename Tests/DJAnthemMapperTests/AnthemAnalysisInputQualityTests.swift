import XCTest
@testable import DJAnthemMapper

final class AnthemAnalysisInputQualityTests: XCTestCase {
    private func frames(_ values: [Float]) -> [AnthemAnalysisFrame] {
        AnthemAnalysisFoundation.frames(from: values, trackDuration: Double(max(1, values.count)))
    }

    func testSilenceHasNoMeaningfulSignal() {
        let result = AnthemAnalysisInputQualityAnalyser.analyse(frames: frames([0,0,0,0]))
        XCTAssertEqual(result?.peakEnergy ?? -1, 0, accuracy: 0.0001)
        XCTAssertFalse(result?.hasMeaningfulSignal ?? true)
    }

    func testNearSilenceBelowFloorHasNoMeaningfulSignal() {
        let result = AnthemAnalysisInputQualityAnalyser.analyse(frames: frames([0.0001,0.0002,0.0001]))
        XCTAssertFalse(result?.hasMeaningfulSignal ?? true)
    }

    func testAudibleFlatSignalRemainsMeaningful() {
        let result = AnthemAnalysisInputQualityAnalyser.analyse(frames: frames([0.8,0.8,0.8,0.8]))
        XCTAssertTrue(result?.hasMeaningfulSignal ?? false)
        XCTAssertEqual(result?.dynamicRange ?? -1, 0, accuracy: 0.0001)
    }

    func testDynamicSignalReportsRangeAndMean() {
        let result = AnthemAnalysisInputQualityAnalyser.analyse(frames: frames([0.1,0.5,0.9]))
        XCTAssertEqual(result?.dynamicRange ?? -1, 0.8, accuracy: 0.0001)
        XCTAssertTrue(result?.meanEnergy.isFinite ?? false)
        XCTAssertTrue(result?.hasMeaningfulSignal ?? false)
    }

    func testEmptyFramesReturnNil() {
        XCTAssertNil(AnthemAnalysisInputQualityAnalyser.analyse(frames: []))
    }
}
