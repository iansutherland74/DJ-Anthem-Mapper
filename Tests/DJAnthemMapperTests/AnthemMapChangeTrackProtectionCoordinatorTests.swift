import Foundation
import XCTest
@testable import DJAnthemMapper

@MainActor
final class AnthemMapChangeTrackProtectionCoordinatorTests: XCTestCase {
    func testCleanExistingSessionProceedsOnceWithExactURL() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let replacement = replacementURL("Clean.mp3")
        var received: [URL] = []

        let result = coordinator().requestChange(
            replacementURL: replacement,
            session: session(baseline: current),
            currentSnapshot: current,
            hasUnsavedNewWorkspaceContent: false
        ) { received.append($0) }

        XCTAssertEqual(result, .proceeded(nil))
        XCTAssertEqual(received, [replacement])
    }

    func testActiveSelectionOnlyAndExactRevertProceed() throws {
        let first = item(start: 10, end: 20)
        let second = item(start: 30, end: 40)
        let baseline = try snapshot(regions: [first, second], activeRegionID: first.id)
        let selectionOnly = try snapshot(regions: [first, second], activeRegionID: second.id)
        let singleBaseline = try snapshot(regions: [item(start: 10, end: 20)])
        var calls = 0

        XCTAssertEqual(
            coordinator().requestChange(
                replacementURL: replacementURL("Selection.mp3"),
                session: session(baseline: baseline),
                currentSnapshot: selectionOnly,
                hasUnsavedNewWorkspaceContent: false
            ) { _ in calls += 1 },
            .proceeded(nil)
        )
        XCTAssertEqual(
            coordinator().requestChange(
                replacementURL: replacementURL("Revert.mp3"),
                session: session(baseline: singleBaseline),
                currentSnapshot: singleBaseline,
                hasUnsavedNewWorkspaceContent: false
            ) { _ in calls += 1 },
            .proceeded(nil)
        )
        XCTAssertEqual(calls, 2)
    }

    func testDirtyContentRequiresResolutionWithoutContinuation() throws {
        let first = item(start: 10, end: 20)
        let second = item(start: 30, end: 40)
        let cases = [
            (
                try snapshot(regions: [first]),
                try snapshot(regions: [item(start: 11, end: 20, id: first.id)])
            ),
            (
                try snapshot(regions: [first]),
                try snapshot(regions: [item(start: 10, end: 21, id: first.id)])
            ),
            (
                try snapshot(regions: [first]),
                try snapshot(regions: [first, second])
            ),
            (
                try snapshot(regions: [first, second]),
                try snapshot(regions: [first])
            )
        ]

        for (baseline, current) in cases {
            var calls = 0
            let result = coordinator().requestChange(
                replacementURL: replacementURL("Dirty.mp3"),
                session: session(baseline: baseline),
                currentSnapshot: current,
                hasUnsavedNewWorkspaceContent: false
            ) { _ in calls += 1 }
            XCTAssertEqual(result, .requiresResolution)
            XCTAssertEqual(calls, 0)
        }
    }

    func testNewWorkspaceAndUnavailableSnapshotUseDecisionGate() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        var calls = 0

        XCTAssertEqual(
            coordinator().requestChange(
                replacementURL: replacementURL("New.mp3"),
                session: nil,
                currentSnapshot: current,
                hasUnsavedNewWorkspaceContent: true
            ) { _ in calls += 1 },
            .requiresResolution
        )
        XCTAssertEqual(
            coordinator().requestChange(
                replacementURL: replacementURL("Untouched.mp3"),
                session: nil,
                currentSnapshot: current,
                hasUnsavedNewWorkspaceContent: false
            ) { _ in calls += 1 },
            .proceeded(nil)
        )
        XCTAssertEqual(
            coordinator().requestChange(
                replacementURL: replacementURL("Unknown.mp3"),
                session: nil,
                currentSnapshot: nil,
                hasUnsavedNewWorkspaceContent: false
            ) { _ in calls += 1 },
            .requiresResolution
        )
        XCTAssertEqual(calls, 1)
    }

    func testSuccessfulSaveDeliversReplacementSessionBeforeChangeTrackContinuation() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(start: 11, end: 20, id: baseline.regions[0].id)])
        let savedSession = session(baseline: current)
        var order: [String] = []
        var received: [URL] = []
        var observedSession: AnthemMapSession?
        let coordinator = coordinator(existingSave: { _, _, _, _ in .success(.init(session: savedSession)) })

        requestDirtyChange(coordinator: coordinator, session: session(baseline: baseline), current: current) {
            XCTAssertEqual(observedSession, savedSession)
            received.append($0)
            order.append("proceed")
        }
        coordinator.resolvePendingChange(
            choice: .save,
            session: session(baseline: baseline),
            currentSnapshot: current,
            mediaURL: mediaURL(),
            trackDuration: 300
        ) {
            XCTAssertEqual($0, .proceeded(savedSession))
            observedSession = savedSession
            order.append("completion")
        }

        XCTAssertEqual(order, ["completion", "proceed"])
        XCTAssertEqual(received, [replacementURL("Replacement.mp3")])
    }

    func testSaveExistingFailuresBlockAndClearPendingState() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(start: 11, end: 20, id: baseline.regions[0].id)])

        for failure in [
            AnthemMapExistingSaveCoordinator.Failure.preparationFailed,
            .executionFailed
        ] {
            var calls = 0
            let coordinator = coordinator(existingSave: { _, _, _, _ in .failure(failure) })
            requestDirtyChange(coordinator: coordinator, session: session(baseline: baseline), current: current) {
                _ in calls += 1
            }
            coordinator.resolvePendingChange(
                choice: .save,
                session: session(baseline: baseline),
                currentSnapshot: current,
                mediaURL: mediaURL(),
                trackDuration: 300
            ) {
                XCTAssertEqual($0, .blocked)
            }
            XCTAssertEqual(calls, 0)
            XCTAssertEqual(
                coordinator.requestChange(
                    replacementURL: replacementURL("AfterFailure.mp3"),
                    session: session(baseline: current),
                    currentSnapshot: current,
                    hasUnsavedNewWorkspaceContent: false
                ) { _ in calls += 1 },
                .proceeded(nil)
            )
        }
    }

    func testSaveAsSuccessProceedsOnceWithReturnedSession() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let savedSession = session(baseline: current)
        let spy = SaveAsSpy()
        let coordinator = coordinator(saveAs: spy.save)
        var calls = 0

        requestDirtyChange(coordinator: coordinator, session: nil, current: current) { _ in calls += 1 }
        coordinator.resolvePendingChange(
            choice: .save,
            session: nil,
            currentSnapshot: current,
            mediaURL: mediaURL(),
            trackDuration: 300
        ) {
            XCTAssertEqual($0, .proceeded(savedSession))
        }
        spy.complete(.saved(.init(session: savedSession)))
        spy.complete(.saved(.init(session: savedSession)))

        XCTAssertEqual(calls, 1)
    }

    func testSuccessfulSaveAsDeliversReplacementSessionBeforeChangeTrackContinuation() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let savedSession = session(baseline: current)
        let spy = SaveAsSpy()
        let coordinator = coordinator(saveAs: spy.save)
        var order: [String] = []
        var observedSession: AnthemMapSession?
        var received: [URL] = []

        requestDirtyChange(coordinator: coordinator, session: nil, current: current) {
            XCTAssertEqual(observedSession, savedSession)
            received.append($0)
            order.append("proceed")
        }
        coordinator.resolvePendingChange(
            choice: .save,
            session: nil,
            currentSnapshot: current,
            mediaURL: mediaURL(),
            trackDuration: 300
        ) {
            XCTAssertEqual($0, .proceeded(savedSession))
            observedSession = savedSession
            order.append("completion")
        }
        spy.complete(.saved(.init(session: savedSession)))

        XCTAssertEqual(order, ["completion", "proceed"])
        XCTAssertEqual(received, [replacementURL("Replacement.mp3")])
    }

    func testSaveAsCancellationAndFailuresBlock() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let outcomes: [AnthemMapSaveAsCoordinator.Result] = [
            .cancelled,
            .failed(.preparationFailed),
            .failed(.panelUnavailable),
            .failed(.executionFailed)
        ]

        for outcome in outcomes {
            let spy = SaveAsSpy()
            let coordinator = coordinator(saveAs: spy.save)
            var calls = 0
            requestDirtyChange(coordinator: coordinator, session: nil, current: current) { _ in calls += 1 }
            coordinator.resolvePendingChange(
                choice: .save,
                session: nil,
                currentSnapshot: current,
                mediaURL: mediaURL(),
                trackDuration: 300
            ) {
                XCTAssertEqual($0, .blocked)
            }
            spy.complete(outcome)
            XCTAssertEqual(calls, 0)
        }
    }

    func testDiscardProceedsWithoutSaveAndCancelAndNilBlock() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(start: 11, end: 20, id: baseline.regions[0].id)])
        var saves = 0
        var discardCalls = 0
        let discardCoordinator = coordinator(existingSave: { _, _, _, _ in
            saves += 1
            return .failure(.preparationFailed)
        })

        requestDirtyChange(
            coordinator: discardCoordinator,
            session: session(baseline: baseline),
            current: current
        ) { _ in discardCalls += 1 }
        discardCoordinator.resolvePendingChange(
            choice: .discard,
            session: session(baseline: baseline),
            currentSnapshot: current,
            mediaURL: mediaURL(),
            trackDuration: 300
        ) {
            XCTAssertEqual($0, .proceeded(nil))
        }
        XCTAssertEqual(saves, 0)
        XCTAssertEqual(discardCalls, 1)

        for choice: AnthemMapUnsavedChangeResolution.Choice? in [.cancel, nil] {
            let coordinator = coordinator()
            var calls = 0
            requestDirtyChange(coordinator: coordinator, session: session(baseline: baseline), current: current) {
                _ in calls += 1
            }
            coordinator.resolvePendingChange(
                choice: choice,
                session: session(baseline: baseline),
                currentSnapshot: current,
                mediaURL: mediaURL(),
                trackDuration: 300
            ) {
                XCTAssertEqual($0, .blocked)
            }
            XCTAssertEqual(calls, 0)
        }
    }

    func testStaleSaveAsCallbackCannotStartLaterRequest() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let spy = SaveAsSpy()
        let coordinator = coordinator(saveAs: spy.save)
        var firstCalls = 0
        var laterCalls = 0

        requestDirtyChange(coordinator: coordinator, session: nil, current: current) { _ in firstCalls += 1 }
        coordinator.resolvePendingChange(
            choice: .save,
            session: nil,
            currentSnapshot: current,
            mediaURL: mediaURL(),
            trackDuration: 300
        ) { _ in }
        spy.complete(.cancelled)

        XCTAssertEqual(
            coordinator.requestChange(
                replacementURL: replacementURL("Later.mp3"),
                session: session(baseline: current),
                currentSnapshot: current,
                hasUnsavedNewWorkspaceContent: false
            ) { _ in laterCalls += 1 },
            .proceeded(nil)
        )
        spy.complete(.saved(.init(session: session(baseline: current))))

        XCTAssertEqual(firstCalls, 0)
        XCTAssertEqual(laterCalls, 1)
    }

    func testSecondChangeTrackRequestCannotReplacePendingUnresolvedRequest() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(start: 11, end: 20, id: baseline.regions[0].id)])
        let coordinator = coordinator()
        let firstURL = replacementURL("First.mp3")
        let secondURL = replacementURL("Second.mp3")
        var firstReceived: [URL] = []
        var secondReceived: [URL] = []

        XCTAssertEqual(
            coordinator.requestChange(
                replacementURL: firstURL,
                session: session(baseline: baseline),
                currentSnapshot: current,
                hasUnsavedNewWorkspaceContent: false
            ) { firstReceived.append($0) },
            .requiresResolution
        )
        XCTAssertEqual(firstReceived, [])

        XCTAssertEqual(
            coordinator.requestChange(
                replacementURL: secondURL,
                session: session(baseline: baseline),
                currentSnapshot: current,
                hasUnsavedNewWorkspaceContent: false
            ) { secondReceived.append($0) },
            .blocked
        )
        XCTAssertEqual(firstReceived, [])
        XCTAssertEqual(secondReceived, [])

        coordinator.resolvePendingChange(
            choice: .discard,
            session: session(baseline: baseline),
            currentSnapshot: current,
            mediaURL: mediaURL(),
            trackDuration: 300
        ) {
            XCTAssertEqual($0, .proceeded(nil))
        }

        XCTAssertEqual(firstReceived, [firstURL])
        XCTAssertEqual(secondReceived, [])
        XCTAssertEqual(
            coordinator.requestChange(
                replacementURL: replacementURL("AfterResolution.mp3"),
                session: session(baseline: current),
                currentSnapshot: current,
                hasUnsavedNewWorkspaceContent: false
            ) { secondReceived.append($0) },
            .proceeded(nil)
        )
        XCTAssertEqual(secondReceived, [replacementURL("AfterResolution.mp3")])
    }

    func testInputsAreNotMutated() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(start: 11, end: 20, id: baseline.regions[0].id)])
        let inputSession = session(baseline: baseline)
        let sessionBefore = inputSession
        let snapshotBefore = current
        let coordinator = coordinator(existingSave: { _, _, _, _ in .failure(.preparationFailed) })

        requestDirtyChange(coordinator: coordinator, session: inputSession, current: current) { _ in }
        coordinator.resolvePendingChange(
            choice: .save,
            session: inputSession,
            currentSnapshot: current,
            mediaURL: mediaURL(),
            trackDuration: 300
        ) { _ in }

        XCTAssertEqual(inputSession, sessionBefore)
        XCTAssertEqual(current, snapshotBefore)
    }

    private func coordinator(
        existingSave: @escaping AnthemMapChangeTrackProtectionCoordinator.ExistingSaveOperation = { _, _, _, _ in
            .failure(.preparationFailed)
        },
        saveAs: @escaping AnthemMapChangeTrackProtectionCoordinator.SaveAsOperation = { _, _, _, _, completion in
            completion(.failed(.preparationFailed))
        }
    ) -> AnthemMapChangeTrackProtectionCoordinator {
        AnthemMapChangeTrackProtectionCoordinator(existingSave: existingSave, saveAs: saveAs)
    }

    private func requestDirtyChange(
        coordinator: AnthemMapChangeTrackProtectionCoordinator,
        session: AnthemMapSession?,
        current: AnthemRegionSnapshot,
        proceed: @escaping (URL) -> Void
    ) {
        XCTAssertEqual(
            coordinator.requestChange(
                replacementURL: replacementURL("Replacement.mp3"),
                session: session,
                currentSnapshot: current,
                hasUnsavedNewWorkspaceContent: session == nil
            ) { proceed($0) },
            .requiresResolution
        )
    }

    private func session(baseline: AnthemRegionSnapshot) -> AnthemMapSession {
        AnthemMapSession(mapURL: URL(fileURLWithPath: "/Maps/Set.anthemmap"), baseline: baseline)
    }

    private func snapshot(
        regions: [AnthemRegionItem],
        activeRegionID: UUID? = nil
    ) throws -> AnthemRegionSnapshot {
        try AnthemRegionSnapshot(regions: regions, activeRegionID: activeRegionID ?? regions[0].id)
    }

    private func item(
        start: TimeInterval?,
        end: TimeInterval?,
        id: UUID = UUID()
    ) -> AnthemRegionItem {
        AnthemRegionItem(id: id, region: AnthemRegion(start: start, end: end))
    }

    private func mediaURL() -> URL {
        URL(fileURLWithPath: "/Media/Current.mp3")
    }

    private func replacementURL(_ name: String) -> URL {
        URL(fileURLWithPath: "/Media/\(name)")
    }
}

@MainActor
private final class SaveAsSpy {
    private var completions: [@MainActor (AnthemMapSaveAsCoordinator.Result) -> Void] = []

    func save(
        _: AnthemMapSession?,
        _: URL,
        _: TimeInterval,
        _: AnthemRegionSnapshot,
        completion: @escaping @MainActor (AnthemMapSaveAsCoordinator.Result) -> Void
    ) {
        completions.append(completion)
    }

    func complete(_ result: AnthemMapSaveAsCoordinator.Result) {
        completions.last?(result)
    }
}
