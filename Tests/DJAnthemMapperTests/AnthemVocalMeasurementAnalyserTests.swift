import XCTest
@testable import DJAnthemMapper

final class AnthemVocalMeasurementAnalyserTests: XCTestCase {
    func testSilenceProducesZeroEnergyAndActivity() throws {
        let result = try XCTUnwrap(AnthemVocalMeasurementAnalyser.measure(left: [0,0,0][...], right: [0,0,0][...]))
        XCTAssertEqual(result.energy, 0)
        XCTAssertEqual(result.activity, 0)
    }

    func testConstantStereoSignalProducesExpectedEnergyAndFullActivity() throws {
        let result = try XCTUnwrap(AnthemVocalMeasurementAnalyser.measure(left: [0.5,0.5][...], right: [0.5,0.5][...]))
        XCTAssertEqual(result.energy, 0.5, accuracy: 0.000001)
        XCTAssertEqual(result.activity, 1)
    }

    func testSingleChannelSignalContributesSymmetrically() throws {
        let leftOnly = try XCTUnwrap(AnthemVocalMeasurementAnalyser.measure(left: [1,1][...], right: [0,0][...]))
        let rightOnly = try XCTUnwrap(AnthemVocalMeasurementAnalyser.measure(left: [0,0][...], right: [1,1][...]))
        XCTAssertEqual(leftOnly.energy, 0.5, accuracy: 0.000001)
        XCTAssertEqual(leftOnly.energy, rightOnly.energy)
        XCTAssertEqual(leftOnly.activity, rightOnly.activity)
    }

    func testActivityRepresentsFractionOfFramesAboveThreshold() throws {
        let result = try XCTUnwrap(AnthemVocalMeasurementAnalyser.measure(left: [0,0.04,0,0.08][...], right: [0,0.04,0,0.08][...]))
        XCTAssertEqual(result.activity, 0.5, accuracy: 0.000001)
    }

    func testMagnitudeAboveOneIsSafelyBounded() throws {
        let result = try XCTUnwrap(AnthemVocalMeasurementAnalyser.measure(left: [2,2][...], right: [2,2][...]))
        XCTAssertEqual(result.energy, 1)
        XCTAssertEqual(result.activity, 1)
    }

    func testInvalidStereoAndNonFiniteSamplesAreRejected() {
        XCTAssertNil(AnthemVocalMeasurementAnalyser.measure(left: [0][...], right: [][...]))
        XCTAssertNil(AnthemVocalMeasurementAnalyser.measure(left: [Float.nan][...], right: [0][...]))
        XCTAssertNil(AnthemVocalMeasurementAnalyser.measure(left: [0][...], right: [Float.infinity][...]))
    }

    func testInvalidActivityThresholdIsRejected() {
        XCTAssertNil(AnthemVocalMeasurementAnalyser.measure(left: [0][...], right: [0][...], activityThreshold: -1))
        XCTAssertNil(AnthemVocalMeasurementAnalyser.measure(left: [0][...], right: [0][...], activityThreshold: .nan))
    }

    func testRepeatedMeasurementIsDeterministic() throws {
        let left: [Float] = [0.1,0.2,0.3,0.4]
        let right: [Float] = [0.4,0.3,0.2,0.1]
        let first = try XCTUnwrap(AnthemVocalMeasurementAnalyser.measure(left: left[...], right: right[...]))
        let second = try XCTUnwrap(AnthemVocalMeasurementAnalyser.measure(left: left[...], right: right[...]))
        XCTAssertEqual(first.energy, second.energy)
        XCTAssertEqual(first.activity, second.activity)
    }
}
