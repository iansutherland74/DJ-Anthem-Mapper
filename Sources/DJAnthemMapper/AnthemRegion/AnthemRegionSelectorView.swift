import SwiftUI

// PHASE_4C1C_REGION_SELECTOR_UI
struct AnthemRegionSelectorView: View {
    @ObservedObject var controller: AnthemRegionController
    @ObservedObject var playback: PlaybackController

    var body: some View {
        HStack(spacing: 8) {
            Text("REGION")
                .font(.caption2.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(AnthemTheme.textMuted)

            ForEach(controller.regions) { item in
                let label = controller.collection.displayLabel(for: item.id) ?? "?"
                Button(label) {
                    stopBoundedPlaybackIfNeeded()
                    _ = controller.selectRegion(id: item.id)
                }
                .buttonStyle(.bordered)
                .tint(item.id == controller.activeRegionID ? .accentColor : nil)
                .help("Edit Region \(label)")
                .accessibilityLabel("Region \(label)\(item.id == controller.activeRegionID ? ", selected" : "")")
            }

            Button("+ Add Region") {
                stopBoundedPlaybackIfNeeded()
                _ = controller.addRegion()
            }
            // PHASE_4C2G_ADD_REGION_VALIDITY_GATE
            // PHASE_4C2H_MAX_8_REGIONS
            .disabled(!controller.canPlayRegion || controller.regions.count >= 8)
            .help(controller.canPlayRegion
                  ? (controller.regions.count >= 8 ? "Maximum of 8 anthem regions reached" : "Add a new anthem region and select it")
                  : "Set a valid START and END for the selected region before adding another region")

            Button("Delete Region", role: .destructive) {
                stopBoundedPlaybackIfNeeded()
                _ = controller.deleteRegion(id: controller.activeRegionID)
            }
            .help(controller.regions.count == 1 ? "Clear the only region" : "Delete the selected region")

            Spacer(minLength: 0)

            Text("\(controller.activeRegionLabel) · \(activePosition) of \(controller.regions.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(AnthemTheme.textMuted)
        }
    }

    private var activePosition: Int {
        (controller.collection.index(id: controller.activeRegionID) ?? 0) + 1
    }

    private func stopBoundedPlaybackIfNeeded() {
        if playback.isPlayingRegion {
            playback.cancelRegionPlayback()
        }
    }
}
