import Foundation

@MainActor
final class AnthemMapLifecycleProtectionCoordinator {
    enum RequestResult: Equatable {
        case proceeded(AnthemMapSession?)
        case requiresResolution
        case blocked
    }

    typealias LifecycleContinuation = @MainActor () -> Void
    typealias ExistingSaveOperation = @MainActor (
        AnthemMapSession,
        URL,
        TimeInterval,
        AnthemRegionSnapshot
    ) -> Result<AnthemMapExistingSaveCoordinator.Success, AnthemMapExistingSaveCoordinator.Failure>
    typealias SaveAsOperation = @MainActor (
        AnthemMapSession?,
        URL,
        TimeInterval,
        AnthemRegionSnapshot,
        @escaping @MainActor (AnthemMapSaveAsCoordinator.Result) -> Void
    ) -> Void
    typealias Completion = @MainActor (RequestResult) -> Void

    private struct PendingLifecycleAction {
        let id: UInt
        let proceed: LifecycleContinuation
        var isSaveInFlight = false
    }

    private let decision = AnthemMapUnsavedChangeDecision()
    private let resolution = AnthemMapUnsavedChangeResolution()
    private let saveExisting: ExistingSaveOperation
    private let saveAs: SaveAsOperation
    private var pendingLifecycleAction: PendingLifecycleAction?
    private var nextRequestID: UInt = 0

    init() {
        saveExisting = Self.defaultExistingSave
        saveAs = Self.defaultSaveAs
    }

    init(
        existingSave: @escaping ExistingSaveOperation,
        saveAs: @escaping SaveAsOperation
    ) {
        self.saveExisting = existingSave
        self.saveAs = saveAs
    }

    func requestLifecycleAction(
        session: AnthemMapSession?,
        currentSnapshot: AnthemRegionSnapshot?,
        hasUnsavedNewWorkspaceContent: Bool,
        proceed: @escaping LifecycleContinuation
    ) -> RequestResult {
        guard pendingLifecycleAction == nil else {
            return .blocked
        }

        switch decision.evaluate(
            session: session,
            currentSnapshot: currentSnapshot,
            hasUnsavedNewWorkspaceContent: hasUnsavedNewWorkspaceContent
        ) {
        case .proceed:
            proceed()
            return .proceeded(nil)
        case .requiresResolution:
            nextRequestID += 1
            pendingLifecycleAction = PendingLifecycleAction(
                id: nextRequestID,
                proceed: proceed
            )
            return .requiresResolution
        }
    }

    func resolvePendingLifecycleAction(
        choice: AnthemMapUnsavedChangeResolution.Choice?,
        session: AnthemMapSession?,
        currentSnapshot: AnthemRegionSnapshot?,
        mediaURL: URL?,
        trackDuration: TimeInterval,
        completion: @escaping Completion
    ) {
        guard let pendingLifecycleAction, !pendingLifecycleAction.isSaveInFlight else {
            completion(.blocked)
            return
        }

        switch resolution.resolve(choice) {
        case .discardAndProceed:
            proceedPendingLifecycleAction(
                id: pendingLifecycleAction.id,
                savedSession: nil,
                completion: completion
            )
        case .cancel:
            blockPendingLifecycleAction(
                id: pendingLifecycleAction.id,
                completion: completion
            )
        case .saveThenProceed:
            guard let currentSnapshot, let mediaURL else {
                blockPendingLifecycleAction(
                    id: pendingLifecycleAction.id,
                    completion: completion
                )
                return
            }

            if let session, session.hasAssociatedMap {
                switch saveExisting(session, mediaURL, trackDuration, currentSnapshot) {
                case .success(let success):
                    proceedPendingLifecycleAction(
                        id: pendingLifecycleAction.id,
                        savedSession: success.session,
                        completion: completion
                    )
                case .failure:
                    blockPendingLifecycleAction(
                        id: pendingLifecycleAction.id,
                        completion: completion
                    )
                }
                return
            }

            beginSaveAs(
                pendingLifecycleAction,
                session: session,
                mediaURL: mediaURL,
                trackDuration: trackDuration,
                currentSnapshot: currentSnapshot,
                completion: completion
            )
        }
    }

    private static func defaultExistingSave(
        session: AnthemMapSession,
        mediaURL: URL,
        trackDuration: TimeInterval,
        currentSnapshot: AnthemRegionSnapshot
    ) -> Result<AnthemMapExistingSaveCoordinator.Success, AnthemMapExistingSaveCoordinator.Failure> {
        AnthemMapExistingSaveCoordinator().save(
            session: session,
            mediaURL: mediaURL,
            trackDuration: trackDuration,
            currentSnapshot: currentSnapshot
        )
    }

    private static func defaultSaveAs(
        session: AnthemMapSession?,
        mediaURL: URL,
        trackDuration: TimeInterval,
        currentSnapshot: AnthemRegionSnapshot,
        completion: @escaping @MainActor (AnthemMapSaveAsCoordinator.Result) -> Void
    ) {
        AnthemMapSaveAsCoordinator().saveAs(
            session: session,
            mediaURL: mediaURL,
            trackDuration: trackDuration,
            currentSnapshot: currentSnapshot,
            completion: completion
        )
    }

    private func beginSaveAs(
        _ pendingLifecycleAction: PendingLifecycleAction,
        session: AnthemMapSession?,
        mediaURL: URL,
        trackDuration: TimeInterval,
        currentSnapshot: AnthemRegionSnapshot,
        completion: @escaping Completion
    ) {
        guard self.pendingLifecycleAction?.id == pendingLifecycleAction.id else {
            completion(.blocked)
            return
        }
        self.pendingLifecycleAction?.isSaveInFlight = true

        saveAs(session, mediaURL, trackDuration, currentSnapshot) { [weak self] result in
            guard let self, self.pendingLifecycleAction?.id == pendingLifecycleAction.id else {
                return
            }

            switch result {
            case .saved(let success):
                self.proceedPendingLifecycleAction(
                    id: pendingLifecycleAction.id,
                    savedSession: success.session,
                    completion: completion
                )
            case .cancelled, .failed:
                self.blockPendingLifecycleAction(
                    id: pendingLifecycleAction.id,
                    completion: completion
                )
            }
        }
    }

    private func proceedPendingLifecycleAction(
        id: UInt,
        savedSession: AnthemMapSession?,
        completion: @escaping Completion
    ) {
        guard let pendingLifecycleAction, pendingLifecycleAction.id == id else {
            return
        }
        self.pendingLifecycleAction = nil
        completion(.proceeded(savedSession))
        pendingLifecycleAction.proceed()
    }

    private func blockPendingLifecycleAction(
        id: UInt,
        completion: @escaping Completion
    ) {
        guard pendingLifecycleAction?.id == id else {
            return
        }
        pendingLifecycleAction = nil
        completion(.blocked)
    }
}
