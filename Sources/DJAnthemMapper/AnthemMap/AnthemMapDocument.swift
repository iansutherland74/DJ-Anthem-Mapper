import Foundation

// M3_01_PERSISTENT_ANTHEM_MAP_SCHEMA
struct AnthemMapDocument: Codable, Equatable, Sendable {
    static let currentFormatVersion = 1
    static let maximumRegionCount = 8

    let formatVersion: Int
    let track: TrackIdentity
    let regions: [Region]

    init(formatVersion: Int = currentFormatVersion, track: TrackIdentity, regions: [Region]) {
        self.formatVersion = formatVersion
        self.track = track
        self.regions = Array(regions.prefix(Self.maximumRegionCount))
    }

    struct TrackIdentity: Codable, Equatable, Sendable {
        let fileName: String
        let fileSize: UInt64?
        let durationMilliseconds: Int64
    }

    struct Region: Codable, Equatable, Identifiable, Sendable {
        let id: UUID
        let slot: Int
        let startMilliseconds: Int64
        let endMilliseconds: Int64
        var durationMilliseconds: Int64 { endMilliseconds - startMilliseconds }

        init(id: UUID, slot: Int, startMilliseconds: Int64, endMilliseconds: Int64) {
            self.id = id; self.slot = slot; self.startMilliseconds = startMilliseconds; self.endMilliseconds = endMilliseconds
        }
    }

    enum ValidationError: Equatable, Sendable {
        case unsupportedFormatVersion(Int)
        case emptyFileName
        case invalidTrackDuration
        case tooManyRegions(Int)
        case invalidSlot(Int)
        case duplicateSlot(Int)
        case duplicateRegionID(UUID)
        case invalidBounds(slot: Int)
        case regionBeyondTrack(slot: Int)
    }

    func validationErrors() -> [ValidationError] {
        var errors: [ValidationError] = []
        if formatVersion != Self.currentFormatVersion { errors.append(.unsupportedFormatVersion(formatVersion)) }
        if track.fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append(.emptyFileName) }
        if track.durationMilliseconds <= 0 { errors.append(.invalidTrackDuration) }
        if regions.count > Self.maximumRegionCount { errors.append(.tooManyRegions(regions.count)) }
        var slots = Set<Int>(); var ids = Set<UUID>()
        for region in regions {
            if !(0..<Self.maximumRegionCount).contains(region.slot) { errors.append(.invalidSlot(region.slot)) }
            if !slots.insert(region.slot).inserted { errors.append(.duplicateSlot(region.slot)) }
            if !ids.insert(region.id).inserted { errors.append(.duplicateRegionID(region.id)) }
            if region.startMilliseconds < 0 || region.endMilliseconds <= region.startMilliseconds { errors.append(.invalidBounds(slot: region.slot)) }
            if track.durationMilliseconds > 0 && region.endMilliseconds > track.durationMilliseconds { errors.append(.regionBeyondTrack(slot: region.slot)) }
        }
        return errors
    }

    var isValid: Bool { validationErrors().isEmpty }
}
