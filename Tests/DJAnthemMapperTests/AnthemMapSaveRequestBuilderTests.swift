import XCTest
@testable import DJAnthemMapper

final class AnthemMapSaveRequestBuilderTests: XCTestCase {
    private let builder = AnthemMapSaveRequestBuilder()
    private let saveEngine = AnthemMapSaveEngine()

    private let trackIdentity = AnthemMapDocument.TrackIdentity(
        fileName: "track.mp3",
        fileSize: 4_096,
        durationMilliseconds: 300_000
    )

    @MainActor
    func testOneValidRegionProducesSaveRequest() throws {
        let item = makeValidItem(start: 10, end: 20)
        let request = try builder.makeRequest(trackIdentity: trackIdentity, regions: [item])
        XCTAssertEqual(request.track, trackIdentity)
        XCTAssertEqual(request.regions, [item])
    }

    @MainActor
    func testTrackIdentityIsPreservedExactly() throws {
        let identity = AnthemMapDocument.TrackIdentity(
            fileName: "performance.mkv",
            fileSize: 9_876,
            durationMilliseconds: 456_789
        )
        let item = makeValidItem(start: 1.234, end: 5.678)
        let request = try builder.makeRequest(trackIdentity: identity, regions: [item])
        XCTAssertEqual(request.track, identity)
    }

    @MainActor
    func testStableRegionUUIDIsPreserved() throws {
        let id = UUID()
        let item = makeValidItem(id: id, start: 10, end: 20)
        let request = try builder.makeRequest(trackIdentity: trackIdentity, regions: [item])
        XCTAssertEqual(request.regions[0].id, id)
    }

    @MainActor
    func testMultipleRegionOrderingIsPreserved() throws {
        let firstID = UUID()
        let secondID = UUID()
        let thirdID = UUID()
        let regions = [
            makeValidItem(id: firstID, start: 10, end: 20),
            makeValidItem(id: secondID, start: 30, end: 40),
            makeValidItem(id: thirdID, start: 50, end: 60)
        ]
        let request = try builder.makeRequest(trackIdentity: trackIdentity, regions: regions)
        XCTAssertEqual(request.regions.map(\.id), [firstID, secondID, thirdID])
    }

    @MainActor
    func testEmptyFinalRegionIsPreservedInRequest() throws {
        let valid = makeValidItem(start: 10, end: 20)
        let empty = AnthemRegionItem()
        let request = try builder.makeRequest(trackIdentity: trackIdentity, regions: [valid, empty])
        XCTAssertEqual(request.regions.count, 2)
        XCTAssertEqual(request.regions[0], valid)
        XCTAssertTrue(request.regions[1].isEmpty)
    }

    @MainActor
    func testStartOnlyFinalRegionIsPreservedInRequest() throws {
        let valid = makeValidItem(start: 10, end: 20)
        let partial = makeStartOnlyItem(start: 30)
        let request = try builder.makeRequest(trackIdentity: trackIdentity, regions: [valid, partial])
        XCTAssertEqual(request.regions.count, 2)
        XCTAssertTrue(request.regions[1].hasStart)
        XCTAssertFalse(request.regions[1].hasEnd)
        XCTAssertFalse(request.regions[1].isComplete)
    }

    @MainActor
    func testEndOnlyFinalRegionIsPreservedInRequest() throws {
        let valid = makeValidItem(start: 10, end: 20)
        let partial = makeEndOnlyItem(end: 40)
        let request = try builder.makeRequest(trackIdentity: trackIdentity, regions: [valid, partial])
        XCTAssertEqual(request.regions.count, 2)
        XCTAssertFalse(request.regions[1].hasStart)
        XCTAssertTrue(request.regions[1].hasEnd)
        XCTAssertFalse(request.regions[1].isComplete)
    }

    @MainActor
    func testEmptyRegionArrayIsRejected() {
        XCTAssertThrowsError(try builder.makeRequest(trackIdentity: trackIdentity, regions: [])) { error in
            XCTAssertEqual(error as? AnthemMapSaveRequestBuilderError, .noRegions)
        }
    }

    @MainActor
    func testOnlyEmptyRegionIsRejected() {
        XCTAssertThrowsError(try builder.makeRequest(trackIdentity: trackIdentity, regions: [AnthemRegionItem()])) { error in
            XCTAssertEqual(error as? AnthemMapSaveRequestBuilderError, .noCompleteValidRegion)
        }
    }

    @MainActor
    func testOnlyStartOnlyRegionIsRejected() {
        let partial = makeStartOnlyItem(start: 10)
        XCTAssertThrowsError(try builder.makeRequest(trackIdentity: trackIdentity, regions: [partial])) { error in
            XCTAssertEqual(error as? AnthemMapSaveRequestBuilderError, .noCompleteValidRegion)
        }
    }

    @MainActor
    func testOnlyEndOnlyRegionIsRejected() {
        let partial = makeEndOnlyItem(end: 20)
        XCTAssertThrowsError(try builder.makeRequest(trackIdentity: trackIdentity, regions: [partial])) { error in
            XCTAssertEqual(error as? AnthemMapSaveRequestBuilderError, .noCompleteValidRegion)
        }
    }

    @MainActor
    func testEightRegionsAreAccepted() throws {
        let regions = (0..<8).map { index in
            let start = Double(index * 20)
            return makeValidItem(start: start, end: start + 10)
        }
        let request = try builder.makeRequest(trackIdentity: trackIdentity, regions: regions)
        XCTAssertEqual(request.regions.count, 8)
    }

    @MainActor
    func testNineRegionsAreRejected() {
        let regions = (0..<9).map { index in
            let start = Double(index * 20)
            return makeValidItem(start: start, end: start + 10)
        }
        XCTAssertThrowsError(try builder.makeRequest(trackIdentity: trackIdentity, regions: regions)) { error in
            XCTAssertEqual(error as? AnthemMapSaveRequestBuilderError, .tooManyRegions(9))
        }
    }

    @MainActor
    func testBuildingRequestDoesNotMutateRegions() throws {
        let regions = [
            makeValidItem(start: 10, end: 20),
            makeValidItem(start: 30, end: 40)
        ]
        let before = regions
        _ = try builder.makeRequest(trackIdentity: trackIdentity, regions: regions)
        XCTAssertEqual(regions, before)
    }

    @MainActor
    func testBuildingRequestDoesNotReplaceUUIDs() throws {
        let firstID = UUID()
        let secondID = UUID()
        let regions = [
            makeValidItem(id: firstID, start: 10, end: 20),
            makeValidItem(id: secondID, start: 30, end: 40)
        ]
        let request = try builder.makeRequest(trackIdentity: trackIdentity, regions: regions)
        XCTAssertEqual(request.regions.map(\.id), [firstID, secondID])
    }

    @MainActor
    func testBuildingRequestDoesNotAlterMarkerValues() throws {
        let item = makeValidItem(start: 10.123, end: 20.456)
        let request = try builder.makeRequest(trackIdentity: trackIdentity, regions: [item])
        let originalStart = try XCTUnwrap(item.start)
        let requestStart = try XCTUnwrap(request.regions[0].start)
        let originalEnd = try XCTUnwrap(item.end)
        let requestEnd = try XCTUnwrap(request.regions[0].end)
        XCTAssertEqual(requestStart, originalStart, accuracy: 0.000_001)
        XCTAssertEqual(requestEnd, originalEnd, accuracy: 0.000_001)
    }

    @MainActor
    func testRequestProducesValidPersistentDocument() throws {
        let firstID = UUID()
        let secondID = UUID()
        let regions = [
            makeValidItem(id: firstID, start: 10, end: 20),
            makeValidItem(id: secondID, start: 30, end: 40)
        ]
        let request = try builder.makeRequest(trackIdentity: trackIdentity, regions: regions)
        let document = try saveEngine.makeDocument(from: request)
        XCTAssertTrue(document.isValid)
        XCTAssertEqual(document.track, trackIdentity)
        XCTAssertEqual(document.regions.count, 2)
        XCTAssertEqual(document.regions.map(\.id), [firstID, secondID])
        XCTAssertEqual(document.regions.map(\.slot), [0, 1])
    }

    @MainActor
    func testEmptyFinalRegionIsOmittedBySaveEngine() throws {
        let validID = UUID()
        let request = try builder.makeRequest(
            trackIdentity: trackIdentity,
            regions: [makeValidItem(id: validID, start: 10, end: 20), AnthemRegionItem()]
        )
        let document = try saveEngine.makeDocument(from: request)
        XCTAssertEqual(document.regions.count, 1)
        XCTAssertEqual(document.regions[0].id, validID)
        XCTAssertEqual(document.regions[0].slot, 0)
    }

    @MainActor
    func testPartialFinalRegionIsOmittedBySaveEngine() throws {
        let validID = UUID()
        let request = try builder.makeRequest(
            trackIdentity: trackIdentity,
            regions: [makeValidItem(id: validID, start: 10, end: 20), makeStartOnlyItem(start: 30)]
        )
        let document = try saveEngine.makeDocument(from: request)
        XCTAssertEqual(document.regions.count, 1)
        XCTAssertEqual(document.regions[0].id, validID)
    }

    @MainActor
    func testControllerNormalisedTimingSurvivesPersistence() throws {
        let item = makeValidItem(start: 10.1234, end: 20.4566)
        let normalisedStart = try XCTUnwrap(item.start)
        let normalisedEnd = try XCTUnwrap(item.end)
        XCTAssertEqual(normalisedStart, 10.123, accuracy: 0.000_001)
        XCTAssertEqual(normalisedEnd, 20.457, accuracy: 0.000_001)

        let request = try builder.makeRequest(trackIdentity: trackIdentity, regions: [item])
        let document = try saveEngine.makeDocument(from: request)
        XCTAssertEqual(document.regions[0].startMilliseconds, 10_123)
        XCTAssertEqual(document.regions[0].endMilliseconds, 20_457)
    }

    @MainActor
    private func makeValidItem(
        id: UUID = UUID(),
        start: TimeInterval,
        end: TimeInterval,
        trackDuration: TimeInterval = 300
    ) -> AnthemRegionItem {
        let controller = AnthemRegionController()
        guard controller.setStart(at: start, trackDuration: trackDuration) else {
            XCTFail("Failed to create START marker")
            return AnthemRegionItem(id: id)
        }
        guard controller.setEnd(at: end, trackDuration: trackDuration) else {
            XCTFail("Failed to create END marker")
            return AnthemRegionItem(id: id, region: controller.region)
        }
        XCTAssertTrue(controller.region.isComplete)
        XCTAssertTrue(controller.region.isValid)
        return AnthemRegionItem(id: id, region: controller.region)
    }

    @MainActor
    private func makeStartOnlyItem(
        id: UUID = UUID(),
        start: TimeInterval,
        trackDuration: TimeInterval = 300
    ) -> AnthemRegionItem {
        let controller = AnthemRegionController()
        guard controller.setStart(at: start, trackDuration: trackDuration) else {
            XCTFail("Failed to create START-only marker")
            return AnthemRegionItem(id: id)
        }
        XCTAssertTrue(controller.region.hasStart)
        XCTAssertFalse(controller.region.hasEnd)
        XCTAssertFalse(controller.region.isComplete)
        return AnthemRegionItem(id: id, region: controller.region)
    }

    @MainActor
    private func makeEndOnlyItem(
        id: UUID = UUID(),
        end: TimeInterval,
        trackDuration: TimeInterval = 300
    ) -> AnthemRegionItem {
        let controller = AnthemRegionController()
        guard controller.setEnd(at: end, trackDuration: trackDuration) else {
            XCTFail("Failed to create END-only marker")
            return AnthemRegionItem(id: id)
        }
        XCTAssertFalse(controller.region.hasStart)
        XCTAssertTrue(controller.region.hasEnd)
        XCTAssertFalse(controller.region.isComplete)
        return AnthemRegionItem(id: id, region: controller.region)
    }
}
