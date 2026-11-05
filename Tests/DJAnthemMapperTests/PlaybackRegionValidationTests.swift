import XCTest
@testable import DJAnthemMapper

@MainActor
final class PlaybackRegionValidationTests: XCTestCase {
    func testValidRegion() {
        XCTAssertTrue(PlaybackController.validRegionBounds(start: 7.531, end: 125.756, duration: 288.640))
    }
    func testEqualAndReversedBoundariesRejected() {
        XCTAssertFalse(PlaybackController.validRegionBounds(start: 10, end: 10, duration: 100))
        XCTAssertFalse(PlaybackController.validRegionBounds(start: 20, end: 10, duration: 100))
    }
    func testOutOfBoundsRejected() {
        XCTAssertFalse(PlaybackController.validRegionBounds(start: -0.001, end: 10, duration: 100))
        XCTAssertFalse(PlaybackController.validRegionBounds(start: 5, end: 101, duration: 100))
    }
    func testNonFiniteRejected() {
        XCTAssertFalse(PlaybackController.validRegionBounds(start: .nan, end: 10, duration: 100))
        XCTAssertFalse(PlaybackController.validRegionBounds(start: 5, end: .infinity, duration: 100))
        XCTAssertFalse(PlaybackController.validRegionBounds(start: 5, end: 10, duration: .nan))
    }
    func testZeroDurationRejected() {
        XCTAssertFalse(PlaybackController.validRegionBounds(start: 0, end: 1, duration: 0))
    }
}
