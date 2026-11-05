import XCTest
@testable import DJAnthemMapper

final class AnthemAnalysisFoundationTests: XCTestCase {
    func testEmptyWaveformProducesNoFrames() {
        XCTAssertTrue(AnthemAnalysisFoundation.frames(from: [], trackDuration: 60).isEmpty)
    }

    func testFramesMapWaveformAcrossTrackDuration() {
        let frames = AnthemAnalysisFoundation.frames(from: [0.1, 0.5, 1.0, 0.2], trackDuration: 40)
        XCTAssertEqual(frames.count, 4)
        XCTAssertEqual(frames[0].startTime, 0, accuracy: 0.0001)
        XCTAssertEqual(frames[1].startTime, 10, accuracy: 0.0001)
        XCTAssertEqual(frames[0].duration, 10, accuracy: 0.0001)
        XCTAssertEqual(frames[2].energy, 1.0, accuracy: 0.0001)
    }

    func testEnergyIsClampedAndNonFiniteEnergyIsSafe() {
        let frames = AnthemAnalysisFoundation.frames(from: [-2, .nan], trackDuration: 2)
        XCTAssertEqual(frames[0].energy, 1.0, accuracy: 0.0001)
        XCTAssertEqual(frames[1].energy, 0.0, accuracy: 0.0001)
    }

    func testStrongestWindowFindsHighestMeanEnergy() {
        let frames = AnthemAnalysisFoundation.frames(from: [0.1, 0.2, 0.9, 1.0, 0.1], trackDuration: 50)
        let result = AnthemAnalysisFoundation.strongestWindow(in: frames, preferredDuration: 20)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.startTime ?? -1, 20, accuracy: 0.0001)
        XCTAssertEqual(result?.endTime ?? -1, 40, accuracy: 0.0001)
        XCTAssertEqual(result?.score ?? -1, 0.95, accuracy: 0.0001)
    }

    func testStrongestWindowRejectsInvalidDuration() {
        let frames = AnthemAnalysisFoundation.frames(from: [1], trackDuration: 1)
        XCTAssertNil(AnthemAnalysisFoundation.strongestWindow(in: frames, preferredDuration: 0))
    }
}
