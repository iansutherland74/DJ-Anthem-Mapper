import Foundation

struct AnthemRegion: Equatable, Sendable {
    var start: TimeInterval?
    var end: TimeInterval?

    init(start: TimeInterval? = nil, end: TimeInterval? = nil) {
        self.start = start
        self.end = end
    }

    var hasStart: Bool { start != nil }
    var hasEnd: Bool { end != nil }
    var isEmpty: Bool { start == nil && end == nil }
    var isComplete: Bool { start != nil && end != nil }

    var isValid: Bool {
        guard let start, let end else { return false }
        return start.isFinite && end.isFinite && start >= 0 && end > start
    }

    var duration: TimeInterval? {
        guard isValid, let start, let end else { return nil }
        return end - start
    }
}
