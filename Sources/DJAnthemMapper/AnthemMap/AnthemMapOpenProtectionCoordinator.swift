import Foundation

@MainActor
final class AnthemMapOpenProtectionCoordinator {
    enum RequestResult: Equatable {
        case proceeded(AnthemMapSession?)
        case requiresResolution
        case blocked
    }

    typealias OpenContinuation = @MainActor (URL) -> Void
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

    private struct PendingOpen {
        let id: UInt
        let mapURL: URL
        let proceed: OpenContinuation
        var isSaveInFlight = false
    }

    private let decision = AnthemMapUnsavedChangeDecision()
    private let resolution = AnthemMapUnsavedChangeResolution()
    private let saveExisting: ExistingSaveOperation
    private let saveAs: SaveAsOperation
    private var pendingOpen: PendingOpen?
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

    func requestOpen(
        mapURL: URL,
        session: AnthemMapSession?,
        currentSnapshot: AnthemRegionSnapshot?,
        hasUnsavedNewWorkspaceContent: Bool,
        proceed: @escaping OpenContinuation
    ) -> RequestResult {
        guard pendingOpen == nil else {
            return .blocked
        }

        switch decision.evaluate(
            session: session,
            currentSnapshot: currentSnapshot,
            hasUnsavedNewWorkspaceContent: hasUnsavedNewWorkspaceContent
        ) {
        case .proceed:
            proceed(mapURL)
            return .proceeded(nil)
        case .requiresResolution:
            nextRequestID += 1
            pendingOpen = PendingOpen(
                id: nextRequestID,
                mapURL: mapURL,
                proceed: proceed
            )
            return .requiresResolution
        }
    }

    func resolvePendingOpen(
        choice: AnthemMapUnsavedChangeResolution.Choice?,
        session: AnthemMapSession?,
        currentSnapshot: AnthemRegionSnapshot?,
        mediaURL: URL,
        trackDuration: TimeInterval,
        completion: @escaping Completion
    ) {
        guard let pendingOpen, !pendingOpen.isSaveInFlight else {
            completion(.blocked)
            return
        }

        switch resolution.resolve(choice) {
        case .discardAndProceed:
            proceedPendingOpen(
                id: pendingOpen.id,
                savedSession: nil,
                completion: completion
            )
        case .cancel:
            blockPendingOpen(id: pendingOpen.id, completion: completion)
        case .saveThenProceed:
            guard let currentSnapshot else {
                blockPendingOpen(id: pendingOpen.id, completion: completion)
                return
            }

            if let session, session.hasAssociatedMap {
                switch saveExisting(session, mediaURL, trackDuration, currentSnapshot) {
                case .success(let success):
                    proceedPendingOpen(
                        id: pendingOpen.id,
                        savedSession: success.session,
                        completion: completion
                    )
                case .failure:
                    blockPendingOpen(id: pendingOpen.id, completion: completion)
                }
                return
            }

            beginSaveAs(
                pendingOpen,
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
        _ pendingOpen: PendingOpen,
        session: AnthemMapSession?,
        mediaURL: URL,
        trackDuration: TimeInterval,
        currentSnapshot: AnthemRegionSnapshot,
        completion: @escaping Completion
    ) {
        guard self.pendingOpen?.id == pendingOpen.id else {
            completion(.blocked)
            return
        }
        self.pendingOpen?.isSaveInFlight = true

        saveAs(session, mediaURL, trackDuration, currentSnapshot) { [weak self] result in
            guard let self, self.pendingOpen?.id == pendingOpen.id else {
                return
            }

            switch result {
            case .saved(let success):
                self.proceedPendingOpen(
                    id: pendingOpen.id,
                    savedSession: success.session,
                    completion: completion
                )
            case .cancelled, .failed:
                self.blockPendingOpen(id: pendingOpen.id, completion: completion)
            }
        }
    }

    private func proceedPendingOpen(
        id: UInt,
        savedSession: AnthemMapSession?,
        completion: @escaping Completion
    ) {
        guard let pendingOpen, pendingOpen.id == id else {
            return
        }
        self.pendingOpen = nil
        completion(.proceeded(savedSession))
        pendingOpen.proceed(pendingOpen.mapURL)
    }

    private func blockPendingOpen(id: UInt, completion: @escaping Completion) {
        guard pendingOpen?.id == id else {
            return
        }
        pendingOpen = nil
        completion(.blocked)
    }
}
