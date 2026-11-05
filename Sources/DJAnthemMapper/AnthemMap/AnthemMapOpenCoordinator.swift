import Combine
import Foundation

// M3_03F_OPEN_COORDINATOR
@MainActor
final class AnthemMapOpenCoordinator: ObservableObject {
    enum Failure: Equatable {
        case read(AnthemMapReadError)
        case restoration(AnthemMapRestorationError)
        case trackMismatch([AnthemMapTrackMatcher.Mismatch])
        case controllerRestoreFailed
    }

    enum Status: Equatable {
        case idle
        case opening
        case opened
        case failed(Failure)
    }

    @Published private(set) var status: Status = .idle
    private let readEngine = AnthemMapReadEngine()
    private let restorationBuilder = AnthemMapRestorationBuilder()
    private let trackMatcher = AnthemMapTrackMatcher()

    @discardableResult
    func open(mapURL: URL, actualTrackIdentity: AnthemMapDocument.TrackIdentity, controller: AnthemRegionController) -> Bool {
        status = .opening
        let document: AnthemMapDocument
        do { document = try readEngine.load(from: mapURL) }
        catch let error as AnthemMapReadError { status = .failed(.read(error)); return false }
        catch { status = .failed(.read(.readFailed)); return false }

        let restoration: AnthemMapRestoration
        do { restoration = try restorationBuilder.makeRestoration(from: document) }
        catch let error as AnthemMapRestorationError { status = .failed(.restoration(error)); return false }
        catch { status = .failed(.restoration(.invalidDocument(document.validationErrors()))); return false }

        let match = trackMatcher.compare(expected: restoration.track, actual: actualTrackIdentity)
        guard match.matches else { status = .failed(.trackMismatch(match.mismatches)); return false }
        guard controller.restore(restoration) else { status = .failed(.controllerRestoreFailed); return false }
        status = .opened
        return true
    }

    func reset() { status = .idle }
}
