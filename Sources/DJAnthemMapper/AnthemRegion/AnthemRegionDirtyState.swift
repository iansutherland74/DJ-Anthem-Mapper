struct AnthemRegionDirtyState: Equatable, Sendable {
    enum State: Equatable, Sendable {
        case clean
        case dirty
    }

    let baseline: AnthemRegionSnapshot

    func evaluate(current: AnthemRegionSnapshot) -> State {
        baseline.regions == current.regions ? .clean : .dirty
    }
}
