import XCTest
@testable import DJAnthemMapper

final class AnthemMapSaveEngineTests: XCTestCase {
    private let engine = AnthemMapSaveEngine()
    private let track = AnthemMapDocument.TrackIdentity(fileName: "track.mp3", fileSize: 4_096, durationMilliseconds: 300_000)

    private func item(id: UUID = UUID(), start: Double?, end: Double?) -> AnthemRegionItem {
        AnthemRegionItem(id: id, region: AnthemRegion(start: start, end: end))
    }

    private func temporaryURL(_ name: String = UUID().uuidString) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(name).appendingPathExtension("anthemmap")
    }

    func testSingleRegionConversion() throws {
        let document = try engine.makeDocument(from: .init(track: track, regions: [item(start: 1, end: 2)]))
        XCTAssertEqual(document.regions.count, 1)
        XCTAssertEqual(document.regions[0].slot, 0)
    }

    func testEightRegionConversion() throws {
        let regions = (0..<8).map { item(start: Double($0 * 10), end: Double($0 * 10 + 5)) }
        let document = try engine.makeDocument(from: .init(track: track, regions: regions))
        XCTAssertEqual(document.regions.count, 8)
        XCTAssertEqual(document.regions.map(\.slot), Array(0..<8))
    }

    func testStableUUIDPreservation() throws {
        let id = UUID()
        let document = try engine.makeDocument(from: .init(track: track, regions: [item(id: id, start: 1, end: 2)]))
        XCTAssertEqual(document.regions[0].id, id)
    }

    func testIncompleteRegionIsOmittedButSlotPositionIsPreserved() throws {
        let regions = [item(start: 1, end: 2), item(start: nil, end: nil), item(start: 3, end: 4)]
        let document = try engine.makeDocument(from: .init(track: track, regions: regions))
        XCTAssertEqual(document.regions.map(\.slot), [0, 2])
    }

    func testMillisecondConversionUsesRounding() throws {
        let document = try engine.makeDocument(from: .init(track: track, regions: [item(start: 1.2344, end: 5.6786)]))
        XCTAssertEqual(document.regions[0].startMilliseconds, 1_234)
        XCTAssertEqual(document.regions[0].endMilliseconds, 5_679)
    }

    func testTrackMetadataPreservation() throws {
        let document = try engine.makeDocument(from: .init(track: track, regions: [item(start: 1, end: 2)]))
        XCTAssertEqual(document.track, track)
    }

    func testMoreThanEightLiveRegionsIsRefusedWithoutTruncation() {
        let regions = (0..<9).map { item(start: Double($0 * 10), end: Double($0 * 10 + 5)) }
        XCTAssertThrowsError(try engine.makeDocument(from: .init(track: track, regions: regions))) { error in
            XCTAssertEqual(error as? AnthemMapSaveError, .tooManyRegions(9))
        }
    }

    func testInvalidDocumentIsRefusedBeforeWriting() {
        let invalidTrack = AnthemMapDocument.TrackIdentity(fileName: "", fileSize: nil, durationMilliseconds: 0)
        let document = AnthemMapDocument(track: invalidTrack, regions: [])
        XCTAssertThrowsError(try engine.save(document: document, to: temporaryURL()))
    }

    func testSuccessfulFileCreation() throws {
        let url = temporaryURL(); defer { try? FileManager.default.removeItem(at: url) }
        let request = AnthemMapSaveRequest(track: track, regions: [item(start: 1, end: 2)])
        try engine.save(request: request, to: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testSavedJSONDecodesBackIdentically() throws {
        let url = temporaryURL(); defer { try? FileManager.default.removeItem(at: url) }
        let document = try engine.makeDocument(from: .init(track: track, regions: [item(start: 1.111, end: 2.222)]))
        try engine.save(document: document, to: url)
        let decoded = try JSONDecoder().decode(AnthemMapDocument.self, from: Data(contentsOf: url))
        XCTAssertEqual(decoded, document)
    }

    func testExistingFileIsAtomicallyReplaced() throws {
        let url = temporaryURL(); defer { try? FileManager.default.removeItem(at: url) }
        try Data("old".utf8).write(to: url)
        let document = try engine.makeDocument(from: .init(track: track, regions: [item(start: 10, end: 20)]))
        try engine.save(document: document, to: url)
        XCTAssertEqual(try JSONDecoder().decode(AnthemMapDocument.self, from: Data(contentsOf: url)), document)
    }

    func testFailedSaveDoesNotCorruptExistingGoodFile() throws {
        let url = temporaryURL(); defer { try? FileManager.default.removeItem(at: url) }
        let original = Data("known-good".utf8); try original.write(to: url)
        let invalidTrack = AnthemMapDocument.TrackIdentity(fileName: "", fileSize: nil, durationMilliseconds: 0)
        XCTAssertThrowsError(try engine.save(document: AnthemMapDocument(track: invalidTrack, regions: []), to: url))
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testDeterministicJSONOutput() throws {
        let document = try engine.makeDocument(from: .init(track: track, regions: [item(start: 1, end: 2)]))
        XCTAssertEqual(try engine.encodedData(for: document), try engine.encodedData(for: document))
    }
}
