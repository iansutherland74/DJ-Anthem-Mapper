import Foundation

// PHASE_4C1A_MULTI_REGION_DATA_MODEL
struct AnthemRegionItem: Identifiable, Equatable, Sendable {
    let id: UUID
    var region: AnthemRegion
    init(id: UUID = UUID(), region: AnthemRegion = AnthemRegion()) { self.id = id; self.region = region }
    var start: TimeInterval? { region.start }
    var end: TimeInterval? { region.end }
    var duration: TimeInterval? { region.duration }
    var hasStart: Bool { region.hasStart }
    var hasEnd: Bool { region.hasEnd }
    var isEmpty: Bool { region.isEmpty }
    var isComplete: Bool { region.isComplete }
    var isValid: Bool { region.isValid }
}

struct AnthemRegionCollection: Equatable, Sendable {
    private(set) var regions: [AnthemRegionItem]
    init(regions: [AnthemRegionItem] = []) {
        self.regions = regions.isEmpty ? [AnthemRegionItem()] : Self.uniqueRegions(from: regions)
    }
    var count: Int { regions.count }
    var isEmpty: Bool { regions.isEmpty }
    var first: AnthemRegionItem { regions[0] }
    func region(id: UUID) -> AnthemRegionItem? { regions.first { $0.id == id } }
    func index(id: UUID) -> Int? { regions.firstIndex { $0.id == id } }
    func displayLabel(for id: UUID) -> String? { index(id: id).map(Self.displayLabel(forIndex:)) }
    @discardableResult mutating func addRegion(region: AnthemRegion = AnthemRegion()) -> UUID {
        let item = AnthemRegionItem(region: region); regions.append(item); return item.id
    }
    @discardableResult mutating func updateRegion(id: UUID, region: AnthemRegion) -> Bool {
        guard let i = index(id: id) else { return false }; regions[i].region = region; return true
    }
    @discardableResult mutating func mutateRegion(id: UUID, _ mutation: (inout AnthemRegion) -> Void) -> Bool {
        guard let i = index(id: id) else { return false }; mutation(&regions[i].region); return true
    }
    @discardableResult mutating func deleteRegion(id: UUID) -> Bool {
        guard let i = index(id: id) else { return false }
        if regions.count == 1 { regions[0].region = AnthemRegion() } else { regions.remove(at: i) }
        return true
    }
    mutating func resetForNewTrack() { regions = [AnthemRegionItem()] }
    static func displayLabel(forIndex index: Int) -> String {
        guard index >= 0 else { return "?" }
        var value = index, label = ""
        repeat {
            guard let scalar = UnicodeScalar(65 + value % 26) else { return String(index + 1) }
            label.insert(Character(scalar), at: label.startIndex); value = value / 26 - 1
        } while value >= 0
        return label
    }
    private static func uniqueRegions(from regions: [AnthemRegionItem]) -> [AnthemRegionItem] {
        var seen = Set<UUID>(), result: [AnthemRegionItem] = []
        for item in regions where seen.insert(item.id).inserted { result.append(item) }
        return result.isEmpty ? [AnthemRegionItem()] : result
    }
}
