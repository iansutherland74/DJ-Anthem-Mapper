import Combine
import Foundation

@MainActor
final class TransactionalMediaImportCoordinator: ObservableObject {
    typealias InspectionResult =
        Swift.Result<MediaDescription, MediaImportError>

    typealias Inspection = (
        URL,
        @escaping @MainActor (InspectionResult) -> Void
    ) -> Void

    enum Outcome {
        case succeeded(MediaDescription)
        case failed(MediaImportError)
    }

    private struct PendingImport {
        let id: UInt
    }

    private let inspect: Inspection
    private var nextRequestID: UInt = 0
    private var pendingImport: PendingImport?

    init() {
        let importer = FFprobeMediaImporter()

        inspect = { url, completion in
            importer.inspect(url: url) { result in
                Task { @MainActor in
                    completion(result)
                }
            }
        }
    }

    init(inspect: @escaping Inspection) {
        self.inspect = inspect
    }

    @discardableResult
    func begin(
        url: URL,
        completion: @escaping @MainActor (Outcome) -> Void
    ) -> UInt {
        nextRequestID &+= 1

        let request = PendingImport(
            id: nextRequestID
        )

        pendingImport = request

        inspect(url) { [weak self] result in
            guard
                let self,
                self.pendingImport?.id == request.id
            else {
                return
            }

            self.pendingImport = nil

            switch result {
            case .success(let description):
                completion(.succeeded(description))
            case .failure(let error):
                completion(.failed(error))
            }
        }

        return request.id
    }

    func cancelPendingImport() {
        pendingImport = nil
    }

    var hasPendingImport: Bool {
        pendingImport != nil
    }
}
