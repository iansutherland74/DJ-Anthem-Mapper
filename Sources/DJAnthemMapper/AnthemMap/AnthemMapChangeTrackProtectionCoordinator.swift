import Foundation

@MainActor
final class AnthemMapChangeTrackProtectionCoordinator {
    enum RequestResult: Equatable {
        case proceeded(AnthemMapSession?)
        case requiresResolution
        case blocked
    }

    typealias ChangeContinuation = @MainActor (URL) -> Void
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

    private struct PendingChange {
        let id: UInt
        let replacementURL: URL
        let proceed: ChangeContinuation
        var isSaveInFlight = false
    }

    private let decision = AnthemMapUnsavedChangeDecision()
    private let resolution = AnthemMapUnsavedChangeResolution()
    private let saveExisting: ExistingSaveOperation
    private let saveAs: SaveAsOperation
    private var pendingChange: PendingChange?
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

    func requestChange(
        replacementURL: URL,
        session: AnthemMapSession?,
        currentSnapshot: AnthemRegionSnapshot?,
        hasUnsavedNewWorkspaceContent: Bool,
        proceed: @escaping ChangeContinuation
    ) -> RequestResult {
        guard pendingChange == nil else {
            return .blocked
        }

        switch decision.evaluate(
            session: session,
            currentSnapshot: currentSnapshot,
            hasUnsavedNewWorkspaceContent: hasUnsavedNewWorkspaceContent
        ) {
        case .proceed:
            proceed(replacementURL)
            return .proceeded(nil)
        case .requiresResolution:
            nextRequestID += 1
            pendingChange = PendingChange(
                id: nextRequestID,
                replacementURL: replacementURL,
                proceed: proceed
            )
            return .requiresResolution
        }
    }

    func resolvePendingChange(
        choice: AnthemMapUnsavedChangeResolution.Choice?,
        session: AnthemMapSession?,
        currentSnapshot: AnthemRegionSnapshot?,
        mediaURL: URL,
        trackDuration: TimeInterval,
        completion: @escaping Completion
    ) {
        guard let pendingChange, !pendingChange.isSaveInFlight else {
            completion(.blocked)
            return
        }

        switch resolution.resolve(choice) {
        case .discardAndProceed:
            proceedPendingChange(
                id: pendingChange.id,
                savedSession: nil,
                completion: completion
            )
        case .cancel:
            blockPendingChange(id: pendingChange.id, completion: completion)
        case .saveThenProceed:
            guard let currentSnapshot else {
                blockPendingChange(id: pendingChange.id, completion: completion)
                return
            }

            if let session, session.hasAssociatedMap {
                switch saveExisting(session, mediaURL, trackDuration, currentSnapshot) {
                case .success(let success):
                    proceedPendingChange(
                        id: pendingChange.id,
                        savedSession: success.session,
                        completion: completion
                    )
                case .failure:
                    blockPendingChange(id: pendingChange.id, completion: completion)
                }
                return
            }

            beginSaveAs(
                pendingChange,
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
        _ pendingChange: PendingChange,
        session: AnthemMapSession?,
        mediaURL: URL,
        trackDuration: TimeInterval,
        currentSnapshot: AnthemRegionSnapshot,
        completion: @escaping Completion
    ) {
        guard self.pendingChange?.id == pendingChange.id else {
            completion(.blocked)
            return
        }
        self.pendingChange?.isSaveInFlight = true

        saveAs(session, mediaURL, trackDuration, currentSnapshot) { [weak self] result in
            guard let self, self.pendingChange?.id == pendingChange.id else {
                return
            }

            switch result {
            case .saved(let success):
                self.proceedPendingChange(
                    id: pendingChange.id,
                    savedSession: success.session,
                    completion: completion
                )
            case .cancelled, .failed:
                self.blockPendingChange(id: pendingChange.id, completion: completion)
            }
        }
    }

    private func proceedPendingChange(
        id: UInt,
        savedSession: AnthemMapSession?,
        completion: @escaping Completion
    ) {
        guard let pendingChange, pendingChange.id == id else {
            return
        }
        self.pendingChange = nil
        completion(.proceeded(savedSession))
        pendingChange.proceed(pendingChange.replacementURL)
    }

    private func blockPendingChange(id: UInt, completion: @escaping Completion) {
        guard pendingChange?.id == id else {
            return
        }
        pendingChange = nil
        completion(.blocked)
    }
}
