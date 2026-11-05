import Foundation
import XCTest
@testable import DJAnthemMapper

@MainActor
final class AnthemMapOpenProtectionCoordinatorTests: XCTestCase {
    func testCleanExistingSessionProceedsOnceWithExactURLAndRetainsNoPendingRequest() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let selectedURL = mapURL("Clean.anthemmap")
        var received: [URL] = []
        let coordinator = makeCoordinator()

        let result = coordinator.requestOpen(
            mapURL: selectedURL,
            session: session(baseline: current),
            currentSnapshot: current,
            hasUnsavedNewWorkspaceContent: false
        ) { received.append($0) }

        XCTAssertEqual(result, .proceeded(nil))
        XCTAssertEqual(received, [selectedURL])
        XCTAssertEqual(
            coordinator.requestOpen(
                mapURL: mapURL("AfterImmediateProceed.anthemmap"),
                session: session(baseline: current),
                currentSnapshot: current,
                hasUnsavedNewWorkspaceContent: false
            ) { received.append($0) },
            .proceeded(nil)
        )
        XCTAssertEqual(received, [selectedURL, mapURL("AfterImmediateProceed.anthemmap")])
    }

    func testActiveSelectionOnlyAndExactRevertProceed() throws {
        let first = item(start: 10, end: 20)
        let second = item(start: 30, end: 40)
        let baseline = try snapshot(regions: [first, second], activeRegionID: first.id)
        let selectionOnly = try snapshot(regions: [first, second], activeRegionID: second.id)
        let singleBaseline = try snapshot(regions: [item(start: 10, end: 20)])
        var calls = 0

        XCTAssertEqual(
            makeCoordinator().requestOpen(
                mapURL: mapURL("Selection.anthemmap"),
                session: session(baseline: baseline),
                currentSnapshot: selectionOnly,
                hasUnsavedNewWorkspaceContent: false
            ) { _ in calls += 1 },
            .proceeded(nil)
        )
        XCTAssertEqual(
            makeCoordinator().requestOpen(
                mapURL: mapURL("Revert.anthemmap"),
                session: session(baseline: singleBaseline),
                currentSnapshot: singleBaseline,
                hasUnsavedNewWorkspaceContent: false
            ) { _ in calls += 1 },
            .proceeded(nil)
        )
        XCTAssertEqual(calls, 2)
    }

    func testDirtyContentRequiresResolutionWithoutOpenContinuation() throws {
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
            let result = makeCoordinator().requestOpen(
                mapURL: mapURL("Dirty.anthemmap"),
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
            makeCoordinator().requestOpen(
                mapURL: mapURL("New.anthemmap"),
                session: nil,
                currentSnapshot: current,
                hasUnsavedNewWorkspaceContent: true
            ) { _ in calls += 1 },
            .requiresResolution
        )
        XCTAssertEqual(
            makeCoordinator().requestOpen(
                mapURL: mapURL("Untouched.anthemmap"),
                session: nil,
                currentSnapshot: current,
                hasUnsavedNewWorkspaceContent: false
            ) { _ in calls += 1 },
            .proceeded(nil)
        )
        XCTAssertEqual(
            makeCoordinator().requestOpen(
                mapURL: mapURL("Unknown.anthemmap"),
                session: nil,
                currentSnapshot: nil,
                hasUnsavedNewWorkspaceContent: false
            ) { _ in calls += 1 },
            .requiresResolution
        )
        XCTAssertEqual(calls, 1)
    }

    func testSuccessfulSaveDeliversReplacementSessionBeforeOpenContinuation() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(start: 11, end: 20, id: baseline.regions[0].id)])
        let savedSession = session(baseline: current)
        let selectedURL = mapURL("Selected.anthemmap")
        var order: [String] = []
        var received: [URL] = []
        var observedSession: AnthemMapSession?
        let coordinator = makeCoordinator(existingSave: { _, _, _, _ in .success(.init(session: savedSession)) })

        requestDirtyOpen(
            coordinator: coordinator,
            mapURL: selectedURL,
            session: session(baseline: baseline),
            current: current
        ) {
            XCTAssertEqual(observedSession, savedSession)
            received.append($0)
            order.append("proceed")
        }
        coordinator.resolvePendingOpen(
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
        XCTAssertEqual(received, [selectedURL])
    }

    func testSaveExistingFailuresBlockAndClearPendingRequest() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(start: 11, end: 20, id: baseline.regions[0].id)])

        for failure in [
            AnthemMapExistingSaveCoordinator.Failure.preparationFailed,
            .executionFailed
        ] {
            var calls = 0
            let coordinator = makeCoordinator(existingSave: { _, _, _, _ in .failure(failure) })
            requestDirtyOpen(
                coordinator: coordinator,
                mapURL: mapURL("SaveFailure.anthemmap"),
                session: session(baseline: baseline),
                current: current
            ) { _ in calls += 1 }
            coordinator.resolvePendingOpen(
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
                coordinator.requestOpen(
                    mapURL: mapURL("AfterSaveFailure.anthemmap"),
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
        let coordinator = makeCoordinator(saveAs: spy.save)
        var calls = 0

        requestDirtyOpen(coordinator: coordinator, session: nil, current: current) { _ in calls += 1 }
        coordinator.resolvePendingOpen(
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

    func testSuccessfulSaveAsDeliversReplacementSessionBeforeOpenContinuation() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let savedSession = session(baseline: current)
        let selectedURL = mapURL("SaveAsSelected.anthemmap")
        let spy = SaveAsSpy()
        let coordinator = makeCoordinator(saveAs: spy.save)
        var order: [String] = []
        var observedSession: AnthemMapSession?
        var received: [URL] = []

        requestDirtyOpen(coordinator: coordinator, mapURL: selectedURL, session: nil, current: current) {
            XCTAssertEqual(observedSession, savedSession)
            received.append($0)
            order.append("proceed")
        }
        coordinator.resolvePendingOpen(
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
        XCTAssertEqual(received, [selectedURL])
    }

    func testSaveAsCancellationAndFailuresBlockOpen() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let outcomes: [AnthemMapSaveAsCoordinator.Result] = [
            .cancelled,
            .failed(.preparationFailed),
            .failed(.panelUnavailable),
            .failed(.executionFailed)
        ]

        for outcome in outcomes {
            let spy = SaveAsSpy()
            let coordinator = makeCoordinator(saveAs: spy.save)
            var calls = 0
            requestDirtyOpen(coordinator: coordinator, session: nil, current: current) { _ in calls += 1 }
            coordinator.resolvePendingOpen(
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
        let discardCoordinator = makeCoordinator(existingSave: { _, _, _, _ in
            saves += 1
            return .failure(.preparationFailed)
        })

        requestDirtyOpen(
            coordinator: discardCoordinator,
            session: session(baseline: baseline),
            current: current
        ) { _ in discardCalls += 1 }
        discardCoordinator.resolvePendingOpen(
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
            let coordinator = makeCoordinator()
            var calls = 0
            requestDirtyOpen(coordinator: coordinator, session: session(baseline: baseline), current: current) {
                _ in calls += 1
            }
            coordinator.resolvePendingOpen(
                choice: choice,
                session: session(baseline: baseline),
                currentSnapshot: current,
                mediaURL: mediaURL(),
                trackDuration: 300
            ) {
                XCTAssertEqual($0, .blocked)
            }
            XCTAssertEqual(calls, 0)
            XCTAssertEqual(
                coordinator.requestOpen(
                    mapURL: mapURL("AfterCancel.anthemmap"),
                    session: session(baseline: current),
                    currentSnapshot: current,
                    hasUnsavedNewWorkspaceContent: false
                ) { _ in calls += 1 },
                .proceeded(nil)
            )
        }
    }

    func testStaleSaveAsCallbackCannotOpenLaterMap() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let spy = SaveAsSpy()
        let coordinator = makeCoordinator(saveAs: spy.save)
        var firstCalls = 0
        var laterURLs: [URL] = []

        requestDirtyOpen(coordinator: coordinator, session: nil, current: current) { _ in firstCalls += 1 }
        coordinator.resolvePendingOpen(
            choice: .save,
            session: nil,
            currentSnapshot: current,
            mediaURL: mediaURL(),
            trackDuration: 300
        ) { _ in }
        spy.complete(.cancelled)

        let laterURL = mapURL("Later.anthemmap")
        XCTAssertEqual(
            coordinator.requestOpen(
                mapURL: laterURL,
                session: session(baseline: current),
                currentSnapshot: current,
                hasUnsavedNewWorkspaceContent: false
            ) { laterURLs.append($0) },
            .proceeded(nil)
        )
        spy.complete(.saved(.init(session: session(baseline: current))))

        XCTAssertEqual(firstCalls, 0)
        XCTAssertEqual(laterURLs, [laterURL])
    }

    func testSecondOpenRequestCannotReplacePendingUnresolvedRequest() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(start: 11, end: 20, id: baseline.regions[0].id)])
        let coordinator = makeCoordinator()
        let firstURL = mapURL("First.anthemmap")
        let secondURL = mapURL("Second.anthemmap")
        var firstReceived: [URL] = []
        var secondReceived: [URL] = []

        XCTAssertEqual(
            coordinator.requestOpen(
                mapURL: firstURL,
                session: session(baseline: baseline),
                currentSnapshot: current,
                hasUnsavedNewWorkspaceContent: false
            ) { firstReceived.append($0) },
            .requiresResolution
        )
        XCTAssertEqual(firstReceived, [])

        XCTAssertEqual(
            coordinator.requestOpen(
                mapURL: secondURL,
                session: session(baseline: baseline),
                currentSnapshot: current,
                hasUnsavedNewWorkspaceContent: false
            ) { secondReceived.append($0) },
            .blocked
        )
        XCTAssertEqual(firstReceived, [])
        XCTAssertEqual(secondReceived, [])

        coordinator.resolvePendingOpen(
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
        let thirdURL = mapURL("AfterResolution.anthemmap")
        XCTAssertEqual(
            coordinator.requestOpen(
                mapURL: thirdURL,
                session: session(baseline: current),
                currentSnapshot: current,
                hasUnsavedNewWorkspaceContent: false
            ) { secondReceived.append($0) },
            .proceeded(nil)
        )
        XCTAssertEqual(secondReceived, [thirdURL])
    }

    func testInputsAreNotMutated() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(start: 11, end: 20, id: baseline.regions[0].id)])
        let inputSession = session(baseline: baseline)
        let sessionBefore = inputSession
        let snapshotBefore = current
        let coordinator = makeCoordinator(existingSave: { _, _, _, _ in .failure(.preparationFailed) })

        requestDirtyOpen(coordinator: coordinator, session: inputSession, current: current) { _ in }
        coordinator.resolvePendingOpen(
            choice: .save,
            session: inputSession,
            currentSnapshot: current,
            mediaURL: mediaURL(),
            trackDuration: 300
        ) { _ in }

        XCTAssertEqual(inputSession, sessionBefore)
        XCTAssertEqual(current, snapshotBefore)
    }

    private func makeCoordinator(
        existingSave: @escaping AnthemMapOpenProtectionCoordinator.ExistingSaveOperation = { _, _, _, _ in
            .failure(.preparationFailed)
        },
        saveAs: @escaping AnthemMapOpenProtectionCoordinator.SaveAsOperation = { _, _, _, _, completion in
            completion(.failed(.preparationFailed))
        }
    ) -> AnthemMapOpenProtectionCoordinator {
        AnthemMapOpenProtectionCoordinator(existingSave: existingSave, saveAs: saveAs)
    }

    private func requestDirtyOpen(
        coordinator: AnthemMapOpenProtectionCoordinator,
        mapURL selectedMapURL: URL? = nil,
        session: AnthemMapSession?,
        current: AnthemRegionSnapshot,
        proceed: @escaping (URL) -> Void
    ) {
        let selectedMapURL = selectedMapURL ?? mapURL("Selected.anthemmap")
        XCTAssertEqual(
            coordinator.requestOpen(
                mapURL: selectedMapURL,
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

    private func mapURL(_ name: String) -> URL {
        URL(fileURLWithPath: "/Maps/\(name)")
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
