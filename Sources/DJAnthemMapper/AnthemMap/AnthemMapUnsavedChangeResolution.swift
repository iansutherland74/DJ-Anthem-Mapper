struct AnthemMapUnsavedChangeResolution: Equatable, Sendable {
    enum Choice: Equatable, Sendable {
        case save
        case discard
        case cancel
    }

    enum Instruction: Equatable, Sendable {
        case saveThenProceed
        case discardAndProceed
        case cancel
    }

    func resolve(_ choice: Choice?) -> Instruction {
        switch choice {
        case .save:
            return .saveThenProceed
        case .discard:
            return .discardAndProceed
        case .cancel, nil:
            return .cancel
        }
    }
}
