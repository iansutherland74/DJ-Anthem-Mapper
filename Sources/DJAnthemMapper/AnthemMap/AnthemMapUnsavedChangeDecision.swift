struct AnthemMapUnsavedChangeDecision: Equatable, Sendable {
    enum Outcome: Equatable, Sendable {
        case proceed
        case requiresResolution
    }

    func evaluate(
        session: AnthemMapSession?,
        currentSnapshot: AnthemRegionSnapshot?,
        hasUnsavedNewWorkspaceContent: Bool
    ) -> Outcome {
        guard let currentSnapshot else {
            return .requiresResolution
        }

        if let session {
            switch session.dirtyState(current: currentSnapshot) {
            case .clean:
                return .proceed
            case .dirty:
                return .requiresResolution
            }
        }

        return hasUnsavedNewWorkspaceContent ? .requiresResolution : .proceed
    }
}
