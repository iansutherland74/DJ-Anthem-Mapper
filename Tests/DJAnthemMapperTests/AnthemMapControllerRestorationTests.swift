import Foundation
import XCTest
@testable import DJAnthemMapper

final class AnthemMapControllerRestorationTests: XCTestCase {
    private func makeTrack() -> AnthemMapDocument.TrackIdentity {
        AnthemMapDocument.TrackIdentity(
            fileName: "x.mp3",
            fileSize: nil,
            durationMilliseconds: Int64(100_000)
        )
    }

    private func makeItem(
        start: TimeInterval,
        end: TimeInterval,
        id: UUID = UUID()
    ) -> AnthemRegionItem {
        AnthemRegionItem(
            id: id,
            region: AnthemRegion(start: start, end: end)
        )
    }

    private func makeRestoration(
        regions: [AnthemRegionItem]
    ) -> AnthemMapRestoration {
        AnthemMapRestoration(
            track: makeTrack(),
            regions: regions
        )
    }

    @MainActor
    func testRestorationReplacesExistingRegions() {
        let controller = AnthemRegionController(
            region: AnthemRegion(start: 1, end: 2)
        )
        let regionA = makeItem(start: 10, end: 20)
        let regionB = makeItem(start: 30, end: 40)
        let restoration = makeRestoration(regions: [regionA, regionB])

        XCTAssertTrue(controller.restore(restoration))
        XCTAssertEqual(controller.regions, [regionA, regionB])
    }

    @MainActor
    func testFirstRestoredRegionBecomesActive() {
        let controller = AnthemRegionController()
        let regionA = makeItem(start: 10, end: 20)
        let regionB = makeItem(start: 30, end: 40)
        let restoration = makeRestoration(regions: [regionA, regionB])

        XCTAssertTrue(controller.restore(restoration))
        XCTAssertEqual(controller.activeRegionID, regionA.id)
    }

    @MainActor
    func testStableUUIDsArePreserved() {
        let controller = AnthemRegionController()
        let expectedID = UUID()
        let region = makeItem(start: 10, end: 20, id: expectedID)
        let restoration = makeRestoration(regions: [region])

        XCTAssertTrue(controller.restore(restoration))
        XCTAssertEqual(controller.regions.first?.id, expectedID)
    }

    @MainActor
    func testTimingsArePreserved() {
        let controller = AnthemRegionController()
        let region = makeItem(start: 12.345, end: 67.890)
        let restoration = makeRestoration(regions: [region])

        XCTAssertTrue(controller.restore(restoration))
        XCTAssertEqual(controller.start, 12.345)
        XCTAssertEqual(controller.end, 67.890)
    }

    @MainActor
    func testEightRegionsRestore() {
        let controller = AnthemRegionController()
        var regions: [AnthemRegionItem] = []

        for index in 0..<8 {
            let start = TimeInterval(index * 10 + 1)
            let end = TimeInterval(index * 10 + 2)
            regions.append(makeItem(start: start, end: end))
        }

        let restoration = makeRestoration(regions: regions)

        XCTAssertTrue(controller.restore(restoration))
        XCTAssertEqual(controller.regions.count, 8)
        XCTAssertEqual(controller.regions, regions)
    }

    @MainActor
    func testEmptyRestorationIsRejectedWithoutMutation() {
        let controller = AnthemRegionController(
            region: AnthemRegion(start: 1, end: 2)
        )
        let regionsBefore = controller.regions
        let activeIDBefore = controller.activeRegionID
        let restoration = makeRestoration(regions: [])

        XCTAssertFalse(controller.restore(restoration))
        XCTAssertEqual(controller.regions, regionsBefore)
        XCTAssertEqual(controller.activeRegionID, activeIDBefore)
    }

    @MainActor
    func testInvalidLiveRegionIsRejectedWithoutMutation() {
        let controller = AnthemRegionController(
            region: AnthemRegion(start: 1, end: 2)
        )
        let regionsBefore = controller.regions
        let activeIDBefore = controller.activeRegionID
        let invalidRegion = makeItem(start: 20, end: 10)
        let restoration = makeRestoration(regions: [invalidRegion])

        XCTAssertFalse(controller.restore(restoration))
        XCTAssertEqual(controller.regions, regionsBefore)
        XCTAssertEqual(controller.activeRegionID, activeIDBefore)
    }

    @MainActor
    func testDuplicateUUIDsAreRejectedWithoutMutation() {
        let controller = AnthemRegionController(
            region: AnthemRegion(start: 1, end: 2)
        )
        let regionsBefore = controller.regions
        let activeIDBefore = controller.activeRegionID
        let duplicateID = UUID()
        let regionA = makeItem(start: 10, end: 20, id: duplicateID)
        let regionB = makeItem(start: 30, end: 40, id: duplicateID)
        let restoration = makeRestoration(regions: [regionA, regionB])

        XCTAssertFalse(controller.restore(restoration))
        XCTAssertEqual(controller.regions, regionsBefore)
        XCTAssertEqual(controller.activeRegionID, activeIDBefore)
    }

    @MainActor
    func testSuccessfulRestoreClearsValidationMessage() {
        let controller = AnthemRegionController()

        XCTAssertFalse(controller.setStart(at: -1, trackDuration: 100))
        XCTAssertNotNil(controller.validationMessage)

        let region = makeItem(start: 10, end: 20)
        let restoration = makeRestoration(regions: [region])

        XCTAssertTrue(controller.restore(restoration))
        XCTAssertNil(controller.validationMessage)
    }
}
