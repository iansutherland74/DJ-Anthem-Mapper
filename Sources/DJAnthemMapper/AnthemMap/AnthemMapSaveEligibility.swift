import Foundation

// M3_02B1_SAVE_ELIGIBILITY
struct AnthemMapSaveEligibility: Equatable, Sendable {
    enum Blocker: Equatable, Sendable {
        case noLoadedMedia
        case invalidTrackDuration
        case noCompleteValidRegion
        case completeInvalidRegion(slot: Int)
        case tooManyRegions(Int)
    }

    let blockers: [Blocker]
    var canSave: Bool { blockers.isEmpty }

    static func evaluate(hasLoadedMedia: Bool, trackDuration: TimeInterval, regions: [AnthemRegionItem]) -> Self {
        var blockers: [Blocker] = []
        if !hasLoadedMedia { blockers.append(.noLoadedMedia) }
        if !trackDuration.isFinite || trackDuration <= 0 { blockers.append(.invalidTrackDuration) }
        if regions.count > AnthemMapDocument.maximumRegionCount { blockers.append(.tooManyRegions(regions.count)) }
        var hasCompleteValidRegion = false
        for (slot, item) in regions.enumerated() {
            if item.isComplete {
                if item.isValid { hasCompleteValidRegion = true }
                else { blockers.append(.completeInvalidRegion(slot: slot)) }
            }
        }
        if !hasCompleteValidRegion { blockers.append(.noCompleteValidRegion) }
        return Self(blockers: blockers)
    }
}
