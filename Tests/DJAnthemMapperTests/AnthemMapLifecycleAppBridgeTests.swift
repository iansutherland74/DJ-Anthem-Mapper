import Foundation
import XCTest
@testable import DJAnthemMapper

@MainActor
final class AnthemMapLifecycleAppBridgeTests: XCTestCase {
    func testCleanCloseRequestsOneAuthorisedReplay() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let provider = ProviderSpy(session: session(baseline: current), snapshot: current)
        let bridge = makeBridge(provider: provider)
        var replayCalls = 0

        let initialDecision = bridge.shouldAllowClose {
            replayCalls += 1
            XCTAssertTrue(bridge.shouldAllowClose { XCTFail("replay must not recurse") })
        }

        XCTAssertFalse(initialDecision)
        XCTAssertEqual(replayCalls, 1)
    }

    func testDirtyCloseDefersAndRequestsResolution() throws {
        let provider = try dirtyExistingProvider()
        let bridge = makeBridge(provider: provider)
        var replayCalls = 0

        XCTAssertFalse(bridge.shouldAllowClose { replayCalls += 1 })
        XCTAssertTrue(bridge.isResolutionRequested)
        XCTAssertEqual(replayCalls, 0)
    }

    func testCleanQuitPermitsImmediatelyWithoutReply() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let provider = ProviderSpy(session: session(baseline: current), snapshot: current)
        let bridge = makeBridge(provider: provider)
        var replies: [Bool] = []

        XCTAssertEqual(bridge.requestTermination { replies.append($0) }, .terminateNow)
        XCTAssertEqual(replies, [])
    }

    func testDirtyQuitDefersAndRequestsResolution() throws {
        let provider = try dirtyExistingProvider()
        let bridge = makeBridge(provider: provider)
        var replies: [Bool] = []

        XCTAssertEqual(bridge.requestTermination { replies.append($0) }, .terminateLater)
        XCTAssertTrue(bridge.isResolutionRequested)
        XCTAssertEqual(replies, [])
    }

    func testSaveThenCloseReplaysAfterReplacementSessionInstallation() throws {
        let provider = try dirtyExistingProvider()
        let savedSession = try savedSession(for: provider)
        var order: [String] = []
        provider.onInstall = { _ in order.append("install") }
        let bridge = makeBridge(
            provider: provider,
            existingSave: { _, _, _, _ in .success(.init(session: savedSession)) }
        )

        XCTAssertFalse(bridge.shouldAllowClose {
            order.append("replay")
            XCTAssertTrue(bridge.shouldAllowClose { XCTFail("replay must not recurse") })
        })
        bridge.resolvePendingLifecycleAction(choice: .save)

        XCTAssertEqual(order, ["install", "replay"])
    }

    func testSaveThenQuitRepliesAfterReplacementSessionInstallation() throws {
        let provider = try dirtyExistingProvider()
        let savedSession = try savedSession(for: provider)
        var order: [String] = []
        provider.onInstall = { _ in order.append("install") }
        let bridge = makeBridge(
            provider: provider,
            existingSave: { _, _, _, _ in .success(.init(session: savedSession)) }
        )

        XCTAssertEqual(
            bridge.requestTermination {
                XCTAssertEqual(order, ["install"])
                order.append($0 ? "reply-true" : "reply-false")
            },
            .terminateLater
        )
        bridge.resolvePendingLifecycleAction(choice: .save)

        XCTAssertEqual(order, ["install", "reply-true"])
    }

    func testDiscardThenCloseReplaysOnce() throws {
        let provider = try dirtyExistingProvider()
        let bridge = makeBridge(provider: provider)
        var replayCalls = 0

        XCTAssertFalse(bridge.shouldAllowClose {
            replayCalls += 1
            XCTAssertTrue(bridge.shouldAllowClose { XCTFail("replay must not recurse") })
        })
        bridge.resolvePendingLifecycleAction(choice: .discard)

        XCTAssertEqual(replayCalls, 1)
    }

    func testDiscardThenQuitRepliesTrueOnce() throws {
        let provider = try dirtyExistingProvider()
        let bridge = makeBridge(provider: provider)
        var replies: [Bool] = []

        XCTAssertEqual(bridge.requestTermination { replies.append($0) }, .terminateLater)
        bridge.resolvePendingLifecycleAction(choice: .discard)

        XCTAssertEqual(replies, [true])
    }

    func testCancelCloseLeavesHostBlocked() throws {
        let provider = try dirtyExistingProvider()
        let bridge = makeBridge(provider: provider)
        var replayCalls = 0

        XCTAssertFalse(bridge.shouldAllowClose { replayCalls += 1 })
        bridge.resolvePendingLifecycleAction(choice: .cancel)

        XCTAssertFalse(bridge.isResolutionRequested)
        XCTAssertEqual(replayCalls, 0)
    }

    func testCancelQuitRepliesFalseOnce() throws {
        let provider = try dirtyExistingProvider()
        let bridge = makeBridge(provider: provider)
        var replies: [Bool] = []

        XCTAssertEqual(bridge.requestTermination { replies.append($0) }, .terminateLater)
        bridge.resolvePendingLifecycleAction(choice: .cancel)

        XCTAssertEqual(replies, [false])
    }

    func testExistingSaveFailureBlocksClose() throws {
        let provider = try dirtyExistingProvider()
        let bridge = makeBridge(
            provider: provider,
            existingSave: { _, _, _, _ in .failure(.executionFailed) }
        )
        var replayCalls = 0

        XCTAssertFalse(bridge.shouldAllowClose { replayCalls += 1 })
        bridge.resolvePendingLifecycleAction(choice: .save)

        XCTAssertEqual(replayCalls, 0)
        XCTAssertFalse(bridge.isResolutionRequested)
    }

    func testExistingSaveFailureRepliesFalseForQuit() throws {
        let provider = try dirtyExistingProvider()
        let bridge = makeBridge(
            provider: provider,
            existingSave: { _, _, _, _ in .failure(.executionFailed) }
        )
        var replies: [Bool] = []

        XCTAssertEqual(bridge.requestTermination { replies.append($0) }, .terminateLater)
        bridge.resolvePendingLifecycleAction(choice: .save)

        XCTAssertEqual(replies, [false])
    }

    func testSaveAsCancellationOrFailureBlocksClose() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let outcomes: [AnthemMapSaveAsCoordinator.Result] = [
            .cancelled,
            .failed(.executionFailed)
        ]

        for outcome in outcomes {
            let provider = ProviderSpy(session: nil, snapshot: current, hasUnsavedNewWorkspaceContent: true)
            let saveAsSpy = SaveAsSpy()
            let bridge = makeBridge(provider: provider, saveAs: saveAsSpy.save)
            var replayCalls = 0

            XCTAssertFalse(bridge.shouldAllowClose { replayCalls += 1 })
            bridge.resolvePendingLifecycleAction(choice: .save)
            saveAsSpy.complete(outcome, at: 0)

            XCTAssertEqual(replayCalls, 0)
            XCTAssertFalse(bridge.isResolutionRequested)
        }
    }

    func testSaveAsCancellationOrFailureRepliesFalseForQuit() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let outcomes: [AnthemMapSaveAsCoordinator.Result] = [
            .cancelled,
            .failed(.executionFailed)
        ]

        for outcome in outcomes {
            let provider = ProviderSpy(session: nil, snapshot: current, hasUnsavedNewWorkspaceContent: true)
            let saveAsSpy = SaveAsSpy()
            let bridge = makeBridge(provider: provider, saveAs: saveAsSpy.save)
            var replies: [Bool] = []

            XCTAssertEqual(bridge.requestTermination { replies.append($0) }, .terminateLater)
            bridge.resolvePendingLifecycleAction(choice: .save)
            saveAsSpy.complete(outcome, at: 0)

            XCTAssertEqual(replies, [false])
        }
    }

    func testDuplicateCloseDoesNotReplacePendingClose() throws {
        let provider = try dirtyExistingProvider()
        let bridge = makeBridge(provider: provider)
        var firstReplayCalls = 0
        var secondReplayCalls = 0

        XCTAssertFalse(bridge.shouldAllowClose { firstReplayCalls += 1 })
        XCTAssertFalse(bridge.shouldAllowClose { secondReplayCalls += 1 })
        bridge.resolvePendingLifecycleAction(choice: .discard)

        XCTAssertEqual(firstReplayCalls, 1)
        XCTAssertEqual(secondReplayCalls, 0)
    }

    func testDuplicateQuitDoesNotCreateSecondTerminationObligation() throws {
        let provider = try dirtyExistingProvider()
        let bridge = makeBridge(provider: provider)
        var firstReplies: [Bool] = []
        var secondReplies: [Bool] = []

        XCTAssertEqual(bridge.requestTermination { firstReplies.append($0) }, .terminateLater)
        XCTAssertEqual(bridge.requestTermination { secondReplies.append($0) }, .terminateCancel)
        bridge.resolvePendingLifecycleAction(choice: .cancel)

        XCTAssertEqual(firstReplies, [false])
        XCTAssertEqual(secondReplies, [])
    }

    func testClosePendingThenQuitIsRejectedWithoutDisturbingClose() throws {
        let provider = try dirtyExistingProvider()
        let bridge = makeBridge(provider: provider)
        var replayCalls = 0
        var replies: [Bool] = []

        XCTAssertFalse(bridge.shouldAllowClose {
            replayCalls += 1
            XCTAssertTrue(bridge.shouldAllowClose { XCTFail("replay must not recurse") })
        })
        XCTAssertEqual(bridge.requestTermination { replies.append($0) }, .terminateCancel)
        bridge.resolvePendingLifecycleAction(choice: .discard)

        XCTAssertEqual(replayCalls, 1)
        XCTAssertEqual(replies, [])
    }

    func testQuitPendingThenCloseIsRejectedWithoutDisturbingQuit() throws {
        let provider = try dirtyExistingProvider()
        let bridge = makeBridge(provider: provider)
        var replies: [Bool] = []
        var replayCalls = 0

        XCTAssertEqual(bridge.requestTermination { replies.append($0) }, .terminateLater)
        XCTAssertFalse(bridge.shouldAllowClose { replayCalls += 1 })
        bridge.resolvePendingLifecycleAction(choice: .cancel)

        XCTAssertEqual(replies, [false])
        XCTAssertEqual(replayCalls, 0)
    }

    func testAuthorisedCloseReplayIsConsumedBeforeNextCloseRequest() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let provider = ProviderSpy(session: session(baseline: current), snapshot: current)
        let bridge = makeBridge(provider: provider)
        var replayCalls = 0

        XCTAssertFalse(bridge.shouldAllowClose {
            replayCalls += 1
            XCTAssertTrue(bridge.shouldAllowClose { XCTFail("replay must not recurse") })
        })
        XCTAssertFalse(bridge.shouldAllowClose {
            replayCalls += 1
            XCTAssertTrue(bridge.shouldAllowClose { XCTFail("replay must not recurse") })
        })

        XCTAssertEqual(replayCalls, 2)
    }

    func testStaleLifecycleSaveAsCallbackCannotReleaseLaterClose() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let provider = ProviderSpy(session: nil, snapshot: current, hasUnsavedNewWorkspaceContent: true)
        let savedSession = session(baseline: current)
        let saveAsSpy = SaveAsSpy()
        let bridge = makeBridge(provider: provider, saveAs: saveAsSpy.save)
        var firstReplayCalls = 0
        var laterReplayCalls = 0

        XCTAssertFalse(bridge.shouldAllowClose { firstReplayCalls += 1 })
        bridge.resolvePendingLifecycleAction(choice: .save)
        saveAsSpy.complete(.cancelled, at: 0)

        provider.sessionValue = session(baseline: current)
        provider.hasUnsavedNewWorkspaceContentValue = false
        XCTAssertFalse(bridge.shouldAllowClose {
            laterReplayCalls += 1
            XCTAssertTrue(bridge.shouldAllowClose { XCTFail("replay must not recurse") })
        })
        saveAsSpy.complete(.saved(.init(session: savedSession)), at: 0)

        XCTAssertEqual(firstReplayCalls, 0)
        XCTAssertEqual(laterReplayCalls, 1)
    }

    func testReplacementSessionPrecedesCloseHostContinuation() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let savedSession = session(baseline: current)
        let provider = ProviderSpy(session: nil, snapshot: current, hasUnsavedNewWorkspaceContent: true)
        let saveAsSpy = SaveAsSpy()
        var installedSession: AnthemMapSession?
        provider.onInstall = { installedSession = $0 }
        let bridge = makeBridge(provider: provider, saveAs: saveAsSpy.save)

        XCTAssertFalse(bridge.shouldAllowClose {
            XCTAssertEqual(installedSession, savedSession)
            XCTAssertTrue(bridge.shouldAllowClose { XCTFail("replay must not recurse") })
        })
        bridge.resolvePendingLifecycleAction(choice: .save)
        saveAsSpy.complete(.saved(.init(session: savedSession)), at: 0)
    }

    func testReplacementSessionPrecedesTerminationHostContinuation() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let savedSession = session(baseline: current)
        let provider = ProviderSpy(session: nil, snapshot: current, hasUnsavedNewWorkspaceContent: true)
        let saveAsSpy = SaveAsSpy()
        var installedSession: AnthemMapSession?
        provider.onInstall = { installedSession = $0 }
        let bridge = makeBridge(provider: provider, saveAs: saveAsSpy.save)
        var replies: [Bool] = []

        XCTAssertEqual(
            bridge.requestTermination {
                XCTAssertEqual(installedSession, savedSession)
                replies.append($0)
            },
            .terminateLater
        )
        bridge.resolvePendingLifecycleAction(choice: .save)
        saveAsSpy.complete(.saved(.init(session: savedSession)), at: 0)

        XCTAssertEqual(replies, [true])
    }

    func testLaterIndependentCloseWorksAfterCancel() throws {
        let provider = try dirtyExistingProvider()
        let bridge = makeBridge(provider: provider)
        var replayCalls = 0

        XCTAssertFalse(bridge.shouldAllowClose { XCTFail("cancelled close must not replay") })
        bridge.resolvePendingLifecycleAction(choice: .cancel)

        provider.sessionValue = session(baseline: provider.snapshotValue)
        XCTAssertFalse(bridge.shouldAllowClose {
            replayCalls += 1
            XCTAssertTrue(bridge.shouldAllowClose { XCTFail("replay must not recurse") })
        })

        XCTAssertEqual(replayCalls, 1)
    }

    func testLaterIndependentQuitWorksAfterCancel() throws {
        let provider = try dirtyExistingProvider()
        let bridge = makeBridge(provider: provider)
        var firstReplies: [Bool] = []
        var laterReplies: [Bool] = []

        XCTAssertEqual(bridge.requestTermination { firstReplies.append($0) }, .terminateLater)
        bridge.resolvePendingLifecycleAction(choice: .cancel)

        provider.sessionValue = session(baseline: provider.snapshotValue)
        XCTAssertEqual(bridge.requestTermination { laterReplies.append($0) }, .terminateNow)

        XCTAssertEqual(firstReplies, [false])
        XCTAssertEqual(laterReplies, [])
    }

    private func makeBridge(
        provider: ProviderSpy,
        existingSave: @escaping AnthemMapLifecycleProtectionCoordinator.ExistingSaveOperation = { _, _, _, _ in
            .failure(.preparationFailed)
        },
        saveAs: @escaping AnthemMapLifecycleProtectionCoordinator.SaveAsOperation = { _, _, _, _, completion in
            completion(.failed(.preparationFailed))
        }
    ) -> AnthemMapLifecycleAppBridge {
        let lifecycleCoordinator = AnthemMapLifecycleProtectionCoordinator(
            existingSave: existingSave,
            saveAs: saveAs
        )
        return AnthemMapLifecycleAppBridge(
            stateProvider: provider.stateProvider,
            protectionCoordinator: lifecycleCoordinator
        )
    }

    private func dirtyExistingProvider() throws -> ProviderSpy {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(start: 11, end: 20, id: baseline.regions[0].id)])
        return ProviderSpy(session: session(baseline: baseline), snapshot: current)
    }

    private func savedSession(for provider: ProviderSpy) throws -> AnthemMapSession {
        AnthemMapSession(mapURL: URL(fileURLWithPath: "/Maps/Saved.anthemmap"), baseline: provider.snapshotValue)
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
}

@MainActor
private final class ProviderSpy {
    var sessionValue: AnthemMapSession?
    var snapshotValue: AnthemRegionSnapshot
    var hasUnsavedNewWorkspaceContentValue: Bool
    var mediaURLValue: URL?
    var trackDurationValue: TimeInterval
    var onInstall: ((AnthemMapSession) -> Void)?

    init(
        session: AnthemMapSession?,
        snapshot: AnthemRegionSnapshot,
        hasUnsavedNewWorkspaceContent: Bool = false,
        mediaURL: URL? = URL(fileURLWithPath: "/Media/Current.mp3"),
        trackDuration: TimeInterval = 300
    ) {
        sessionValue = session
        snapshotValue = snapshot
        hasUnsavedNewWorkspaceContentValue = hasUnsavedNewWorkspaceContent
        mediaURLValue = mediaURL
        trackDurationValue = trackDuration
    }

    var stateProvider: AnthemMapLifecycleAppBridge.StateProvider {
        AnthemMapLifecycleAppBridge.StateProvider(
            session: { self.sessionValue },
            currentSnapshot: { self.snapshotValue },
            hasUnsavedNewWorkspaceContent: { self.hasUnsavedNewWorkspaceContentValue },
            mediaURL: { self.mediaURLValue },
            trackDuration: { self.trackDurationValue },
            installReplacementSession: { session in
                self.sessionValue = session
                self.onInstall?(session)
            }
        )
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
