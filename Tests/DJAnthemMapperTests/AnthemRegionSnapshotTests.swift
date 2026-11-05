import XCTest
@testable import DJAnthemMapper

@MainActor
final class AnthemRegionSnapshotTests: XCTestCase {
    func testIdenticalSnapshotsCompareEqual() throws {
        let regions = [item(start: 10, end: 20)]
        XCTAssertEqual(
            try AnthemRegionSnapshot(regions: regions, activeRegionID: regions[0].id),
            try AnthemRegionSnapshot(regions: regions, activeRegionID: regions[0].id)
        )
    }

    func testRegionOrderAffectsEquality() throws {
        let first = item(start: 10, end: 20)
        let second = item(start: 30, end: 40)
        XCTAssertNotEqual(
            try AnthemRegionSnapshot(regions: [first, second], activeRegionID: first.id),
            try AnthemRegionSnapshot(regions: [second, first], activeRegionID: first.id)
        )
    }

    func testStartChangesAffectEquality() throws {
        let id = UUID()
        XCTAssertNotEqual(
            try AnthemRegionSnapshot(regions: [item(id: id, start: 10, end: 20)], activeRegionID: id),
            try AnthemRegionSnapshot(regions: [item(id: id, start: 11, end: 20)], activeRegionID: id)
        )
    }

    func testEndChangesAffectEquality() throws {
        let id = UUID()
        XCTAssertNotEqual(
            try AnthemRegionSnapshot(regions: [item(id: id, start: 10, end: 20)], activeRegionID: id),
            try AnthemRegionSnapshot(regions: [item(id: id, start: 10, end: 21)], activeRegionID: id)
        )
    }

    func testUUIDChangesAffectEquality() throws {
        let first = item(start: 10, end: 20)
        let second = item(start: 10, end: 20)
        XCTAssertNotEqual(
            try AnthemRegionSnapshot(regions: [first], activeRegionID: first.id),
            try AnthemRegionSnapshot(regions: [second], activeRegionID: second.id)
        )
    }

    func testActiveRegionChangesAffectEquality() throws {
        let first = item(start: 10, end: 20)
        let second = item(start: 30, end: 40)
        XCTAssertNotEqual(
            try AnthemRegionSnapshot(regions: [first, second], activeRegionID: first.id),
            try AnthemRegionSnapshot(regions: [first, second], activeRegionID: second.id)
        )
    }

    func testIncompleteRegionsSurviveCaptureAndRestore() throws {
        let source = AnthemRegionController()
        let firstID = source.activeRegionID
        XCTAssertTrue(source.setStart(at: 10, trackDuration: 100))
        let secondID = source.addRegion()
        XCTAssertTrue(source.setEnd(at: 40, trackDuration: 100))
        XCTAssertTrue(source.selectRegion(id: firstID))

        let snapshot = try XCTUnwrap(source.captureSnapshot())
        let restored = AnthemRegionController(region: AnthemRegion(start: 50, end: 60))

        XCTAssertTrue(restored.restore(snapshot: snapshot))
        XCTAssertEqual(restored.regions.map(\.id), [firstID, secondID])
        XCTAssertEqual(restored.regions[0].start, 10)
        XCTAssertNil(restored.regions[0].end)
        XCTAssertNil(restored.regions[1].start)
        XCTAssertEqual(restored.regions[1].end, 40)
        XCTAssertEqual(restored.activeRegionID, firstID)
    }

    func testEmptySnapshotsAreRejected() {
        XCTAssertThrowsError(try AnthemRegionSnapshot(regions: [], activeRegionID: UUID())) {
            XCTAssertEqual($0 as? AnthemRegionSnapshot.ValidationError, .emptyRegions)
        }
    }

    func testDuplicateUUIDsAreRejected() {
        let id = UUID()
        XCTAssertThrowsError(try AnthemRegionSnapshot(
            regions: [item(id: id, start: 10, end: 20), item(id: id, start: 30, end: 40)],
            activeRegionID: id
        )) {
            XCTAssertEqual($0 as? AnthemRegionSnapshot.ValidationError, .duplicateRegionID(id))
        }
    }

    func testMissingActiveUUIDIsRejected() {
        XCTAssertThrowsError(try AnthemRegionSnapshot(
            regions: [item(start: 10, end: 20)],
            activeRegionID: UUID()
        )) {
            guard case .missingActiveRegionID = $0 as? AnthemRegionSnapshot.ValidationError else {
                return XCTFail("Expected missing active region validation error")
            }
        }
    }

    func testMoreThanEightRegionsAreRejected() {
        let regions = (0...8).map { _ in item() }
        XCTAssertThrowsError(try AnthemRegionSnapshot(regions: regions, activeRegionID: regions[0].id)) {
            XCTAssertEqual($0 as? AnthemRegionSnapshot.ValidationError, .tooManyRegions(9))
        }
    }

    func testFailedRestoreLeavesAllControllerStateUnchanged() throws {
        let controller = AnthemRegionController(region: AnthemRegion(start: 10, end: 20))
        XCTAssertFalse(controller.setStart(at: 30, trackDuration: 100))
        let collection = controller.collection
        let activeRegionID = controller.activeRegionID
        let validationMessage = controller.validationMessage
        let rejectedSnapshot = try? AnthemRegionSnapshot(regions: [], activeRegionID: UUID())

        XCTAssertFalse(controller.restore(snapshot: rejectedSnapshot))
        XCTAssertEqual(controller.collection, collection)
        XCTAssertEqual(controller.activeRegionID, activeRegionID)
        XCTAssertEqual(controller.validationMessage, validationMessage)
    }

    func testSuccessfulRoundTripPreservesAllEditorState() throws {
        let source = AnthemRegionController()
        let firstID = source.activeRegionID
        XCTAssertTrue(source.setStart(at: 10, trackDuration: 100))
        let secondID = source.addRegion()
        XCTAssertTrue(source.setEnd(at: 40, trackDuration: 100))
        let thirdID = source.addRegion(region: AnthemRegion(start: 60, end: 70))
        XCTAssertTrue(source.selectRegion(id: secondID))
        let snapshot = try XCTUnwrap(source.captureSnapshot())

        let restored = AnthemRegionController()
        XCTAssertTrue(restored.restore(snapshot: snapshot))

        XCTAssertEqual(restored.regions.map(\.id), [firstID, secondID, thirdID])
        XCTAssertEqual(restored.regions.map(\.start), [10, nil, 60])
        XCTAssertEqual(restored.regions.map(\.end), [nil, 40, 70])
        XCTAssertEqual(restored.activeRegionID, secondID)
    }

    func testCaptureDoesNotMutateController() throws {
        let controller = AnthemRegionController()
        let firstID = controller.activeRegionID
        XCTAssertTrue(controller.setStart(at: 10, trackDuration: 100))
        let secondID = controller.addRegion(region: AnthemRegion(start: 30, end: 40))
        XCTAssertTrue(controller.selectRegion(id: firstID))
        let before = controller.collection
        let activeRegionID = controller.activeRegionID

        _ = try XCTUnwrap(controller.captureSnapshot())

        XCTAssertEqual(controller.collection, before)
        XCTAssertEqual(controller.activeRegionID, activeRegionID)
        XCTAssertNotEqual(firstID, secondID)
    }

    func testRestoringValidSnapshotDoesNotAlterValidationMessage() throws {
        let source = AnthemRegionController(region: AnthemRegion(start: 10, end: 20))
        let snapshot = try XCTUnwrap(source.captureSnapshot())
        let restored = AnthemRegionController(region: AnthemRegion(start: 30, end: 40))
        XCTAssertFalse(restored.setStart(at: 50, trackDuration: 100))
        let validationMessage = try XCTUnwrap(restored.validationMessage)

        XCTAssertTrue(restored.restore(snapshot: snapshot))
        XCTAssertEqual(restored.validationMessage, validationMessage)
    }

    private func item(id: UUID = UUID(), start: TimeInterval? = nil, end: TimeInterval? = nil) -> AnthemRegionItem {
        AnthemRegionItem(id: id, region: AnthemRegion(start: start, end: end))
    }
}
