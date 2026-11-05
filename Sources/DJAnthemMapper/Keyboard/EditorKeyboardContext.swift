import Combine
import Foundation

@MainActor
// PHASE_4A3A3_FOCUSSTATE_SOURCE_RELEASE
final class EditorKeyboardContext: ObservableObject {
    @Published var isEditingText = false
    @Published private(set) var focusReleaseGeneration = 0

    func requestFocusRelease() {
        focusReleaseGeneration &+= 1
        isEditingText = false
    }
}

enum EditorShortcutAction: Equatable, Sendable {
    case togglePlayback
    case ignored
}

enum EditorShortcutDecision {
    static func spaceAction(isEditingText: Bool, canPlay: Bool) -> EditorShortcutAction {
        guard !isEditingText, canPlay else { return .ignored }
        return .togglePlayback
    }
}
