import Foundation

// M3_03D_TRACK_IDENTITY_MATCHER
struct AnthemMapTrackMatcher: Sendable {
    enum Mismatch: Equatable, Sendable {
        case fileName
        case fileSize
        case duration
    }

    struct Result: Equatable, Sendable {
        let mismatches: [Mismatch]
        var matches: Bool { mismatches.isEmpty }
    }

    func compare(
        expected: AnthemMapDocument.TrackIdentity,
        actual: AnthemMapDocument.TrackIdentity
    ) -> Result {
        var mismatches: [Mismatch] = []
        if expected.fileName != actual.fileName { mismatches.append(.fileName) }
        if let expectedFileSize = expected.fileSize,
           let actualFileSize = actual.fileSize,
           expectedFileSize != actualFileSize {
            mismatches.append(.fileSize)
        }
        if expected.durationMilliseconds != actual.durationMilliseconds { mismatches.append(.duration) }
        return Result(mismatches: mismatches)
    }
}
