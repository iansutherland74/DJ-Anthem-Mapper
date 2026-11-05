import Combine
import Foundation

// M3_02B5_SAVE_COORDINATOR
@MainActor
final class AnthemMapSaveCoordinator: ObservableObject {
    enum Status: Equatable { case idle, ready, preparing, prepared, failed(String) }
    struct PreparedSave: Equatable, Sendable { let document: AnthemMapDocument; let suggestedFileName: String }
    enum CoordinatorError: Error, Equatable, Sendable { case notEligible, trackIdentityFailed, requestFailed, documentValidationFailed }

    @Published private(set) var status: Status = .idle
    @Published private(set) var eligibility: AnthemMapSaveEligibility?
    @Published private(set) var preparedSave: PreparedSave?

    private let trackIdentityBuilder = AnthemMapTrackIdentityBuilder()
    private let requestBuilder = AnthemMapSaveRequestBuilder()
    private let filenameBuilder = AnthemMapSuggestedFileName()
    private let saveEngine = AnthemMapSaveEngine()

    init() {}

    var canSave: Bool { eligibility?.canSave == true }
    var blockers: [AnthemMapSaveEligibility.Blocker] { eligibility?.blockers ?? [] }

    @discardableResult
    func evaluate(mediaURL: URL?, trackDuration: TimeInterval, regions: [AnthemRegionItem]) -> AnthemMapSaveEligibility {
        let result = AnthemMapSaveEligibility.evaluate(hasLoadedMedia: mediaURL != nil, trackDuration: trackDuration, regions: regions)
        eligibility = result; preparedSave = nil; status = result.canSave ? .ready : .idle
        return result
    }

    func prepare(mediaURL: URL, trackDuration: TimeInterval, regions: [AnthemRegionItem]) throws -> PreparedSave {
        let result = AnthemMapSaveEligibility.evaluate(hasLoadedMedia: true, trackDuration: trackDuration, regions: regions)
        eligibility = result; preparedSave = nil
        guard result.canSave else { status = .idle; throw CoordinatorError.notEligible }
        status = .preparing
        let trackIdentity: AnthemMapDocument.TrackIdentity
        do { trackIdentity = try trackIdentityBuilder.makeIdentity(mediaURL: mediaURL, trackDuration: trackDuration) }
        catch { return try transitionToFailure(error: .trackIdentityFailed, message: "Track identity could not be prepared.") }
        let request: AnthemMapSaveRequest
        do { request = try requestBuilder.makeRequest(trackIdentity: trackIdentity, regions: regions) }
        catch { return try transitionToFailure(error: .requestFailed, message: "Anthem Map save request could not be prepared.") }
        let document: AnthemMapDocument
        do { document = try saveEngine.makeDocument(from: request) }
        catch { return try transitionToFailure(error: .documentValidationFailed, message: "Anthem Map validation failed.") }
        let prepared = PreparedSave(document: document, suggestedFileName: filenameBuilder.make(for: mediaURL))
        preparedSave = prepared; status = .prepared; return prepared
    }

    func reset() { eligibility = nil; preparedSave = nil; status = .idle }
    private func transitionToFailure(error: CoordinatorError, message: String) throws -> PreparedSave { preparedSave = nil; status = .failed(message); throw error }
}
