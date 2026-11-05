import Foundation

// M3_02B4_SUGGESTED_FILENAME_BUILDER
struct AnthemMapSuggestedFileName: Sendable {
    static let fileExtension = "anthemmap"

    func make(for mediaURL: URL) -> String {
        let sourceName = mediaURL.lastPathComponent
        let stem = (sourceName as NSString).deletingPathExtension
        let usableStem = stem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Anthem Map" : stem
        return usableStem + "." + Self.fileExtension
    }
}
