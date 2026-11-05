import Foundation
import XCTest
@testable import DJAnthemMapper

@MainActor
final class AnthemMapExistingSaveCoordinatorTests: XCTestCase {
    private let coordinator = AnthemMapExistingSaveCoordinator()

    func testNilMapURLReturnsNoAssociatedMap() throws {
        let snapshot = try snapshot(regions: [item(start: 10, end: 20)])
        let result = coordinator.save(session: .init(mapURL: nil, baseline: snapshot), mediaURL: mediaURL(), trackDuration: 300, currentSnapshot: snapshot)
        assertFailure(result, equals: .noAssociatedMap)
    }

    func testNilMapURLPerformsNoFileWrite() throws {
        try withDirectory { directory in
            let snapshot = try snapshot(regions: [item(start: 10, end: 20)])
            let unused = directory.appendingPathComponent("unused.anthemmap")
            let result = coordinator.save(session: .init(mapURL: nil, baseline: snapshot), mediaURL: mediaURL(), trackDuration: 300, currentSnapshot: snapshot)
            assertFailure(result, equals: .noAssociatedMap)
            XCTAssertFalse(FileManager.default.fileExists(atPath: unused.path))
        }
    }

    func testAssociatedURLIsPreservedExactly() throws {
        try withDirectory { directory in
            let destination = directory.appendingPathComponent("Set.anthemmap")
            let saved = try unwrap(save(destination: destination, snapshot: try snapshot(regions: [item(start: 10, end: 20)])))
            XCTAssertEqual(saved.session.mapURL, destination)
        }
    }

    func testSuccessfulSaveWritesDecodableValidDocument() throws {
        try withDirectory { directory in
            let destination = directory.appendingPathComponent("Set.anthemmap")
            _ = try unwrap(save(destination: destination, snapshot: try snapshot(regions: [item(start: 10, end: 20)])))
            XCTAssertTrue(try document(at: destination).isValid)
        }
    }

    func testSuccessfulSaveUsesTrackIdentitySemantics() throws {
        try withMedia(named: "Track.mp3", bytes: 4096) { media in
            try withDirectory { directory in
                let destination = directory.appendingPathComponent("Set.anthemmap")
                _ = try unwrap(save(destination: destination, media: media, snapshot: try snapshot(regions: [item(start: 10, end: 20)])))
                let track = try document(at: destination).track
                XCTAssertEqual(track.fileName, "Track.mp3")
                XCTAssertEqual(track.fileSize, 4096)
                XCTAssertEqual(track.durationMilliseconds, 300_000)
            }
        }
    }

    func testSuccessfulSavePreservesStableRegionUUIDs() throws {
        try withDirectory { directory in
            let id = UUID()
            let destination = directory.appendingPathComponent("Set.anthemmap")
            _ = try unwrap(save(destination: destination, snapshot: try snapshot(regions: [item(start: 10, end: 20, id: id)])))
            XCTAssertEqual(try document(at: destination).regions.map(\.id), [id])
        }
    }

    func testSuccessfulSavePreservesOrderThroughSlots() throws {
        try withDirectory { directory in
            let first = item(start: 10, end: 20)
            let second = item(start: 30, end: 40)
            let third = item(start: 50, end: 60)
            let destination = directory.appendingPathComponent("Set.anthemmap")
            _ = try unwrap(save(destination: destination, snapshot: try snapshot(regions: [first, second, third])))
            let saved = try document(at: destination)
            XCTAssertEqual(saved.regions.map(\.id), [first.id, second.id, third.id])
            XCTAssertEqual(saved.regions.map(\.slot), [0, 1, 2])
        }
    }

    func testSuccessfulSavePreservesMillisecondConversion() throws {
        try withDirectory { directory in
            let destination = directory.appendingPathComponent("Set.anthemmap")
            _ = try unwrap(save(destination: destination, snapshot: try snapshot(regions: [item(start: 10.123, end: 20.456)])))
            let region = try XCTUnwrap(try document(at: destination).regions.first)
            XCTAssertEqual(region.startMilliseconds, 10_123)
            XCTAssertEqual(region.endMilliseconds, 20_456)
        }
    }

    func testSuccessfulSaveReturnsCurrentSnapshotAsBaseline() throws {
        try withDirectory { directory in
            let old = try snapshot(regions: [item(start: 10, end: 20)])
            let current = try snapshot(regions: [item(start: 30, end: 40)])
            let destination = directory.appendingPathComponent("Set.anthemmap")
            let result = coordinator.save(session: .init(mapURL: destination, baseline: old), mediaURL: mediaURL(), trackDuration: 300, currentSnapshot: current)
            XCTAssertEqual(try unwrap(result).session.baseline, current)
        }
    }

    func testReturnedSessionIsCleanAgainstSavedSnapshot() throws {
        try withDirectory { directory in
            let snapshot = try snapshot(regions: [item(start: 10, end: 20)])
            let saved = try unwrap(save(destination: directory.appendingPathComponent("Set.anthemmap"), snapshot: snapshot))
            XCTAssertEqual(saved.session.dirtyState(current: snapshot), .clean)
        }
    }

    func testActiveSelectionOnlyDifferenceIsCleanBeforeAndAfterSave() throws {
        try withDirectory { directory in
            let first = item(start: 10, end: 20)
            let second = item(start: 30, end: 40)
            let baseline = try snapshot(regions: [first, second], active: first.id)
            let current = try snapshot(regions: [first, second], active: second.id)
            let session = AnthemMapSession(mapURL: directory.appendingPathComponent("Set.anthemmap"), baseline: baseline)
            XCTAssertEqual(session.dirtyState(current: current), .clean)
            let saved = try unwrap(coordinator.save(session: session, mediaURL: mediaURL(), trackDuration: 300, currentSnapshot: current))
            XCTAssertEqual(saved.session.dirtyState(current: current), .clean)
            XCTAssertEqual(saved.session.baseline.activeRegionID, second.id)
        }
    }

    func testOriginalInputSessionIsNotMutated() throws {
        try withDirectory { directory in
            let snapshot = try snapshot(regions: [item(start: 10, end: 20)])
            let session = AnthemMapSession(mapURL: directory.appendingPathComponent("Set.anthemmap"), baseline: snapshot)
            let before = session
            _ = try unwrap(coordinator.save(session: session, mediaURL: mediaURL(), trackDuration: 300, currentSnapshot: snapshot))
            XCTAssertEqual(session, before)
        }
    }

    func testCurrentSnapshotIsNotMutated() throws {
        try withDirectory { directory in
            let snapshot = try snapshot(regions: [item(start: 10, end: 20)])
            let before = snapshot
            _ = try unwrap(save(destination: directory.appendingPathComponent("Set.anthemmap"), snapshot: snapshot))
            XCTAssertEqual(snapshot, before)
        }
    }

    func testPreparationFailureLeavesDestinationUnchanged() throws {
        try withDirectory { directory in
            let destination = directory.appendingPathComponent("Set.anthemmap")
            let original = Data("original".utf8)
            try original.write(to: destination)
            let invalid = try snapshot(regions: [item()])
            let result = coordinator.save(session: .init(mapURL: destination, baseline: invalid), mediaURL: mediaURL(), trackDuration: 300, currentSnapshot: invalid)
            assertFailure(result, equals: .preparationFailed)
            XCTAssertEqual(try Data(contentsOf: destination), original)
        }
    }

    func testExecutionFailureLeavesOriginalSessionBaselineUnchanged() throws {
        try withDirectory { directory in
            let snapshot = try snapshot(regions: [item(start: 10, end: 20)])
            let destination = directory.appendingPathComponent("missing", isDirectory: true).appendingPathComponent("Set.anthemmap")
            let session = AnthemMapSession(mapURL: destination, baseline: snapshot)
            let before = session
            let result = coordinator.save(session: session, mediaURL: mediaURL(), trackDuration: 300, currentSnapshot: snapshot)
            assertFailure(result, equals: .executionFailed)
            XCTAssertEqual(session, before)
        }
    }

    func testExecutionFailureDoesNotReturnReplacementSession() throws {
        try withDirectory { directory in
            let snapshot = try snapshot(regions: [item(start: 10, end: 20)])
            let destination = directory.appendingPathComponent("missing", isDirectory: true).appendingPathComponent("Set.anthemmap")
            assertFailure(save(destination: destination, snapshot: snapshot), equals: .executionFailed)
        }
    }

    func testInvalidDurationReturnsPreparationFailure() throws {
        try withDirectory { directory in
            let snapshot = try snapshot(regions: [item(start: 10, end: 20)])
            let result = coordinator.save(session: .init(mapURL: directory.appendingPathComponent("Set.anthemmap"), baseline: snapshot), mediaURL: mediaURL(), trackDuration: 0, currentSnapshot: snapshot)
            assertFailure(result, equals: .preparationFailed)
        }
    }

    func testInvalidMediaIdentityReturnsPreparationFailure() throws {
        try withDirectory { directory in
            let snapshot = try snapshot(regions: [item(start: 10, end: 20)])
            let invalidMedia = try XCTUnwrap(URL(string: "custom://"))
            XCTAssertEqual(invalidMedia.lastPathComponent, "")
            let result = coordinator.save(session: .init(mapURL: directory.appendingPathComponent("Set.anthemmap"), baseline: snapshot), mediaURL: invalidMedia, trackDuration: 300, currentSnapshot: snapshot)
            assertFailure(result, equals: .preparationFailed)
        }
    }

    func testExistingDestinationIsReplacedByCertifiedExecutionPath() throws {
        try withDirectory { directory in
            let destination = directory.appendingPathComponent("Set.anthemmap")
            try Data("old".utf8).write(to: destination)
            _ = try unwrap(save(destination: destination, snapshot: try snapshot(regions: [item(start: 10, end: 20)])))
            XCTAssertTrue(try document(at: destination).isValid)
        }
    }

    func testSuccessfulOverwriteReplacesOldDocumentContent() throws {
        try withDirectory { directory in
            let destination = directory.appendingPathComponent("Set.anthemmap")
            _ = try unwrap(save(destination: destination, snapshot: try snapshot(regions: [item(start: 10, end: 20)])))
            let id = UUID()
            _ = try unwrap(save(destination: destination, snapshot: try snapshot(regions: [item(start: 30, end: 40, id: id)])))
            let saved = try document(at: destination)
            XCTAssertEqual(saved.regions.map(\.id), [id])
            XCTAssertEqual(saved.regions.first?.startMilliseconds, 30_000)
        }
    }

    func testSuccessfulOverwriteDoesNotAddDuplicateExtension() throws {
        try withDirectory { directory in
            let destination = directory.appendingPathComponent("Set.anthemmap")
            _ = try unwrap(save(destination: destination, snapshot: try snapshot(regions: [item(start: 10, end: 20)])))
            XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: "\(destination.path).anthemmap"))
        }
    }

    func testSaveUsesOnlyAssociatedDestinationWithoutPanelOrPresenter() throws {
        try withDirectory { directory in
            let destination = directory.appendingPathComponent("Set.anthemmap")
            _ = try unwrap(save(destination: destination, snapshot: try snapshot(regions: [item(start: 10, end: 20)])))
            XCTAssertEqual(try document(at: destination).regions.count, 1)
        }
    }

    func testSaveHasNoOpenOrRestorationDependency() throws {
        try withDirectory { directory in
            _ = try unwrap(save(destination: directory.appendingPathComponent("Set.anthemmap"), snapshot: try snapshot(regions: [item(start: 10, end: 20)])))
        }
    }

    func testSaveHasNoControllerPlaybackOrWaveformDependency() throws {
        try withDirectory { directory in
            _ = try unwrap(save(destination: directory.appendingPathComponent("Set.anthemmap"), snapshot: try snapshot(regions: [item(start: 10, end: 20)])))
        }
    }

    func testResultMatchesDirectCertifiedPipeline() throws {
        try withDirectory { directory in
            let snapshot = try snapshot(regions: [item(start: 10, end: 20)])
            let coordinatorDestination = directory.appendingPathComponent("Coordinator.anthemmap")
            let directDestination = directory.appendingPathComponent("Direct.anthemmap")
            _ = try unwrap(save(destination: coordinatorDestination, snapshot: snapshot))
            let prepared = try AnthemMapSaveCoordinator().prepare(mediaURL: mediaURL(), trackDuration: 300, regions: snapshot.regions)
            try AnthemMapSaveExecutor().execute(preparedSave: prepared, destinationURL: directDestination)
            XCTAssertEqual(try document(at: coordinatorDestination), try document(at: directDestination))
        }
    }

    private func save(destination: URL, media: URL? = nil, snapshot: AnthemRegionSnapshot) -> Result<AnthemMapExistingSaveCoordinator.Success, AnthemMapExistingSaveCoordinator.Failure> {
        coordinator.save(session: .init(mapURL: destination, baseline: snapshot), mediaURL: media ?? mediaURL(), trackDuration: 300, currentSnapshot: snapshot)
    }

    private func unwrap(_ result: Result<AnthemMapExistingSaveCoordinator.Success, AnthemMapExistingSaveCoordinator.Failure>) throws -> AnthemMapExistingSaveCoordinator.Success {
        switch result {
        case .success(let value): return value
        case .failure(let failure): throw failure
        }
    }

    private func assertFailure(_ result: Result<AnthemMapExistingSaveCoordinator.Success, AnthemMapExistingSaveCoordinator.Failure>, equals expected: AnthemMapExistingSaveCoordinator.Failure, file: StaticString = #filePath, line: UInt = #line) {
        switch result {
        case .success: XCTFail("Expected failure", file: file, line: line)
        case .failure(let actual): XCTAssertEqual(actual, expected, file: file, line: line)
        }
    }

    private func document(at url: URL) throws -> AnthemMapDocument {
        try JSONDecoder().decode(AnthemMapDocument.self, from: Data(contentsOf: url))
    }

    private func mediaURL() -> URL { URL(fileURLWithPath: "/Media/Track.mp3") }

    private func snapshot(regions: [AnthemRegionItem], active: UUID? = nil) throws -> AnthemRegionSnapshot {
        try AnthemRegionSnapshot(regions: regions, activeRegionID: active ?? regions[0].id)
    }

    private func item(start: TimeInterval? = nil, end: TimeInterval? = nil, id: UUID = UUID()) -> AnthemRegionItem {
        AnthemRegionItem(id: id, region: AnthemRegion(start: start, end: end))
    }

    private func withDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    private func withMedia(named name: String, bytes: Int, _ body: (URL) throws -> Void) throws {
        try withDirectory { directory in
            let file = directory.appendingPathComponent(name)
            try Data(repeating: 0x41, count: bytes).write(to: file)
            try body(file)
        }
    }
}
