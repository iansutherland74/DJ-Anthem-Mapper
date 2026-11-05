import Foundation

struct MediaDescription {
    let sourceURL: URL
    let fileSize: Int64
    let container: String
    let duration: Double?
    let overallBitRate: Int?
    let metadata: MediaMetadata
    let audioStreams: [AudioStreamDescription]
    let hasVideo: Bool

    var defaultAudioStream: AudioStreamDescription? {
        audioStreams.first(where: { $0.isDefault && !$0.isCommentary })
            ?? audioStreams.first(where: { !$0.isCommentary })
            ?? audioStreams.first
    }
}

struct MediaMetadata {
    let title: String?
    let artist: String?
    let album: String?
    let genre: String?
}

struct AudioStreamDescription: Identifiable {
    let id: Int
    let codecName: String
    let codecLongName: String?
    let sampleRate: Int?
    let channels: Int?
    let channelLayout: String?
    let bitRate: Int?
    let language: String?
    let title: String?
    let isDefault: Bool
    let isCommentary: Bool
}
