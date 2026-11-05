import Foundation
import XCTest
@testable import DJAnthemMapper

@MainActor
final class AnthemMapOpenCoordinatorTests: XCTestCase {
    private func identity(fileName: String = "Track.mp3", fileSize: UInt64? = 4_096, durationMilliseconds: Int64 = 300_000) -> AnthemMapDocument.TrackIdentity {
        .init(fileName: fileName, fileSize: fileSize, durationMilliseconds: durationMilliseconds)
    }

    private func document(track: AnthemMapDocument.TrackIdentity? = nil, id: UUID = UUID(), start: Int64 = 10_000, end: Int64 = 20_000) -> AnthemMapDocument {
        AnthemMapDocument(track: track ?? identity(), regions: [.init(id: id, slot: 0, startMilliseconds: start, endMilliseconds: end)])
    }

    private func write(_ document: AnthemMapDocument) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("anthemmap")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(document).write(to: url, options: .atomic)
        return url
    }

    private func seededController() -> AnthemRegionController {
        AnthemRegionController(region: AnthemRegion(start: 1, end: 2))
    }

    private func assertUnchanged(_ controller: AnthemRegionController, regions: [AnthemRegionItem], activeID: UUID, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(controller.regions, regions, file: file, line: line)
        XCTAssertEqual(controller.activeRegionID, activeID, file: file, line: line)
    }

    func testValidMapAndMatchingTrackRestoresSuccessfully() throws {
        let id = UUID(), url = try write(document(id: id)); defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = AnthemMapOpenCoordinator(), controller = seededController()
        XCTAssertTrue(coordinator.open(mapURL: url, actualTrackIdentity: identity(), controller: controller))
        XCTAssertEqual(controller.regions.first?.id, id)
        XCTAssertEqual(controller.start, 10)
        XCTAssertEqual(controller.end, 20)
    }

    func testSuccessSetsOpenedStatus() throws {
        let url = try write(document()); defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = AnthemMapOpenCoordinator()
        XCTAssertTrue(coordinator.open(mapURL: url, actualTrackIdentity: identity(), controller: seededController()))
        XCTAssertEqual(coordinator.status, .opened)
    }

    func testMissingMapFailsWithoutControllerMutation() {
        let coordinator = AnthemMapOpenCoordinator(), controller = seededController()
        let before = controller.regions, active = controller.activeRegionID
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("anthemmap")
        XCTAssertFalse(coordinator.open(mapURL: url, actualTrackIdentity: identity(), controller: controller))
        XCTAssertEqual(coordinator.status, .failed(.read(.readFailed)))
        assertUnchanged(controller, regions: before, activeID: active)
    }

    func testMalformedMapFailsWithoutControllerMutation() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("anthemmap")
        try Data("not-json".utf8).write(to: url); defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = AnthemMapOpenCoordinator(), controller = seededController(); let before = controller.regions, active = controller.activeRegionID
        XCTAssertFalse(coordinator.open(mapURL: url, actualTrackIdentity: identity(), controller: controller))
        XCTAssertEqual(coordinator.status, .failed(.read(.decodingFailed)))
        assertUnchanged(controller, regions: before, activeID: active)
    }

    func testInvalidDocumentFailsWithoutControllerMutation() throws {
        let invalid = AnthemMapDocument(track: identity(), regions: [.init(id: UUID(), slot: 0, startMilliseconds: 20_000, endMilliseconds: 10_000)])
        let url = try write(invalid); defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = AnthemMapOpenCoordinator(), controller = seededController(); let before = controller.regions, active = controller.activeRegionID
        XCTAssertFalse(coordinator.open(mapURL: url, actualTrackIdentity: identity(), controller: controller))
        guard case .failed(.read(.invalidDocument(let errors))) = coordinator.status else { return XCTFail("Expected invalid-document read failure") }
        XCTAssertFalse(errors.isEmpty); assertUnchanged(controller, regions: before, activeID: active)
    }

    func testFilenameMismatchPreventsRestoration() throws {
        let url = try write(document()); defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = AnthemMapOpenCoordinator(), controller = seededController(); let before = controller.regions, active = controller.activeRegionID
        XCTAssertFalse(coordinator.open(mapURL: url, actualTrackIdentity: identity(fileName: "Other.mp3"), controller: controller))
        XCTAssertEqual(coordinator.status, .failed(.trackMismatch([.fileName])))
        assertUnchanged(controller, regions: before, activeID: active)
    }

    func testDurationMismatchPreventsRestoration() throws {
        let url = try write(document()); defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = AnthemMapOpenCoordinator(), controller = seededController(); let before = controller.regions, active = controller.activeRegionID
        XCTAssertFalse(coordinator.open(mapURL: url, actualTrackIdentity: identity(durationMilliseconds: 300_001), controller: controller))
        XCTAssertEqual(coordinator.status, .failed(.trackMismatch([.duration])))
        assertUnchanged(controller, regions: before, activeID: active)
    }

    func testFileSizeMismatchPreventsRestoration() throws {
        let url = try write(document()); defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = AnthemMapOpenCoordinator(), controller = seededController(); let before = controller.regions, active = controller.activeRegionID
        XCTAssertFalse(coordinator.open(mapURL: url, actualTrackIdentity: identity(fileSize: 8_192), controller: controller))
        XCTAssertEqual(coordinator.status, .failed(.trackMismatch([.fileSize])))
        assertUnchanged(controller, regions: before, activeID: active)
    }

    func testMultipleMismatchReasonsArePreserved() throws {
        let url = try write(document()); defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = AnthemMapOpenCoordinator()
        let actual = identity(fileName: "Other.mp3", fileSize: 8_192, durationMilliseconds: 300_001)
        XCTAssertFalse(coordinator.open(mapURL: url, actualTrackIdentity: actual, controller: seededController()))
        XCTAssertEqual(coordinator.status, .failed(.trackMismatch([.fileName, .fileSize, .duration])))
    }

    func testUUIDAndTimingArePreservedEndToEnd() throws {
        let id = UUID(), url = try write(document(id: id, start: 12_345, end: 67_890)); defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = AnthemMapOpenCoordinator(), controller = seededController()
        XCTAssertTrue(coordinator.open(mapURL: url, actualTrackIdentity: identity(), controller: controller))
        XCTAssertEqual(controller.regions.first?.id, id)
        XCTAssertEqual(controller.start, 12.345)
        XCTAssertEqual(controller.end, 67.89)
    }

    func testResetReturnsStatusToIdle() throws {
        let url = try write(document()); defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = AnthemMapOpenCoordinator()
        XCTAssertTrue(coordinator.open(mapURL: url, actualTrackIdentity: identity(), controller: seededController()))
        XCTAssertEqual(coordinator.status, .opened)
        coordinator.reset()
        XCTAssertEqual(coordinator.status, .idle)
    }
}
