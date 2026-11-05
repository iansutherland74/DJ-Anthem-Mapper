import Foundation

// M3_03G_LOADED_MEDIA_IDENTITY_BRIDGE
enum AnthemMapLoadedMediaIdentityError: Error, Equatable, Sendable {
    case noLoadedMedia
    case invalidIdentity(AnthemMapTrackIdentityError)
}

struct AnthemMapLoadedMediaIdentityBuilder: Sendable {
    private let builder = AnthemMapTrackIdentityBuilder()

    func makeIdentity(
        media: MediaDescription?,
        trackDuration: TimeInterval
    ) throws -> AnthemMapDocument.TrackIdentity {
        guard let media else {
            throw AnthemMapLoadedMediaIdentityError.noLoadedMedia
        }
        do {
            return try builder.makeIdentity(
                mediaURL: media.sourceURL,
                trackDuration: trackDuration
            )
        } catch let error as AnthemMapTrackIdentityError {
            throw AnthemMapLoadedMediaIdentityError.invalidIdentity(error)
        }
    }
}
