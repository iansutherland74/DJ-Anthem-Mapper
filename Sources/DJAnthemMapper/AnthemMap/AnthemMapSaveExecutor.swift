import Foundation

// M3_02B8_SAVE_EXECUTION_LAYER
struct AnthemMapSaveExecutor: Sendable {
    private let saveEngine = AnthemMapSaveEngine()

    @discardableResult
    func execute(
        preparedSave: AnthemMapSaveCoordinator.PreparedSave,
        destinationURL: URL
    ) throws -> URL {
        try saveEngine.save(
            document: preparedSave.document,
            to: destinationURL
        )
        return destinationURL
    }
}
