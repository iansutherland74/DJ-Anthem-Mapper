import Foundation

@MainActor
final class AnthemMapSaveAsCoordinator {
    enum Failure: Error, Equatable, Sendable {
        case preparationFailed
        case panelUnavailable
        case executionFailed
    }

    struct Success: Equatable, Sendable {
        let session: AnthemMapSession
    }

    enum Result: Equatable, Sendable {
        case saved(Success)
        case cancelled
        case failed(Failure)
    }

    typealias PanelPresentation = (
        AnthemMapSaveCoordinator.PreparedSave,
        @escaping @MainActor (AnthemMapSavePanelPresenter.Result) -> Void
    ) -> Void
    typealias Preparation = (URL, TimeInterval, [AnthemRegionItem]) throws -> AnthemMapSaveCoordinator.PreparedSave
    typealias Execution = (AnthemMapSaveCoordinator.PreparedSave, URL) throws -> URL

    private let presentSavePanel: PanelPresentation
    private let prepareSave: Preparation
    private let executeSave: Execution

    init() {
        let presenter = AnthemMapSavePanelPresenter()
        presentSavePanel = { preparedSave, completion in
            presenter.present(preparedSave: preparedSave, completion: completion)
        }
        prepareSave = { mediaURL, trackDuration, regions in
            try AnthemMapSaveCoordinator().prepare(
                mediaURL: mediaURL,
                trackDuration: trackDuration,
                regions: regions
            )
        }
        executeSave = { preparedSave, destinationURL in
            try AnthemMapSaveExecutor().execute(
                preparedSave: preparedSave,
                destinationURL: destinationURL
            )
        }
    }

    init(
        presentSavePanel: @escaping PanelPresentation,
        prepare: @escaping Preparation,
        execute: @escaping Execution
    ) {
        self.presentSavePanel = presentSavePanel
        prepareSave = prepare
        executeSave = execute
    }

    func saveAs(
        session: AnthemMapSession?,
        mediaURL: URL,
        trackDuration: TimeInterval,
        currentSnapshot: AnthemRegionSnapshot,
        completion: @escaping @MainActor (Result) -> Void
    ) {
        let preparedSave: AnthemMapSaveCoordinator.PreparedSave
        do {
            preparedSave = try prepareSave(mediaURL, trackDuration, currentSnapshot.regions)
        } catch {
            completion(.failed(.preparationFailed))
            return
        }

        var didComplete = false
        func complete(_ result: Result) {
            guard !didComplete else { return }
            didComplete = true
            completion(result)
        }

        presentSavePanel(preparedSave) { [executeSave] panelResult in
            switch panelResult {
            case .cancelled:
                complete(.cancelled)
            case .unavailable:
                complete(.failed(.panelUnavailable))
            case .selected(let destinationURL):
                do {
                    _ = try executeSave(preparedSave, destinationURL)
                    complete(.saved(Success(
                        session: AnthemMapSession(
                            mapURL: destinationURL,
                            baseline: currentSnapshot
                        )
                    )))
                } catch {
                    complete(.failed(.executionFailed))
                }
            }
        }
        _ = session
    }
}
