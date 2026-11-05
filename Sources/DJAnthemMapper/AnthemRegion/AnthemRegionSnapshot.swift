import Foundation

struct AnthemRegionSnapshot: Equatable, Sendable {
    enum ValidationError: Error, Equatable, Sendable {
        case emptyRegions
        case tooManyRegions(Int)
        case duplicateRegionID(UUID)
        case missingActiveRegionID(UUID)
    }

    let regions: [AnthemRegionItem]
    let activeRegionID: UUID

    init(regions: [AnthemRegionItem], activeRegionID: UUID) throws {
        guard !regions.isEmpty else { throw ValidationError.emptyRegions }
        guard regions.count <= AnthemMapDocument.maximumRegionCount else {
            throw ValidationError.tooManyRegions(regions.count)
        }

        var seen = Set<UUID>()
        for region in regions {
            guard seen.insert(region.id).inserted else {
                throw ValidationError.duplicateRegionID(region.id)
            }
        }

        guard seen.contains(activeRegionID) else {
            throw ValidationError.missingActiveRegionID(activeRegionID)
        }

        self.regions = regions
        self.activeRegionID = activeRegionID
    }
}
