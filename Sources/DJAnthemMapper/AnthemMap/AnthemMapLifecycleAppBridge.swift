import Combine
import Foundation

@MainActor
final class AnthemMapLifecycleAppBridge: ObservableObject {
    enum TerminationDecision: Equatable {
        case terminateNow
        case terminateLater
        case terminateCancel
    }

    typealias CloseReplay = @MainActor () -> Void
    typealias TerminationReply = @MainActor (Bool) -> Void

    struct StateProvider {
        let session: @MainActor () -> AnthemMapSession?
        let currentSnapshot: @MainActor () -> AnthemRegionSnapshot?
        let hasUnsavedNewWorkspaceContent: @MainActor () -> Bool
        let mediaURL: @MainActor () -> URL?
        let trackDuration: @MainActor () -> TimeInterval
        let installReplacementSession: @MainActor (AnthemMapSession) -> Void
    }

    @Published private(set) var isResolutionRequested = false

    private enum ActiveOperation {
        case idle
        case awaitingClose(CloseReplay)
        case replayingClose
        case awaitingTermination(TerminationReply)
    }

    private let stateProvider: StateProvider
    private let protectionCoordinator: AnthemMapLifecycleProtectionCoordinator
    private var activeOperation: ActiveOperation = .idle
    private var isEvaluatingTermination = false
    private var isResolving = false

    init(
        stateProvider: StateProvider,
        protectionCoordinator: AnthemMapLifecycleProtectionCoordinator
    ) {
        self.stateProvider = stateProvider
        self.protectionCoordinator = protectionCoordinator
    }

    func shouldAllowClose(requestReplay: @escaping CloseReplay) -> Bool {
        if case .replayingClose = activeOperation {
            activeOperation = .idle
            return true
        }

        guard case .idle = activeOperation else {
            return false
        }

        activeOperation = .awaitingClose(requestReplay)
        let result = protectionCoordinator.requestLifecycleAction(
            session: stateProvider.session(),
            currentSnapshot: stateProvider.currentSnapshot(),
            hasUnsavedNewWorkspaceContent: stateProvider.hasUnsavedNewWorkspaceContent()
        ) { [weak self] in
            self?.releaseActiveOperation()
        }

        switch result {
        case .proceeded:
            return false
        case .requiresResolution:
            isResolutionRequested = true
            return false
        case .blocked:
            activeOperation = .idle
            return false
        }
    }

    func requestTermination(reply: @escaping TerminationReply) -> TerminationDecision {
        guard case .idle = activeOperation else {
            return .terminateCancel
        }

        activeOperation = .awaitingTermination(reply)
        isEvaluatingTermination = true
        let result = protectionCoordinator.requestLifecycleAction(
            session: stateProvider.session(),
            currentSnapshot: stateProvider.currentSnapshot(),
            hasUnsavedNewWorkspaceContent: stateProvider.hasUnsavedNewWorkspaceContent()
        ) { [weak self] in
            self?.releaseActiveOperation()
        }
        isEvaluatingTermination = false

        switch result {
        case .proceeded:
            activeOperation = .idle
            return .terminateNow
        case .requiresResolution:
            isResolutionRequested = true
            return .terminateLater
        case .blocked:
            activeOperation = .idle
            return .terminateCancel
        }
    }

    func resolvePendingLifecycleAction(
        choice: AnthemMapUnsavedChangeResolution.Choice?
    ) {
        guard isAwaitingResolution, !isResolving else {
            return
        }

        isResolutionRequested = false
        isResolving = true
        protectionCoordinator.resolvePendingLifecycleAction(
            choice: choice,
            session: stateProvider.session(),
            currentSnapshot: stateProvider.currentSnapshot(),
            mediaURL: stateProvider.mediaURL(),
            trackDuration: stateProvider.trackDuration()
        ) { [weak self] result in
            guard let self else {
                return
            }

            self.isResolving = false
            switch result {
            case .proceeded(let replacementSession):
                if let replacementSession {
                    self.stateProvider.installReplacementSession(replacementSession)
                }
            case .requiresResolution:
                self.isResolutionRequested = true
            case .blocked:
                self.cancelActiveOperation()
            }
        }
    }

    private var isAwaitingResolution: Bool {
        switch activeOperation {
        case .awaitingClose, .awaitingTermination:
            return true
        case .idle, .replayingClose:
            return false
        }
    }

    private func releaseActiveOperation() {
        switch activeOperation {
        case .awaitingClose(let requestReplay):
            activeOperation = .replayingClose
            requestReplay()
        case .awaitingTermination(let reply):
            guard !isEvaluatingTermination else {
                return
            }
            activeOperation = .idle
            reply(true)
        case .idle, .replayingClose:
            break
        }
    }

    private func cancelActiveOperation() {
        isResolutionRequested = false
        switch activeOperation {
        case .awaitingTermination(let reply):
            activeOperation = .idle
            reply(false)
        case .awaitingClose:
            activeOperation = .idle
        case .idle, .replayingClose:
            break
        }
    }
}
