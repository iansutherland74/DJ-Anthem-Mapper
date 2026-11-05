import Foundation
import XCTest
@testable import DJAnthemMapper

@MainActor
final class AnthemMapLifecycleProtectionCoordinatorTests: XCTestCase {
    func testCleanRequestContinuesImmediatelyOnce() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        var calls = 0

        let result = coordinator().requestLifecycleAction(
            session: session(baseline: current),
            currentSnapshot: current,
            hasUnsavedNewWorkspaceContent: false
        ) {
            calls += 1
        }

        XCTAssertEqual(result, .proceeded(nil))
        XCTAssertEqual(calls, 1)
    }

    func testDirtyExistingSessionRequiresResolutionWithoutContinuation() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(start: 11, end: 20, id: baseline.regions[0].id)])
        var calls = 0

        let result = coordinator().requestLifecycleAction(
            session: session(baseline: baseline),
            currentSnapshot: current,
            hasUnsavedNewWorkspaceContent: false
        ) {
            calls += 1
        }

        XCTAssertEqual(result, .requiresResolution)
        XCTAssertEqual(calls, 0)
    }

    func testDirtyNewWorkspaceRequiresResolutionWithoutContinuation() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        var calls = 0

        let result = coordinator().requestLifecycleAction(
            session: nil,
            currentSnapshot: current,
            hasUnsavedNewWorkspaceContent: true
        ) {
            calls += 1
        }

        XCTAssertEqual(result, .requiresResolution)
        XCTAssertEqual(calls, 0)
    }

    func testSecondPendingRequestIsBlockedAndPreservesFirst() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(start: 11, end: 20, id: baseline.regions[0].id)])
        let lifecycleCoordinator = coordinator()
        var firstCalls = 0
        var secondCalls = 0

        requestDirty(
            coordinator: lifecycleCoordinator,
            session: session(baseline: baseline),
            current: current
        ) {
            firstCalls += 1
        }

        XCTAssertEqual(
            lifecycleCoordinator.requestLifecycleAction(
                session: session(baseline: baseline),
                currentSnapshot: current,
                hasUnsavedNewWorkspaceContent: false
            ) {
                secondCalls += 1
            },
            .blocked
        )

        resolveDiscard(
            coordinator: lifecycleCoordinator,
            session: session(baseline: baseline),
            current: current
        )

        XCTAssertEqual(firstCalls, 1)
        XCTAssertEqual(secondCalls, 0)
    }

    func testCancelClearsPendingWithoutContinuation() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let lifecycleCoordinator = coordinator()
        var calls = 0

        requestDirty(coordinator: lifecycleCoordinator, session: nil, current: current) {
            calls += 1
        }
        lifecycleCoordinator.resolvePendingLifecycleAction(
            choice: .cancel,
            session: nil,
            currentSnapshot: current,
            mediaURL: mediaURL(),
            trackDuration: 300
        ) {
            XCTAssertEqual($0, .blocked)
        }

        XCTAssertEqual(calls, 0)
    }

    func testNilChoiceClearsPendingWithoutContinuation() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let lifecycleCoordinator = coordinator()
        var calls = 0

        requestDirty(coordinator: lifecycleCoordinator, session: nil, current: current) {
            calls += 1
        }
        lifecycleCoordinator.resolvePendingLifecycleAction(
            choice: nil,
            session: nil,
            currentSnapshot: current,
            mediaURL: mediaURL(),
            trackDuration: 300
        ) {
            XCTAssertEqual($0, .blocked)
        }

        XCTAssertEqual(calls, 0)
    }

    func testDiscardContinuesOnceWithoutSave() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(start: 11, end: 20, id: baseline.regions[0].id)])
        var saveCalls = 0
        var lifecycleCalls = 0
        let lifecycleCoordinator = coordinator(existingSave: { _, _, _, _ in
            saveCalls += 1
            return .failure(.preparationFailed)
        })

        requestDirty(
            coordinator: lifecycleCoordinator,
            session: session(baseline: baseline),
            current: current
        ) {
            lifecycleCalls += 1
        }
        resolveDiscard(
            coordinator: lifecycleCoordinator,
            session: session(baseline: baseline),
            current: current
        )

        XCTAssertEqual(saveCalls, 0)
        XCTAssertEqual(lifecycleCalls, 1)
    }

    func testExistingSaveSuccessExposesReplacementSessionBeforeContinuation() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(start: 11, end: 20, id: baseline.regions[0].id)])
        let savedSession = session(baseline: current)
        var order: [String] = []
        var observedSession: AnthemMapSession?
        let lifecycleCoordinator = coordinator(existingSave: { _, _, _, _ in
            .success(.init(session: savedSession))
        })

        requestDirty(
            coordinator: lifecycleCoordinator,
            session: session(baseline: baseline),
            current: current
        ) {
            XCTAssertEqual(observedSession, savedSession)
            order.append("proceed")
        }
        lifecycleCoordinator.resolvePendingLifecycleAction(
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
    }

    func testExistingSaveFailureBlocksContinuation() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(start: 11, end: 20, id: baseline.regions[0].id)])
        let lifecycleCoordinator = coordinator(existingSave: { _, _, _, _ in
            .failure(.executionFailed)
        })
        var calls = 0

        requestDirty(
            coordinator: lifecycleCoordinator,
            session: session(baseline: baseline),
            current: current
        ) {
            calls += 1
        }
        lifecycleCoordinator.resolvePendingLifecycleAction(
            choice: .save,
            session: session(baseline: baseline),
            currentSnapshot: current,
            mediaURL: mediaURL(),
            trackDuration: 300
        ) {
            XCTAssertEqual($0, .blocked)
        }

        XCTAssertEqual(calls, 0)
    }

    func testSaveAsSuccessExposesReplacementSessionBeforeContinuation() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let savedSession = session(baseline: current)
        let saveAsSpy = SaveAsSpy()
        var order: [String] = []
        var observedSession: AnthemMapSession?
        let lifecycleCoordinator = coordinator(saveAs: saveAsSpy.save)

        requestDirty(coordinator: lifecycleCoordinator, session: nil, current: current) {
            XCTAssertEqual(observedSession, savedSession)
            order.append("proceed")
        }
        lifecycleCoordinator.resolvePendingLifecycleAction(
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
        saveAsSpy.complete(.saved(.init(session: savedSession)), at: 0)

        XCTAssertEqual(order, ["completion", "proceed"])
    }

    func testSaveAsCancellationBlocksContinuation() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let saveAsSpy = SaveAsSpy()
        let lifecycleCoordinator = coordinator(saveAs: saveAsSpy.save)
        var calls = 0

        requestDirty(coordinator: lifecycleCoordinator, session: nil, current: current) {
            calls += 1
        }
        lifecycleCoordinator.resolvePendingLifecycleAction(
            choice: .save,
            session: nil,
            currentSnapshot: current,
            mediaURL: mediaURL(),
            trackDuration: 300
        ) {
            XCTAssertEqual($0, .blocked)
        }
        saveAsSpy.complete(.cancelled, at: 0)

        XCTAssertEqual(calls, 0)
    }

    func testSaveAsFailuresBlockContinuation() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let outcomes: [AnthemMapSaveAsCoordinator.Result] = [
            .failed(.preparationFailed),
            .failed(.panelUnavailable),
            .failed(.executionFailed)
        ]

        for outcome in outcomes {
            let saveAsSpy = SaveAsSpy()
            let lifecycleCoordinator = coordinator(saveAs: saveAsSpy.save)
            var calls = 0

            requestDirty(coordinator: lifecycleCoordinator, session: nil, current: current) {
                calls += 1
            }
            lifecycleCoordinator.resolvePendingLifecycleAction(
                choice: .save,
                session: nil,
                currentSnapshot: current,
                mediaURL: mediaURL(),
                trackDuration: 300
            ) {
                XCTAssertEqual($0, .blocked)
            }
            saveAsSpy.complete(outcome, at: 0)

            XCTAssertEqual(calls, 0)
        }
    }

    func testUnavailableSnapshotBlocksSaveConservatively() throws {
        let lifecycleCoordinator = coordinator()
        var calls = 0

        XCTAssertEqual(
            lifecycleCoordinator.requestLifecycleAction(
                session: nil,
                currentSnapshot: nil,
                hasUnsavedNewWorkspaceContent: false
            ) {
                calls += 1
            },
            .requiresResolution
        )
        lifecycleCoordinator.resolvePendingLifecycleAction(
            choice: .save,
            session: nil,
            currentSnapshot: nil,
            mediaURL: mediaURL(),
            trackDuration: 300
        ) {
            XCTAssertEqual($0, .blocked)
        }

        XCTAssertEqual(calls, 0)
    }

    func testUnavailableMediaBlocksSaveConservatively() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let lifecycleCoordinator = coordinator()
        var calls = 0

        requestDirty(coordinator: lifecycleCoordinator, session: nil, current: current) {
            calls += 1
        }
        lifecycleCoordinator.resolvePendingLifecycleAction(
            choice: .save,
            session: nil,
            currentSnapshot: current,
            mediaURL: nil,
            trackDuration: 300
        ) {
            XCTAssertEqual($0, .blocked)
        }

        XCTAssertEqual(calls, 0)
    }

    func testStaleSaveAsCallbackCannotReleaseLaterRequest() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let savedSession = session(baseline: current)
        let saveAsSpy = SaveAsSpy()
        let lifecycleCoordinator = coordinator(saveAs: saveAsSpy.save)
        var firstCalls = 0
        var laterCalls = 0

        requestDirty(coordinator: lifecycleCoordinator, session: nil, current: current) {
            firstCalls += 1
        }
        lifecycleCoordinator.resolvePendingLifecycleAction(
            choice: .save,
            session: nil,
            currentSnapshot: current,
            mediaURL: mediaURL(),
            trackDuration: 300
        ) { _ in }
        saveAsSpy.complete(.cancelled, at: 0)

        XCTAssertEqual(
            lifecycleCoordinator.requestLifecycleAction(
                session: session(baseline: current),
                currentSnapshot: current,
                hasUnsavedNewWorkspaceContent: false
            ) {
                laterCalls += 1
            },
            .proceeded(nil)
        )
        saveAsSpy.complete(.saved(.init(session: savedSession)), at: 0)

        XCTAssertEqual(firstCalls, 0)
        XCTAssertEqual(laterCalls, 1)
    }

    func testDuplicateSaveAsCallbackContinuesExactlyOnce() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let savedSession = session(baseline: current)
        let saveAsSpy = SaveAsSpy()
        let lifecycleCoordinator = coordinator(saveAs: saveAsSpy.save)
        var calls = 0

        requestDirty(coordinator: lifecycleCoordinator, session: nil, current: current) {
            calls += 1
        }
        lifecycleCoordinator.resolvePendingLifecycleAction(
            choice: .save,
            session: nil,
            currentSnapshot: current,
            mediaURL: mediaURL(),
            trackDuration: 300
        ) { _ in }
        saveAsSpy.complete(.saved(.init(session: savedSession)), at: 0)
        saveAsSpy.complete(.saved(.init(session: savedSession)), at: 0)

        XCTAssertEqual(calls, 1)
    }

    func testLaterRequestProceedsAfterCancel() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let lifecycleCoordinator = coordinator()
        var calls = 0

        requestDirty(coordinator: lifecycleCoordinator, session: nil, current: current) {
            calls += 1
        }
        lifecycleCoordinator.resolvePendingLifecycleAction(
            choice: .cancel,
            session: nil,
            currentSnapshot: current,
            mediaURL: mediaURL(),
            trackDuration: 300
        ) { _ in }

        XCTAssertEqual(
            lifecycleCoordinator.requestLifecycleAction(
                session: nil,
                currentSnapshot: current,
                hasUnsavedNewWorkspaceContent: false
            ) {
                calls += 1
            },
            .proceeded(nil)
        )
        XCTAssertEqual(calls, 1)
    }

    func testLaterRequestsProceedAfterDiscardAndSaveWithoutMutatingInputs() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(start: 11, end: 20, id: baseline.regions[0].id)])
        let inputSession = session(baseline: baseline)
        let savedSession = session(baseline: current)
        let sessionBefore = inputSession
        let snapshotBefore = current
        let lifecycleCoordinator = coordinator(existingSave: { _, _, _, _ in
            .success(.init(session: savedSession))
        })
        var calls = 0

        requestDirty(
            coordinator: lifecycleCoordinator,
            session: inputSession,
            current: current
        ) {
            calls += 1
        }
        resolveDiscard(
            coordinator: lifecycleCoordinator,
            session: inputSession,
            current: current
        )
        XCTAssertEqual(
            lifecycleCoordinator.requestLifecycleAction(
                session: inputSession,
                currentSnapshot: current,
                hasUnsavedNewWorkspaceContent: false
            ) {
                calls += 1
            },
            .requiresResolution
        )
        lifecycleCoordinator.resolvePendingLifecycleAction(
            choice: .save,
            session: inputSession,
            currentSnapshot: current,
            mediaURL: mediaURL(),
            trackDuration: 300
        ) {
            XCTAssertEqual($0, .proceeded(savedSession))
        }

        XCTAssertEqual(calls, 2)
        XCTAssertEqual(inputSession, sessionBefore)
        XCTAssertEqual(current, snapshotBefore)
    }

    private func coordinator(
        existingSave: @escaping AnthemMapLifecycleProtectionCoordinator.ExistingSaveOperation = { _, _, _, _ in
            .failure(.preparationFailed)
        },
        saveAs: @escaping AnthemMapLifecycleProtectionCoordinator.SaveAsOperation = { _, _, _, _, completion in
            completion(.failed(.preparationFailed))
        }
    ) -> AnthemMapLifecycleProtectionCoordinator {
        AnthemMapLifecycleProtectionCoordinator(existingSave: existingSave, saveAs: saveAs)
    }

    private func requestDirty(
        coordinator: AnthemMapLifecycleProtectionCoordinator,
        session: AnthemMapSession?,
        current: AnthemRegionSnapshot,
        proceed: @escaping () -> Void
    ) {
        XCTAssertEqual(
            coordinator.requestLifecycleAction(
                session: session,
                currentSnapshot: current,
                hasUnsavedNewWorkspaceContent: session == nil
            ) {
                proceed()
            },
            .requiresResolution
        )
    }

    private func resolveDiscard(
        coordinator: AnthemMapLifecycleProtectionCoordinator,
        session: AnthemMapSession?,
        current: AnthemRegionSnapshot
    ) {
        coordinator.resolvePendingLifecycleAction(
            choice: .discard,
            session: session,
            currentSnapshot: current,
            mediaURL: mediaURL(),
            trackDuration: 300
        ) {
            XCTAssertEqual($0, .proceeded(nil))
        }
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

    func complete(_ result: AnthemMapSaveAsCoordinator.Result, at index: Int) {
        completions[index](result)
    }
}
