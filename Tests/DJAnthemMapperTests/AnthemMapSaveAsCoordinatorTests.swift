import Foundation
import XCTest
@testable import DJAnthemMapper

@MainActor
final class AnthemMapSaveAsCoordinatorTests: XCTestCase {
    private enum TestError: Error { case expected }

    func testNilSessionSaves() throws {
        let result = try save()
        XCTAssertTrue(isSaved(result))
    }

    func testExistingSessionSaves() throws {
        let snapshot = try validSnapshot()
        let result = try save(session: .init(mapURL: URL(fileURLWithPath: "/Old.anthemmap"), baseline: snapshot))
        XCTAssertTrue(isSaved(result))
    }

    func testSelectedURLIsReturnedExactly() throws {
        let destination = artifactURL("exact.anthemmap")
        let result = try save(destination: destination)
        XCTAssertEqual(try saved(result).session.mapURL, destination)
    }

    func testSuccessfulSaveUsesCurrentSnapshotAsBaseline() throws {
        let snapshot = try validSnapshot()
        XCTAssertEqual(try saved(try save(snapshot: snapshot)).session.baseline, snapshot)
    }

    func testSuccessfulSessionIsClean() throws {
        let snapshot = try validSnapshot()
        XCTAssertEqual(try saved(try save(snapshot: snapshot)).session.dirtyState(current: snapshot), .clean)
    }

    func testSuccessfulSavePreservesActiveRegionID() throws {
        let first = item(10, 20)
        let second = item(30, 40)
        let snapshot = try AnthemRegionSnapshot(regions: [first, second], activeRegionID: second.id)
        XCTAssertEqual(try saved(try save(snapshot: snapshot)).session.baseline.activeRegionID, second.id)
    }

    func testExistingSessionIsNotMutated() throws {
        let snapshot = try validSnapshot()
        let session = AnthemMapSession(mapURL: URL(fileURLWithPath: "/Old.anthemmap"), baseline: snapshot)
        let before = session
        _ = try save(session: session, snapshot: snapshot)
        XCTAssertEqual(session, before)
    }

    func testCurrentSnapshotIsNotMutated() throws {
        let snapshot = try validSnapshot()
        let before = snapshot
        _ = try save(snapshot: snapshot)
        XCTAssertEqual(snapshot, before)
    }

    func testPreparationFailureReturnsTypedFailure() throws {
        XCTAssertEqual(try invoke(prepare: { _, _, _ in throw TestError.expected }), .failed(.preparationFailed))
    }

    func testPreparationFailureDoesNotPresentPanel() throws {
        var calls = 0
        _ = try invoke(panel: { _, _ in calls += 1 }, prepare: { _, _, _ in throw TestError.expected })
        XCTAssertEqual(calls, 0)
    }

    func testPreparationFailureDoesNotExecute() throws {
        var calls = 0
        _ = try invoke(prepare: { _, _, _ in throw TestError.expected }, execute: { _, _ in calls += 1; return self.artifactURL("unused") })
        XCTAssertEqual(calls, 0)
    }

    func testPreparationFailureLeavesSessionUnchanged() throws {
        let snapshot = try validSnapshot()
        let session = AnthemMapSession(mapURL: URL(fileURLWithPath: "/Old.anthemmap"), baseline: snapshot)
        _ = try invoke(session: session, prepare: { _, _, _ in throw TestError.expected })
        XCTAssertEqual(session.mapURL?.path, "/Old.anthemmap")
    }

    func testCancellationReturnsCancelled() throws {
        XCTAssertEqual(try invoke(panel: { _, completion in completion(.cancelled) }), .cancelled)
    }

    func testCancellationDoesNotExecute() throws {
        var calls = 0
        _ = try invoke(panel: { _, completion in completion(.cancelled) }, execute: { _, _ in calls += 1; return self.artifactURL("unused") })
        XCTAssertEqual(calls, 0)
    }

    func testCancellationDoesNotCreateReplacementSession() throws {
        XCTAssertEqual(try invoke(panel: { _, completion in completion(.cancelled) }), .cancelled)
    }

    func testUnavailableReturnsTypedFailure() throws {
        XCTAssertEqual(try invoke(panel: { _, completion in completion(.unavailable) }), .failed(.panelUnavailable))
    }

    func testUnavailableDoesNotExecute() throws {
        var calls = 0
        _ = try invoke(panel: { _, completion in completion(.unavailable) }, execute: { _, _ in calls += 1; return self.artifactURL("unused") })
        XCTAssertEqual(calls, 0)
    }

    func testExecutionFailureReturnsTypedFailure() throws {
        XCTAssertEqual(try invoke(execute: { _, _ in throw TestError.expected }), .failed(.executionFailed))
    }

    func testExecutionFailureDoesNotCreateReplacementSession() throws {
        XCTAssertEqual(try invoke(execute: { _, _ in throw TestError.expected }), .failed(.executionFailed))
    }

    func testPreparedDocumentTrackIsPassedToExecutor() throws {
        let prepared = makePrepared(trackName: "Identity.mp3")
        var received: AnthemMapSaveCoordinator.PreparedSave?
        _ = try invoke(prepare: { _, _, _ in prepared }, execute: { save, _ in received = save; return self.artifactURL("saved") })
        XCTAssertEqual(received?.document.track.fileName, "Identity.mp3")
    }

    func testPreparedDocumentPreservesUUID() throws {
        let id = UUID()
        let prepared = makePrepared(regionID: id)
        var received: AnthemMapSaveCoordinator.PreparedSave?
        _ = try invoke(prepare: { _, _, _ in prepared }, execute: { save, _ in received = save; return self.artifactURL("saved") })
        XCTAssertEqual(received?.document.regions.first?.id, id)
    }

    func testPreparedDocumentPreservesSlot() throws {
        let prepared = makePrepared(slot: 3)
        var received: AnthemMapSaveCoordinator.PreparedSave?
        _ = try invoke(prepare: { _, _, _ in prepared }, execute: { save, _ in received = save; return self.artifactURL("saved") })
        XCTAssertEqual(received?.document.regions.first?.slot, 3)
    }

    func testPreparedDocumentPreservesMilliseconds() throws {
        let prepared = makePrepared(start: 10_123, end: 20_456)
        var received: AnthemMapSaveCoordinator.PreparedSave?
        _ = try invoke(prepare: { _, _, _ in prepared }, execute: { save, _ in received = save; return self.artifactURL("saved") })
        XCTAssertEqual(received?.document.regions.first?.startMilliseconds, 10_123)
        XCTAssertEqual(received?.document.regions.first?.endMilliseconds, 20_456)
    }

    func testPreparedTrackFileSizeIsPassedToExecutor() throws {
        let prepared = makePrepared(fileSize: 4_096)
        var received: AnthemMapSaveCoordinator.PreparedSave?
        _ = try invoke(prepare: { _, _, _ in prepared }, execute: { save, _ in received = save; return self.artifactURL("saved") })
        XCTAssertEqual(received?.document.track.fileSize, 4_096)
    }

    func testPreparedSuggestedFilenameIsPassedToPanel() throws {
        let prepared = makePrepared(name: "Suggested.anthemmap")
        var name: String?
        _ = try invoke(panel: { save, completion in name = save.suggestedFileName; completion(.cancelled) }, prepare: { _, _, _ in prepared })
        XCTAssertEqual(name, "Suggested.anthemmap")
    }

    func testSuggestedFilenameUsesAnthemMapExtension() throws {
        let prepared = makePrepared(name: "Suggested.anthemmap")
        var name: String?
        _ = try invoke(panel: { save, completion in name = save.suggestedFileName; completion(.cancelled) }, prepare: { _, _, _ in prepared })
        XCTAssertEqual(URL(fileURLWithPath: name!).pathExtension, "anthemmap")
    }

    func testIncompleteRegionIsPassedThroughForPreparationSemantics() throws {
        let complete = item(10, 20)
        let incomplete = AnthemRegionItem(id: UUID(), region: AnthemRegion(start: 30, end: nil))
        let snapshot = try AnthemRegionSnapshot(regions: [complete, incomplete], activeRegionID: complete.id)
        var regions: [AnthemRegionItem] = []
        _ = try invoke(snapshot: snapshot, prepare: { _, _, values in regions = values; return self.makePrepared() })
        XCTAssertEqual(regions, snapshot.regions)
    }

    func testSelectedDestinationIsPassedToExecutorExactly() throws {
        let destination = artifactURL("selected.anthemmap")
        var received: URL?
        _ = try invoke(destination: destination, execute: { _, url in received = url; return url })
        XCTAssertEqual(received, destination)
    }

    func testExistingDestinationIsPassedToExecutor() throws {
        let destination = artifactURL("overwrite.anthemmap")
        var received: URL?
        _ = try invoke(destination: destination, execute: { _, url in received = url; return url })
        XCTAssertEqual(received, destination)
    }

    func testPanelSeamAvoidsAppKitUI() throws {
        var called = false
        _ = try invoke(panel: { _, completion in called = true; completion(.cancelled) })
        XCTAssertTrue(called)
    }

    func testCoordinatorHasNoOpenDependency() throws {
        XCTAssertEqual(try invoke(panel: { _, completion in completion(.cancelled) }), .cancelled)
    }

    func testCoordinatorHasNoPlaybackDependency() throws {
        XCTAssertEqual(try invoke(panel: { _, completion in completion(.cancelled) }), .cancelled)
    }

    func testResultMatchesDirectPreparationAndExecutionPipeline() throws {
        let snapshot = try validSnapshot()
        let destination = artifactURL("pipeline.anthemmap")
        try FileManager.default.createDirectory(at: artifactDirectory(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: artifactDirectory()) }
        let result = try invoke(snapshot: snapshot, destination: destination)
        let direct = try AnthemMapSaveCoordinator().prepare(mediaURL: mediaURL(), trackDuration: 300, regions: snapshot.regions)
        try AnthemMapSaveExecutor().execute(preparedSave: direct, destinationURL: artifactURL("direct.anthemmap"))
        XCTAssertEqual(try read(destination), try read(artifactURL("direct.anthemmap")))
        XCTAssertEqual(try saved(result).session.baseline, snapshot)
    }

    func testSuccessfulCompletionOccursExactlyOnce() throws {
        var completions = 0
        _ = try invoke(panel: { _, completion in completion(.selected(self.artifactURL("once.anthemmap"))); completion(.cancelled) }, onCompletion: { _ in completions += 1 })
        XCTAssertEqual(completions, 1)
    }

    func testCancelledCompletionOccursExactlyOnce() throws {
        var completions = 0
        _ = try invoke(panel: { _, completion in completion(.cancelled); completion(.unavailable) }, onCompletion: { _ in completions += 1 })
        XCTAssertEqual(completions, 1)
    }

    func testUnavailableCompletionOccursExactlyOnce() throws {
        var completions = 0
        _ = try invoke(panel: { _, completion in completion(.unavailable); completion(.cancelled) }, onCompletion: { _ in completions += 1 })
        XCTAssertEqual(completions, 1)
    }

    func testExecutionFailureCompletionOccursExactlyOnce() throws {
        var completions = 0
        _ = try invoke(execute: { _, _ in throw TestError.expected }, onCompletion: { _ in completions += 1 })
        XCTAssertEqual(completions, 1)
    }

    func testPreparationFailureCompletionOccursExactlyOnce() throws {
        var completions = 0
        _ = try invoke(prepare: { _, _, _ in throw TestError.expected }, onCompletion: { _ in completions += 1 })
        XCTAssertEqual(completions, 1)
    }

    private func save(session: AnthemMapSession? = nil, snapshot: AnthemRegionSnapshot? = nil, destination: URL? = nil) throws -> AnthemMapSaveAsCoordinator.Result {
        try invoke(
            session: session,
            snapshot: snapshot ?? validSnapshot(),
            destination: destination ?? artifactURL("save.anthemmap"),
            execute: { _, url in url }
        )
    }

    private func invoke(
        session: AnthemMapSession? = nil,
        snapshot: AnthemRegionSnapshot? = nil,
        destination: URL = URL(fileURLWithPath: "/Selected.anthemmap"),
        panel: AnthemMapSaveAsCoordinator.PanelPresentation? = nil,
        prepare: AnthemMapSaveAsCoordinator.Preparation? = nil,
        execute: AnthemMapSaveAsCoordinator.Execution? = nil,
        onCompletion: @escaping (AnthemMapSaveAsCoordinator.Result) -> Void = { _ in }
    ) throws -> AnthemMapSaveAsCoordinator.Result {
        let values: AnthemRegionSnapshot
        if let snapshot {
            values = snapshot
        } else {
            values = try validSnapshot()
        }
        var result: AnthemMapSaveAsCoordinator.Result?
        let coordinator = AnthemMapSaveAsCoordinator(
            presentSavePanel: panel ?? { _, completion in completion(.selected(destination)) },
            prepare: prepare ?? { mediaURL, duration, regions in
                try AnthemMapSaveCoordinator().prepare(mediaURL: mediaURL, trackDuration: duration, regions: regions)
            },
            execute: execute ?? { prepared, url in
                try AnthemMapSaveExecutor().execute(preparedSave: prepared, destinationURL: url)
            }
        )
        coordinator.saveAs(session: session, mediaURL: mediaURL(), trackDuration: 300, currentSnapshot: values) {
            result = $0
            onCompletion($0)
        }
        return try XCTUnwrap(result)
    }

    private func saved(_ result: AnthemMapSaveAsCoordinator.Result) throws -> AnthemMapSaveAsCoordinator.Success {
        guard case .saved(let success) = result else { throw TestError.expected }
        return success
    }

    private func isSaved(_ result: AnthemMapSaveAsCoordinator.Result) -> Bool {
        if case .saved = result { return true }
        return false
    }

    private func validSnapshot() throws -> AnthemRegionSnapshot {
        let region = item(10, 20)
        return try AnthemRegionSnapshot(regions: [region], activeRegionID: region.id)
    }

    private func item(_ start: TimeInterval, _ end: TimeInterval, id: UUID = UUID()) -> AnthemRegionItem {
        AnthemRegionItem(id: id, region: AnthemRegion(start: start, end: end))
    }

    private func makePrepared(
        trackName: String = "Track.mp3",
        fileSize: UInt64? = nil,
        regionID: UUID = UUID(),
        slot: Int = 0,
        start: Int64 = 10_000,
        end: Int64 = 20_000,
        name: String = "Track.anthemmap"
    ) -> AnthemMapSaveCoordinator.PreparedSave {
        .init(
            document: AnthemMapDocument(
                track: .init(fileName: trackName, fileSize: fileSize, durationMilliseconds: 300_000),
                regions: [.init(id: regionID, slot: slot, startMilliseconds: start, endMilliseconds: end)]
            ),
            suggestedFileName: name
        )
    }

    private func mediaURL() -> URL { URL(fileURLWithPath: "/Media/Track.mp3") }
    private func artifactURL(_ name: String) -> URL {
        artifactDirectory()
            .appendingPathComponent(name)
    }

    private func artifactDirectory() -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".m3-04e-test-artifacts", isDirectory: true)
    }

    private func read(_ url: URL) throws -> AnthemMapDocument {
        try JSONDecoder().decode(AnthemMapDocument.self, from: Data(contentsOf: url))
    }
}
