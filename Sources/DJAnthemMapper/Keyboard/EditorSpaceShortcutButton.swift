import SwiftUI

struct EditorSpaceShortcutButton: View {
    @ObservedObject var context: EditorKeyboardContext
    @ObservedObject var playback: PlaybackController

    var body: some View {
        Button {
            guard EditorShortcutDecision.spaceAction(
                isEditingText: context.isEditingText,
                canPlay: playback.canPlay
            ) == .togglePlayback else { return }
            playback.togglePlayback()
        } label: {
            Color.clear.frame(width: 1, height: 1)
        }
        .keyboardShortcut(.space, modifiers: [])
        .disabled(context.isEditingText || !playback.canPlay)
        .opacity(0.001)
        .accessibilityHidden(true)
        .help("Play/Pause (Space)")
    }
}
