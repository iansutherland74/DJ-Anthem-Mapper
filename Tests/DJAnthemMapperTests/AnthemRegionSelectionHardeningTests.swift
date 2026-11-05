import XCTest
@testable import DJAnthemMapper

// PHASE_4C1D_MULTI_REGION_HARDENING_TESTS
@MainActor
final class AnthemRegionSelectionHardeningTests: XCTestCase {
    func testAddWithoutActivationPreservesActiveRegion() {
        let c = AnthemRegionController(region: AnthemRegion(start: 10, end: 20))
        let a = c.activeRegionID
        let b = c.addRegion(region: AnthemRegion(start: 30, end: 40), makeActive: false)
        XCTAssertEqual(c.activeRegionID, a)
        XCTAssertEqual(c.region, AnthemRegion(start: 10, end: 20))
        XCTAssertEqual(c.collection.region(id: b)?.region, AnthemRegion(start: 30, end: 40))
    }

    func testDeletingNonActiveRegionDoesNotChangeActiveRegion() {
        let c = AnthemRegionController(region: AnthemRegion(start: 10, end: 20))
        let a = c.activeRegionID
        let b = c.addRegion(region: AnthemRegion(start: 30, end: 40), makeActive: false)
        XCTAssertTrue(c.deleteRegion(id: b))
        XCTAssertEqual(c.activeRegionID, a)
        XCTAssertEqual(c.region, AnthemRegion(start: 10, end: 20))
    }

    func testClearAffectsOnlyActiveRegion() {
        let c = AnthemRegionController(region: AnthemRegion(start: 10, end: 20))
        let a = c.activeRegionID
        let b = c.addRegion(region: AnthemRegion(start: 30, end: 40))
        c.clear()
        XCTAssertTrue(c.region.isEmpty)
        XCTAssertTrue(c.selectRegion(id: a))
        XCTAssertEqual(c.region, AnthemRegion(start: 10, end: 20))
        XCTAssertTrue(c.selectRegion(id: b))
        XCTAssertTrue(c.region.isEmpty)
    }

    func testRepeatedSwitchingDoesNotMutateEitherRegion() {
        let c = AnthemRegionController(region: AnthemRegion(start: 10, end: 20))
        let a = c.activeRegionID
        let b = c.addRegion(region: AnthemRegion(start: 30, end: 40))
        for _ in 0..<20 {
            XCTAssertTrue(c.selectRegion(id: a))
            XCTAssertEqual(c.region, AnthemRegion(start: 10, end: 20))
            XCTAssertTrue(c.selectRegion(id: b))
            XCTAssertEqual(c.region, AnthemRegion(start: 30, end: 40))
        }
    }

    func testDeletingFirstActiveChoosesFollowingRegionWithoutMutation() {
        let c = AnthemRegionController(region: AnthemRegion(start: 10, end: 20))
        let a = c.activeRegionID
        let b = c.addRegion(region: AnthemRegion(start: 30, end: 40))
        _ = c.addRegion(region: AnthemRegion(start: 50, end: 60))
        XCTAssertTrue(c.selectRegion(id: a))
        XCTAssertTrue(c.deleteRegion(id: a))
        XCTAssertEqual(c.activeRegionID, b)
        XCTAssertEqual(c.region, AnthemRegion(start: 30, end: 40))
    }

    func testDeletingLastActiveChoosesPreviousRemainingRegion() {
        let c = AnthemRegionController(region: AnthemRegion(start: 10, end: 20))
        let a = c.activeRegionID
        let b = c.addRegion(region: AnthemRegion(start: 30, end: 40))
        XCTAssertEqual(c.activeRegionID, b)
        XCTAssertTrue(c.deleteRegion(id: b))
        XCTAssertEqual(c.activeRegionID, a)
        XCTAssertEqual(c.region, AnthemRegion(start: 10, end: 20))
    }

    func testInvalidSelectionIsNonDestructive() {
        let c = AnthemRegionController(region: AnthemRegion(start: 10, end: 20))
        let active = c.activeRegionID
        XCTAssertFalse(c.selectRegion(id: UUID()))
        XCTAssertEqual(c.activeRegionID, active)
        XCTAssertEqual(c.region, AnthemRegion(start: 10, end: 20))
    }
}
