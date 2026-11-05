import XCTest
@testable import DJAnthemMapper

final class AnthemRegionOverlayGeometryTests: XCTestCase {
    func testBothMarkersVisible() {
        let r = AnthemRegionOverlayGeometry.layout(start: 10, end: 20, visibleStart: 0, visibleDuration: 40, width: 400)
        XCTAssertEqual(r.startX, 100); XCTAssertEqual(r.endX, 200); XCTAssertEqual(r.shadeX, 100); XCTAssertEqual(r.shadeWidth, 100)
    }

    func testOffscreenMarkersAreNotClamped() {
        let r = AnthemRegionOverlayGeometry.layout(start: 10, end: 20, visibleStart: 30, visibleDuration: 10, width: 500)
        XCTAssertNil(r.startX); XCTAssertNil(r.endX); XCTAssertNil(r.shadeX); XCTAssertNil(r.shadeWidth)
    }

    func testViewportEntirelyInsideRegion() {
        let r = AnthemRegionOverlayGeometry.layout(start: 10, end: 30, visibleStart: 15, visibleDuration: 10, width: 500)
        XCTAssertNil(r.startX); XCTAssertNil(r.endX); XCTAssertEqual(r.shadeX, 0); XCTAssertEqual(r.shadeWidth, 500)
    }

    func testStartVisibleEndOffscreen() {
        let r = AnthemRegionOverlayGeometry.layout(start: 12, end: 30, visibleStart: 10, visibleDuration: 10, width: 200)
        XCTAssertEqual(r.startX, 40); XCTAssertNil(r.endX); XCTAssertEqual(r.shadeX, 40); XCTAssertEqual(r.shadeWidth, 160)
    }

    func testEndVisibleStartOffscreen() {
        let r = AnthemRegionOverlayGeometry.layout(start: 0, end: 18, visibleStart: 10, visibleDuration: 10, width: 200)
        XCTAssertNil(r.startX); XCTAssertEqual(r.endX, 160); XCTAssertEqual(r.shadeX, 0); XCTAssertEqual(r.shadeWidth, 160)
    }

    func testInvalidRegionHasNoShading() {
        let r = AnthemRegionOverlayGeometry.layout(start: 20, end: 10, visibleStart: 0, visibleDuration: 30, width: 300)
        XCTAssertEqual(r.startX, 200); XCTAssertEqual(r.endX, 100); XCTAssertNil(r.shadeX); XCTAssertNil(r.shadeWidth)
    }

    func testInvalidViewportReturnsEmptyLayout() {
        XCTAssertEqual(AnthemRegionOverlayGeometry.layout(start: 1, end: 2, visibleStart: 0, visibleDuration: 0, width: 100), .init())
        XCTAssertEqual(AnthemRegionOverlayGeometry.layout(start: 1, end: 2, visibleStart: 0, visibleDuration: 1, width: 0), .init())
    }
}
