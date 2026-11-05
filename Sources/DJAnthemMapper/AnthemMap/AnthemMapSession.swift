import Foundation

struct AnthemMapSession: Equatable, Sendable {
    let mapURL: URL?
    let baseline: AnthemRegionSnapshot

    var hasAssociatedMap: Bool {
        mapURL != nil
    }

    func dirtyState(current: AnthemRegionSnapshot) -> AnthemRegionDirtyState.State {
        AnthemRegionDirtyState(baseline: baseline).evaluate(current: current)
    }
}
