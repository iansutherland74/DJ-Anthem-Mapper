import Foundation

// M3_02B3_SAVE_REQUEST_BUILDER
enum AnthemMapSaveRequestBuilderError: Error, Equatable, Sendable {
    case noRegions
    case noCompleteValidRegion
    case tooManyRegions(Int)
}

struct AnthemMapSaveRequestBuilder: Sendable {
    func makeRequest(
        trackIdentity: AnthemMapDocument.TrackIdentity,
        regions: [AnthemRegionItem]
    ) throws -> AnthemMapSaveRequest {
        guard !regions.isEmpty else {
            throw AnthemMapSaveRequestBuilderError.noRegions
        }
        guard regions.count <= AnthemMapDocument.maximumRegionCount else {
            throw AnthemMapSaveRequestBuilderError.tooManyRegions(regions.count)
        }
        guard regions.contains(where: { $0.isComplete && $0.isValid }) else {
            throw AnthemMapSaveRequestBuilderError.noCompleteValidRegion
        }
        return AnthemMapSaveRequest(track: trackIdentity, regions: regions)
    }
}
