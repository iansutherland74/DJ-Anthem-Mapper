import Combine
import Foundation

@MainActor
final class AnthemRegionController: ObservableObject {
    enum Marker: Equatable, Sendable { case start, end }

    enum ValidationError: Error, Equatable, Sendable {
        case trackUnavailable, invalidTrackDuration, nonFiniteTime
        case beforeTrackStart, afterTrackEnd
        case startMustBeEarlierThanEnd, endMustBeLaterThanStart

        var message: String {
            switch self {
            case .trackUnavailable: return "Load a track before setting anthem markers."
            case .invalidTrackDuration: return "The track duration is unavailable."
            case .nonFiniteTime: return "The marker position is invalid."
            case .beforeTrackStart: return "The marker cannot be earlier than the track start."
            case .afterTrackEnd: return "The marker cannot be later than the track end."
            case .startMustBeEarlierThanEnd: return "START must be earlier than END."
            case .endMustBeLaterThanStart: return "END must be later than START."
            }
        }
    }

    // PHASE_4C1B_ACTIVE_REGION_BRIDGE
    @Published private(set) var collection: AnthemRegionCollection
    @Published private(set) var activeRegionID: UUID
    @Published private(set) var validationMessage: String?

    init(region: AnthemRegion = AnthemRegion()) {
        let item = AnthemRegionItem(region: region)
        self.collection = AnthemRegionCollection(regions: [item])
        self.activeRegionID = item.id
        validationMessage = nil
    }

    var region: AnthemRegion {
        collection.region(id: activeRegionID)?.region ?? AnthemRegion()
    }
    var regions: [AnthemRegionItem] { collection.regions }
    var activeRegionLabel: String { collection.displayLabel(for: activeRegionID) ?? "?" }

    var start: TimeInterval? { region.start }
    var end: TimeInterval? { region.end }
    var duration: TimeInterval? { region.duration }
    var hasStart: Bool { region.hasStart }
    var hasEnd: Bool { region.hasEnd }
    var hasAnyMarker: Bool { !region.isEmpty }
    var canPlayRegion: Bool { region.isValid }

    func captureSnapshot() -> AnthemRegionSnapshot? {
        try? AnthemRegionSnapshot(regions: collection.regions, activeRegionID: activeRegionID)
    }

    @discardableResult
    func restore(snapshot: AnthemRegionSnapshot?) -> Bool {
        guard let snapshot else { return false }
        let restoredCollection = AnthemRegionCollection(regions: snapshot.regions)
        guard restoredCollection.regions == snapshot.regions,
              restoredCollection.region(id: snapshot.activeRegionID) != nil
        else { return false }
        collection = restoredCollection
        activeRegionID = snapshot.activeRegionID
        return true
    }

    @discardableResult
    func setStart(at time: TimeInterval, trackDuration: TimeInterval) -> Bool {
        guard validateCommon(time: time, trackDuration: trackDuration, marker: .start) else { return false }
        if let end = region.end, time >= end { reject(.startMustBeEarlierThanEnd); return false }
        var updated = region
        updated.start = normalised(time)
        storeActiveRegion(updated)
        validationMessage = nil
        return true
    }

    @discardableResult
    func setEnd(at time: TimeInterval, trackDuration: TimeInterval) -> Bool {
        guard validateCommon(time: time, trackDuration: trackDuration, marker: .end) else { return false }
        if let start = region.start, time <= start { reject(.endMustBeLaterThanStart); return false }
        var updated = region
        updated.end = normalised(time)
        storeActiveRegion(updated)
        validationMessage = nil
        return true
    }

    // PHASE_4B2_INTERACTIVE_ANTHEM_REGION_EDITING
    @discardableResult
    func nudge(_ marker: Marker, by delta: TimeInterval, trackDuration: TimeInterval) -> Bool {
        let current: TimeInterval?
        switch marker {
        case .start: current = region.start
        case .end: current = region.end
        }
        guard let current else { return false }
        let proposed = min(trackDuration, max(0, current + delta))
        switch marker {
        case .start: return setStart(at: proposed, trackDuration: trackDuration)
        case .end: return setEnd(at: proposed, trackDuration: trackDuration)
        }
    }

    func clear() {
        storeActiveRegion(AnthemRegion())
        validationMessage = nil
    }

    func resetForNewTrack() {
        var updated = collection
        updated.resetForNewTrack()
        collection = updated
        activeRegionID = updated.first.id
        validationMessage = nil
    }

    @discardableResult
    func addRegion(region: AnthemRegion = AnthemRegion(), makeActive: Bool = true) -> UUID {
        var updated = collection
        let id = updated.addRegion(region: region)
        collection = updated
        if makeActive { activeRegionID = id; validationMessage = nil }
        return id
    }

    @discardableResult
    func selectRegion(id: UUID) -> Bool {
        guard collection.region(id: id) != nil else { return false }
        activeRegionID = id
        validationMessage = nil
        return true
    }

    @discardableResult
    func deleteRegion(id: UUID) -> Bool {
        guard let index = collection.index(id: id) else { return false }
        let deletingActive = id == activeRegionID
        var updated = collection
        guard updated.deleteRegion(id: id) else { return false }
        collection = updated
        if deletingActive {
            let nextIndex = min(index, updated.count - 1)
            activeRegionID = updated.regions[nextIndex].id
        }
        validationMessage = nil
        return true
    }

    // M3_03C_CONTROLLER_RESTORATION_BRIDGE
    @discardableResult
    func restore(_ restoration: AnthemMapRestoration) -> Bool {
        guard !restoration.regions.isEmpty,
              restoration.regions.count <= AnthemMapDocument.maximumRegionCount,
              restoration.regions.allSatisfy({ $0.isComplete && $0.isValid }),
              Set(restoration.regions.map(\.id)).count == restoration.regions.count
        else { return false }
        let restoredCollection = AnthemRegionCollection(regions: restoration.regions)
        guard restoredCollection.count == restoration.regions.count else { return false }
        collection = restoredCollection
        activeRegionID = restoredCollection.first.id
        validationMessage = nil
        return true
    }
    func clearValidationMessage() { validationMessage = nil }

    private func storeActiveRegion(_ region: AnthemRegion) {
        var updated = collection
        guard updated.updateRegion(id: activeRegionID, region: region) else { return }
        collection = updated
    }

    private func validateCommon(time: TimeInterval, trackDuration: TimeInterval, marker: Marker) -> Bool {
        guard trackDuration.isFinite else { reject(.invalidTrackDuration); return false }
        guard trackDuration > 0 else { reject(.trackUnavailable); return false }
        guard time.isFinite else { reject(.nonFiniteTime); return false }
        guard time >= 0 else { reject(.beforeTrackStart); return false }
        guard time <= trackDuration else { reject(.afterTrackEnd); return false }
        if marker == .start, time == trackDuration { reject(.startMustBeEarlierThanEnd); return false }
        if marker == .end, time == 0 { reject(.endMustBeLaterThanStart); return false }
        return true
    }

    private func reject(_ error: ValidationError) { validationMessage = error.message }
    private func normalised(_ time: TimeInterval) -> TimeInterval { (time * 1_000).rounded() / 1_000 }
}
