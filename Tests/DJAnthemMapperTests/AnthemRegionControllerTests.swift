import XCTest
@testable import DJAnthemMapper

@MainActor
final class AnthemRegionControllerTests: XCTestCase {
    private let duration = 180.0

    func testInitialState() {
        let c = AnthemRegionController()
        XCTAssertNil(c.start); XCTAssertNil(c.end); XCTAssertNil(c.duration)
        XCTAssertFalse(c.hasAnyMarker); XCTAssertFalse(c.canPlayRegion)
    }

    func testValidRegionAndDuration() throws {
        let c = AnthemRegionController()
        XCTAssertTrue(c.setStart(at: 43.719, trackDuration: duration))
        XCTAssertTrue(c.setEnd(at: 65.410, trackDuration: duration))
        XCTAssertEqual(try XCTUnwrap(c.duration), 21.691, accuracy: 0.000001)
        XCTAssertTrue(c.canPlayRegion)
    }

    func testStartOnlyAndEndOnlyAreAllowed() {
        let a = AnthemRegionController(); XCTAssertTrue(a.setStart(at: 10, trackDuration: duration)); XCTAssertNil(a.end)
        let b = AnthemRegionController(); XCTAssertTrue(b.setEnd(at: 20, trackDuration: duration)); XCTAssertNil(b.start)
    }

    func testInvalidStartIsNonDestructive() {
        let c = validController(); let old = c.region
        XCTAssertFalse(c.setStart(at: 70, trackDuration: duration))
        XCTAssertEqual(c.region, old); XCTAssertEqual(c.validationMessage, "START must be earlier than END.")
    }

    func testInvalidEndIsNonDestructive() {
        let c = validController(); let old = c.region
        XCTAssertFalse(c.setEnd(at: 30, trackDuration: duration))
        XCTAssertEqual(c.region, old); XCTAssertEqual(c.validationMessage, "END must be later than START.")
    }

    func testBoundsAndNonFiniteValues() {
        let c = AnthemRegionController()
        XCTAssertFalse(c.setStart(at: -0.001, trackDuration: duration))
        XCTAssertFalse(c.setEnd(at: duration + 0.001, trackDuration: duration))
        XCTAssertFalse(c.setStart(at: .nan, trackDuration: duration))
        XCTAssertFalse(c.setEnd(at: .infinity, trackDuration: duration))
    }

    func testBoundaryRules() {
        let c = AnthemRegionController()
        XCTAssertFalse(c.setStart(at: duration, trackDuration: duration))
        XCTAssertFalse(c.setEnd(at: 0, trackDuration: duration))
        XCTAssertTrue(c.setStart(at: 10, trackDuration: duration))
        XCTAssertTrue(c.setEnd(at: duration, trackDuration: duration))
    }

    func testMillisecondNormalisation() throws {
        let c = AnthemRegionController()
        XCTAssertTrue(c.setStart(at: 43.7194, trackDuration: duration))
        XCTAssertEqual(try XCTUnwrap(c.start), 43.719, accuracy: 0.000001)
        XCTAssertTrue(c.setStart(at: 43.7196, trackDuration: duration))
        XCTAssertEqual(try XCTUnwrap(c.start), 43.720, accuracy: 0.000001)
    }

    func testClearAndNewTrackReset() {
        let c = validController(); c.clear(); XCTAssertEqual(c.region, AnthemRegion())
        _ = c.setStart(at: 10, trackDuration: duration); c.resetForNewTrack(); XCTAssertEqual(c.region, AnthemRegion())
    }

    private func validController() -> AnthemRegionController {
        let c = AnthemRegionController(); XCTAssertTrue(c.setStart(at: 43.719, trackDuration: duration)); XCTAssertTrue(c.setEnd(at: 65.410, trackDuration: duration)); return c
    }
}
