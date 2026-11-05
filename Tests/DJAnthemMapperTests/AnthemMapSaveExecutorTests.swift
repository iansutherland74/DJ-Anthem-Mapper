import Foundation
import XCTest
@testable import DJAnthemMapper

final class AnthemMapSaveExecutorTests: XCTestCase {
    @MainActor
    func testExecutionCreatesFileAtSelectedDestination() throws {
        try withTemporaryDirectory { directory in
            let destination = directory.appendingPathComponent("Track.anthemmap")
            let returned = try AnthemMapSaveExecutor().execute(preparedSave: makePreparedSave(), destinationURL: destination)
            XCTAssertEqual(returned, destination)
            XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        }
    }

    @MainActor
    func testSavedDocumentDecodesIdentically() throws {
        try withTemporaryDirectory { directory in
            let prepared = makePreparedSave()
            let destination = directory.appendingPathComponent("Track.anthemmap")
            try AnthemMapSaveExecutor().execute(preparedSave: prepared, destinationURL: destination)
            let decoded = try JSONDecoder().decode(AnthemMapDocument.self, from: Data(contentsOf: destination))
            XCTAssertEqual(decoded, prepared.document)
        }
    }

    @MainActor
    func testExistingFileIsReplacedAtomically() throws {
        try withTemporaryDirectory { directory in
            let destination = directory.appendingPathComponent("Track.anthemmap")
            try Data("old".utf8).write(to: destination)
            let prepared = makePreparedSave()
            try AnthemMapSaveExecutor().execute(preparedSave: prepared, destinationURL: destination)
            let decoded = try JSONDecoder().decode(AnthemMapDocument.self, from: Data(contentsOf: destination))
            XCTAssertEqual(decoded, prepared.document)
        }
    }

    @MainActor
    func testExecutionPreservesPreparedSave() throws {
        try withTemporaryDirectory { directory in
            let prepared = makePreparedSave()
            let before = prepared
            try AnthemMapSaveExecutor().execute(preparedSave: prepared, destinationURL: directory.appendingPathComponent("Track.anthemmap"))
            XCTAssertEqual(prepared, before)
        }
    }

    @MainActor
    func testExecutionPreservesStableRegionUUIDAndSlot() throws {
        try withTemporaryDirectory { directory in
            let id = UUID()
            let prepared = makePreparedSave(regionID: id)
            let destination = directory.appendingPathComponent("Track.anthemmap")
            try AnthemMapSaveExecutor().execute(preparedSave: prepared, destinationURL: destination)
            let decoded = try JSONDecoder().decode(AnthemMapDocument.self, from: Data(contentsOf: destination))
            XCTAssertEqual(decoded.regions.first?.id, id)
            XCTAssertEqual(decoded.regions.first?.slot, 0)
        }
    }

    @MainActor
    func testWriteFailureIsPropagated() throws {
        try withTemporaryDirectory { directory in
            let missingDirectory = directory.appendingPathComponent("missing", isDirectory: true)
            let destination = missingDirectory.appendingPathComponent("Track.anthemmap")
            XCTAssertThrowsError(try AnthemMapSaveExecutor().execute(preparedSave: makePreparedSave(), destinationURL: destination))
            XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        }
    }

    @MainActor
    private func makePreparedSave(regionID: UUID = UUID()) -> AnthemMapSaveCoordinator.PreparedSave {
        let track = AnthemMapDocument.TrackIdentity(fileName: "Test Track.mp3", fileSize: UInt64(4_096), durationMilliseconds: Int64(300_000))
        let region = AnthemMapDocument.Region(id: regionID, slot: 0, startMilliseconds: Int64(10_000), endMilliseconds: Int64(20_000))
        return AnthemMapSaveCoordinator.PreparedSave(
            document: AnthemMapDocument(track: track, regions: [region]),
            suggestedFileName: "Test Track.anthemmap"
        )
    }

    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }
}
