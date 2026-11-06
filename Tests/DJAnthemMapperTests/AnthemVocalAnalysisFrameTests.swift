import XCTest
@testable import DJAnthemMapper

final class AnthemVocalAnalysisFrameTests: XCTestCase {
    func testValidValuesArePreservedExactly() {
        let frame = AnthemVocalAnalysisFrame(startTime: 12.5, duration: 2.25, energy: 0.4, activity: 0.7)
        XCTAssertEqual(frame.startTime, 12.5)
        XCTAssertEqual(frame.duration, 2.25)
        XCTAssertEqual(frame.energy, 0.4)
        XCTAssertEqual(frame.activity, 0.7)
        XCTAssertEqual(frame.endTime, 14.75)
    }

    func testNegativeTimeValuesClampToZero() {
        let frame = AnthemVocalAnalysisFrame(startTime: -2, duration: -3, energy: 0.5, activity: 0.5)
        XCTAssertEqual(frame.startTime, 0)
        XCTAssertEqual(frame.duration, 0)
        XCTAssertEqual(frame.endTime, 0)
    }

    func testEnergyAndActivityClampToUnitRange() {
        let low = AnthemVocalAnalysisFrame(startTime: 0, duration: 1, energy: -2, activity: -3)
        let high = AnthemVocalAnalysisFrame(startTime: 0, duration: 1, energy: 2, activity: 3)
        XCTAssertEqual(low.energy, 0)
        XCTAssertEqual(low.activity, 0)
        XCTAssertEqual(high.energy, 1)
        XCTAssertEqual(high.activity, 1)
    }

    func testNonFiniteTimeValuesBecomeZero() {
        for value in [Double.nan, Double.infinity, -Double.infinity] {
            let start = AnthemVocalAnalysisFrame(startTime: value, duration: 1, energy: 0, activity: 0)
            let duration = AnthemVocalAnalysisFrame(startTime: 0, duration: value, energy: 0, activity: 0)
            XCTAssertEqual(start.startTime, 0)
            XCTAssertEqual(duration.duration, 0)
            XCTAssertTrue(start.endTime.isFinite)
            XCTAssertTrue(duration.endTime.isFinite)
        }
    }

    func testNonFiniteMeasurementsBecomeZero() {
        for value in [Float.nan, Float.infinity, -Float.infinity] {
            let energy = AnthemVocalAnalysisFrame(startTime: 0, duration: 1, energy: value, activity: 0.5)
            let activity = AnthemVocalAnalysisFrame(startTime: 0, duration: 1, energy: 0.5, activity: value)
            XCTAssertEqual(energy.energy, 0)
            XCTAssertEqual(activity.activity, 0)
        }
    }

    func testRepeatedConstructionIsDeterministicAndEquatable() {
        let first = AnthemVocalAnalysisFrame(startTime: 4, duration: 2, energy: 0.25, activity: 0.75)
        let second = AnthemVocalAnalysisFrame(startTime: 4, duration: 2, energy: 0.25, activity: 0.75)
        XCTAssertEqual(first, second)
    }

    func testEndTimeUsesSanitisedValues() {
        let frame = AnthemVocalAnalysisFrame(startTime: -10, duration: 3.5, energy: 0, activity: 0)
        XCTAssertEqual(frame.endTime, 3.5)
        XCTAssertTrue(frame.endTime.isFinite)
    }
}
