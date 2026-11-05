import XCTest
@testable import DJAnthemMapper

// PHASE_4C1B_ACTIVE_REGION_BRIDGE_TESTS
@MainActor
final class AnthemRegionActiveBridgeTests: XCTestCase {
    private func assertEqual(_ actual: Double?, _ expected: Double, accuracy: Double = 0.000_001,
                             file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else {
            XCTFail("Expected numeric value, found nil", file: file, line: line)
            return
        }
        XCTAssertEqual(actual, expected, accuracy: accuracy, file: file, line: line)
    }

    func testExistingRegionMigratesToActiveRegionA() {
        let c = AnthemRegionController(region: AnthemRegion(start: 10, end: 20))
        XCTAssertEqual(c.regions.count, 1)
        XCTAssertEqual(c.activeRegionLabel, "A")
        XCTAssertEqual(c.region, AnthemRegion(start: 10, end: 20))
    }

    func testAddingAndSwitchingKeepsRegionsIndependent() {
        let c = AnthemRegionController()
        let a = c.activeRegionID
        XCTAssertTrue(c.setStart(at: 10, trackDuration: 100))
        XCTAssertTrue(c.setEnd(at: 20, trackDuration: 100))
        let b = c.addRegion()
        XCTAssertEqual(c.activeRegionID, b)
        XCTAssertTrue(c.setStart(at: 30, trackDuration: 100))
        XCTAssertTrue(c.setEnd(at: 40, trackDuration: 100))
        XCTAssertTrue(c.selectRegion(id: a))
        XCTAssertEqual(c.region, AnthemRegion(start: 10, end: 20))
        XCTAssertTrue(c.selectRegion(id: b))
        XCTAssertEqual(c.region, AnthemRegion(start: 30, end: 40))
    }

    func testNudgeChangesOnlyActiveRegion() {
        let c = AnthemRegionController(region: AnthemRegion(start: 10, end: 20))
        let a = c.activeRegionID
        let b = c.addRegion(region: AnthemRegion(start: 30, end: 40))
        XCTAssertTrue(c.nudge(.start, by: 0.1, trackDuration: 100))
        assertEqual(c.start, 30.1)
        XCTAssertTrue(c.selectRegion(id: a))
        assertEqual(c.start, 10)
        XCTAssertTrue(c.selectRegion(id: b))
        assertEqual(c.start, 30.1)
    }

    func testDeletingActiveSelectsValidNeighbour() {
        let c = AnthemRegionController()
        let a = c.activeRegionID
        let b = c.addRegion()
        let d = c.addRegion()
        XCTAssertTrue(c.selectRegion(id: b))
        XCTAssertTrue(c.deleteRegion(id: b))
        XCTAssertEqual(c.activeRegionID, d)
        XCTAssertEqual(c.regions.count, 2)
        XCTAssertNotNil(c.collection.region(id: a))
    }

    func testDeletingOnlyRegionClearsAndKeepsIdentity() {
        let c = AnthemRegionController(region: AnthemRegion(start: 10, end: 20))
        let id = c.activeRegionID
        XCTAssertTrue(c.deleteRegion(id: id))
        XCTAssertEqual(c.activeRegionID, id)
        XCTAssertEqual(c.regions.count, 1)
        XCTAssertTrue(c.region.isEmpty)
    }

    func testResetForNewTrackReturnsToFreshA() {
        let c = AnthemRegionController(region: AnthemRegion(start: 10, end: 20))
        _ = c.addRegion(region: AnthemRegion(start: 30, end: 40))
        c.resetForNewTrack()
        XCTAssertEqual(c.regions.count, 1)
        XCTAssertEqual(c.activeRegionLabel, "A")
        XCTAssertTrue(c.region.isEmpty)
    }

    func testUnknownRegionCannotBeSelectedOrDeleted() {
        let c = AnthemRegionController()
        let original = c.activeRegionID
        XCTAssertFalse(c.selectRegion(id: UUID()))
        XCTAssertFalse(c.deleteRegion(id: UUID()))
        XCTAssertEqual(c.activeRegionID, original)
    }
}
