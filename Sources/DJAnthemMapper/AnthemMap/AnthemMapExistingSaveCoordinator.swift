import Foundation

@MainActor
struct AnthemMapExistingSaveCoordinator {
    enum Failure: Error, Equatable, Sendable {
        case noAssociatedMap
        case preparationFailed
        case executionFailed
    }

    struct Success: Equatable, Sendable {
        let session: AnthemMapSession
    }

    func save(
        session: AnthemMapSession,
        mediaURL: URL,
        trackDuration: TimeInterval,
        currentSnapshot: AnthemRegionSnapshot
    ) -> Result<Success, Failure> {
        guard let mapURL = session.mapURL else { return .failure(.noAssociatedMap) }

        let preparedSave: AnthemMapSaveCoordinator.PreparedSave
        do {
            preparedSave = try AnthemMapSaveCoordinator().prepare(
                mediaURL: mediaURL,
                trackDuration: trackDuration,
                regions: currentSnapshot.regions
            )
        } catch {
            return .failure(.preparationFailed)
        }

        do {
            try AnthemMapSaveExecutor().execute(preparedSave: preparedSave, destinationURL: mapURL)
        } catch {
            return .failure(.executionFailed)
        }

        return .success(Success(
            session: AnthemMapSession(mapURL: mapURL, baseline: currentSnapshot)
        ))
    }
}
