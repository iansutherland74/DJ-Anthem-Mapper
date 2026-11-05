import Foundation

// M3_02B2_TRACK_IDENTITY_BUILDER
enum AnthemMapTrackIdentityError: Error, Equatable, Sendable {
    case invalidFileName
    case invalidTrackDuration
}

struct AnthemMapTrackIdentityBuilder: Sendable {
    func validatedFileName(_ fileName: String) throws -> String {
        guard !fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnthemMapTrackIdentityError.invalidFileName
        }
        return fileName
    }

    func makeIdentity(mediaURL: URL, trackDuration: TimeInterval) throws -> AnthemMapDocument.TrackIdentity {
        let fileName = try validatedFileName(mediaURL.lastPathComponent)
        guard trackDuration.isFinite, trackDuration > 0 else {
            throw AnthemMapTrackIdentityError.invalidTrackDuration
        }

        let durationMilliseconds = Int64((trackDuration * 1000.0).rounded())
        let fileSize: UInt64?
        if let attributes = try? FileManager.default.attributesOfItem(atPath: mediaURL.path),
           let size = attributes[.size] as? NSNumber {
            fileSize = size.uint64Value
        } else {
            fileSize = nil
        }

        return AnthemMapDocument.TrackIdentity(
            fileName: fileName,
            fileSize: fileSize,
            durationMilliseconds: durationMilliseconds
        )
    }
}
