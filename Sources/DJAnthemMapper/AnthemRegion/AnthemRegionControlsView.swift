import SwiftUI

// PHASE_4B2_INTERACTIVE_ANTHEM_REGION_EDITING
struct AnthemRegionControlsView: View {
    @ObservedObject var controller: AnthemRegionController
    @ObservedObject var playback: PlaybackController
    @State private var selectedMarker: AnthemRegionController.Marker = .start

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("ANTHEM REGION")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(AnthemTheme.textMuted)
                Spacer()
                if let message = controller.validationMessage {
                    Text(message).font(.caption).foregroundStyle(.orange)
                        .accessibilityLabel("Marker error: \(message)")
                }
            }

            // PHASE_4C1C_REGION_SELECTOR_UI
            AnthemRegionSelectorView(controller: controller, playback: playback)

            Divider().overlay(AnthemTheme.border)

            // FIX4B3D2_READABLE_ANTHEM_CONTROLS
            values
            coreButtons
            auditionButtons

            Divider().overlay(AnthemTheme.border)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { markerPicker; Spacer(minLength: 8); nudgeButtons }
                VStack(alignment: .leading, spacing: 8) { markerPicker; nudgeButtons }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.035)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AnthemTheme.border, lineWidth: 1))
        // FIX4B2E_LIVE_END_PLAYBACK_BOUNDARY
        .onChange(of: controller.end) { _, newEnd in
            guard let newEnd, playback.isPlayingRegion else { return }
            playback.updateActiveRegionEnd(newEnd)
        }
        // FIX4B3A1_LIVE_START_LOOP_BOUNDARY
        .onChange(of: controller.start) { _, newStart in
            guard let newStart, playback.isLoopingRegion else { return }
            playback.updateActiveRegionStart(newStart)
        }
    }

    private var values: some View {
        HStack(spacing: 18) {
            markerValue(title: "START", time: controller.start, colour: .green)
            markerValue(title: "END", time: controller.end, colour: .orange)
            markerValue(title: "DURATION", time: controller.duration, colour: AnthemTheme.textSecondary)
        }
    }

    private var coreButtons: some View {
        HStack(spacing: 8) {
            Button("Set START") {
                controller.setStart(at: playback.currentTime, trackDuration: playback.duration)
                selectedMarker = .start
            }.help("Set START to the current playback position")
            Button("Set END") {
                controller.setEnd(at: playback.currentTime, trackDuration: playback.duration)
                selectedMarker = .end
            }.help("Set END to the current playback position")
            Button(playback.isPlayingRegion ? "Stop Region" : "Play Region") {
                if playback.isPlayingRegion { playback.cancelRegionPlayback() }
                else if let start = controller.start, let end = controller.end { playback.playRegion(start: start, end: end) }
            }
            .disabled(!playback.isPlayingRegion && !controller.canPlayRegion)
            Button(playback.isLoopingRegion ? "Stop Loop" : "Loop Region") {
                if playback.isLoopingRegion { playback.cancelRegionPlayback() }
                else if let start = controller.start, let end = controller.end { playback.loopRegion(start: start, end: end) }
            }
            .disabled(!playback.isLoopingRegion && !controller.canPlayRegion)
            Button("Clear", role: .destructive) { controller.clear() }.disabled(!controller.hasAnyMarker)
        }
    }

    private var auditionButtons: some View {
        HStack(spacing: 8) {
            Button("Audition START") { if let start = controller.start { playback.auditionStart(start) } }.disabled(!controller.hasStart)
            Button("Audition END") { if let end = controller.end { playback.auditionEnd(end) } }.disabled(!controller.hasEnd)
            Button("Pre −2s") { if let start = controller.start { playback.preRollStart(start, seconds: 2) } }.disabled(!controller.hasStart)
            Button("Pre −5s") { if let start = controller.start { playback.preRollStart(start, seconds: 5) } }.disabled(!controller.hasStart)
            Button("Post +2s") { if let end = controller.end { playback.postRollEnd(end, seconds: 2) } }.disabled(!controller.hasEnd)
            Button("Post +5s") { if let end = controller.end { playback.postRollEnd(end, seconds: 5) } }.disabled(!controller.hasEnd)
        }
    }

    private var markerPicker: some View {
        Picker("Edit marker", selection: $selectedMarker) {
            Text("START").tag(AnthemRegionController.Marker.start)
            Text("END").tag(AnthemRegionController.Marker.end)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 220)
    }

    private var nudgeButtons: some View {
        HStack(spacing: 6) {
            nudgeButton("−1s", -1)
            nudgeButton("−100ms", -0.1)
            nudgeButton("−10ms", -0.01)
            nudgeButton("+10ms", 0.01)
            nudgeButton("+100ms", 0.1)
            nudgeButton("+1s", 1)
        }
    }

    private func nudgeButton(_ title: String, _ delta: TimeInterval) -> some View {
        Button(title) {
            controller.nudge(selectedMarker, by: delta, trackDuration: playback.duration)
        }
        .disabled(selectedMarker == .start ? !controller.hasStart : !controller.hasEnd)
        .help("Move selected marker by \(title)")
    }

    private func markerValue(title: String, time: TimeInterval?, colour: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2.weight(.bold)).foregroundStyle(AnthemTheme.textMuted)
            Text(time.map(format) ?? "Not set")
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(time == nil ? AnthemTheme.textSecondary : colour)
        }
        .frame(minWidth: 86, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func format(_ seconds: TimeInterval) -> String {
        let milliseconds = Int64((seconds * 1_000).rounded())
        return String(format: "%02lld:%02lld.%03lld", milliseconds / 60_000,
                      (milliseconds / 1_000) % 60, milliseconds % 1_000)
    }
}
