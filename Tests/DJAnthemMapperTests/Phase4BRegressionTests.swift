import XCTest
@testable import DJAnthemMapper

// PHASE_4BH3_AUTOMATED_4B_REGRESSION_TESTS
final class Phase4BRegressionTests: XCTestCase {
    private func assertEqual(_ actual: Double?, _ expected: Double, accuracy: Double = 0.000_001,
                             file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else {
            XCTFail("Expected numeric value, found nil", file: file, line: line)
            return
        }
        XCTAssertEqual(actual, expected, accuracy: accuracy, file: file, line: line)
    }

    func testAnthemRegionValidityAndDuration() {
        XCTAssertFalse(AnthemRegion().isValid)
        XCTAssertFalse(AnthemRegion(start: 10, end: 10).isValid)
        XCTAssertFalse(AnthemRegion(start: 11, end: 10).isValid)
        let region = AnthemRegion(start: 10, end: 12.5)
        XCTAssertTrue(region.isValid)
        assertEqual(region.duration, 2.5)
    }

    @MainActor
    func testControllerNormalisesMillisecondsAndRejectsInvalidOrder() {
        let c = AnthemRegionController()
        XCTAssertTrue(c.setStart(at: 10.1236, trackDuration: 100))
        assertEqual(c.start, 10.124)
        XCTAssertTrue(c.setEnd(at: 20.9876, trackDuration: 100))
        assertEqual(c.end, 20.988)
        XCTAssertFalse(c.setStart(at: 21, trackDuration: 100))
        assertEqual(c.start, 10.124)
        XCTAssertFalse(c.setEnd(at: 10, trackDuration: 100))
        assertEqual(c.end, 20.988)
    }

    @MainActor
    func testControllerNudgesBothMarkers() {
        let c = AnthemRegionController()
        XCTAssertTrue(c.setStart(at: 10, trackDuration: 100))
        XCTAssertTrue(c.setEnd(at: 20, trackDuration: 100))
        XCTAssertTrue(c.nudge(.start, by: 0.01, trackDuration: 100))
        assertEqual(c.start, 10.01)
        XCTAssertTrue(c.nudge(.end, by: -0.1, trackDuration: 100))
        assertEqual(c.end, 19.9)
    }

    @MainActor
    func testRegionBoundsValidation() {
        XCTAssertTrue(PlaybackController.validRegionBounds(start: 1, end: 2, duration: 10))
        XCTAssertFalse(PlaybackController.validRegionBounds(start: 2, end: 2, duration: 10))
        XCTAssertFalse(PlaybackController.validRegionBounds(start: 3, end: 2, duration: 10))
        XCTAssertFalse(PlaybackController.validRegionBounds(start: -1, end: 2, duration: 10))
        XCTAssertFalse(PlaybackController.validRegionBounds(start: 1, end: 11, duration: 10))
    }

    @MainActor
    func testExplicitBoundedPlaybackModesExist() {
        let modes: [PlaybackController.BoundedPlaybackMode] = [
            .region, .loop, .startAudition, .endAudition, .preRoll, .postRoll
        ]
        XCTAssertEqual(Set(modes.map(String.init(describing:))).count, 6)
    }

    func testViewportHalfSecondPrecisionAndClamping() {
        let v = WaveformViewport(start: 10, duration: 0.5, width: 1000)
        XCTAssertEqual(v.time(forX: 0), 10, accuracy: 0.000_001)
        XCTAssertEqual(v.time(forX: 500), 10.25, accuracy: 0.000_001)
        XCTAssertEqual(v.time(forX: 1000), 10.5, accuracy: 0.000_001)
        XCTAssertEqual(v.time(forX: -100), 10, accuracy: 0.000_001)
        XCTAssertEqual(v.time(forX: 1500), 10.5, accuracy: 0.000_001)
        XCTAssertEqual(v.x(forTime: 10.25), 500, accuracy: 0.000_001)
    }

    func testViewportRoundTripAcrossZoomDurations() {
        for visibleDuration in [0.5, 1.0, 5.0, 30.0, 180.0] {
            let v = WaveformViewport(start: 20, duration: visibleDuration, width: 900)
            for x in stride(from: 0.0, through: 900.0, by: 90.0) {
                XCTAssertEqual(v.x(forTime: v.time(forX: x)), x, accuracy: 0.000_001)
            }
        }
    }

    func testOverlayGeometryUsesViewportCoordinates() {
        let v = WaveformViewport(start: 10, duration: 10, width: 1000)
        let layout = AnthemRegionOverlayGeometry.layout(start: 12, end: 18, viewport: v)
        assertEqual(layout.startX, 200)
        assertEqual(layout.endX, 800)
        assertEqual(layout.shadeX, 200)
        assertEqual(layout.shadeWidth, 600)
    }

    func testOverlayClipsRegionToVisibleWindow() {
        let v = WaveformViewport(start: 10, duration: 10, width: 1000)
        let layout = AnthemRegionOverlayGeometry.layout(start: 5, end: 15, viewport: v)
        XCTAssertNil(layout.startX)
        assertEqual(layout.endX, 500)
        assertEqual(layout.shadeX, 0)
        assertEqual(layout.shadeWidth, 500)
    }
}
