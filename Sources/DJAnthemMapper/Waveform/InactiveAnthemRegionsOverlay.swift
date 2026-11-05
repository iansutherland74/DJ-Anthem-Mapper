import SwiftUI

// PHASE_4C2B_READ_ONLY_INACTIVE_REGION_OVERLAY
struct InactiveAnthemRegionsOverlay: View {
    @ObservedObject var controller: AnthemRegionController
    let visibleStart: TimeInterval
    let visibleDuration: TimeInterval

    // PHASE_4C2C_DJ_PAD_PALETTE
    private func color(for index: Int) -> Color {
        // Bright RGB performance-pad style palette. Region letters remain visible,
        // so colour is an additional identity rather than the only identity.
        let palette: [Color] = [
            Color(red: 0.93, green: 0.18, blue: 0.20), // A red
            Color(red: 1.00, green: 0.45, blue: 0.10), // B orange
            Color(red: 0.12, green: 0.48, blue: 1.00), // C blue
            Color(red: 1.00, green: 0.82, blue: 0.08), // D yellow
            Color(red: 0.18, green: 0.82, blue: 0.32), // E green
            Color(red: 0.05, green: 0.78, blue: 0.88), // F cyan
            Color(red: 0.60, green: 0.30, blue: 0.95), // G purple
            Color(red: 1.00, green: 0.25, blue: 0.62)  // H pink
        ]
        return palette[max(0, index) % palette.count]
    }

    var body: some View {
        GeometryReader { proxy in
            let viewport = WaveformViewport(
                start: visibleStart,
                duration: visibleDuration,
                width: max(1, proxy.size.width)
            )
            let layouts = MultiRegionWaveformGeometry.layout(
                regions: controller.regions,
                activeRegionID: controller.activeRegionID,
                viewport: viewport
            )

            ZStack(alignment: .leading) {
                // PHASE_4C2C_REGION_LABELS_AND_STYLING
                // PHASE_4C2G_PERSISTENT_ACTIVE_REGION_RECTANGLE
                // Render every region's pad-coloured rectangle persistently. The active
                // START/END marker overlay remains above this read-only presentation layer.
                ForEach(layouts) { layout in
                    if let x = layout.shadeX,
                       let shadeWidth = layout.shadeWidth,
                       shadeWidth > 0 {
                        let label = controller.collection.displayLabel(for: layout.id) ?? "?"
                        let regionIndex = controller.collection.index(id: layout.id) ?? 0
                        let regionColor = color(for: regionIndex)
                        let renderedWidth = max(1, shadeWidth)

                        // PHASE_4C2C_REGION_COLOUR_IDENTITY
                        // PHASE_4C2C_REGION_COLOUR_VISIBILITY
                        ZStack(alignment: .topLeading) {
                            Rectangle()
                                .fill(regionColor.opacity(0.18))

                            Rectangle()
                                .fill(regionColor.opacity(0.82))
                                .frame(height: 3)

                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(regionColor.opacity(0.88))
                                    .frame(width: 2)
                                Spacer(minLength: 0)
                                Rectangle()
                                    .fill(regionColor.opacity(0.72))
                                    .frame(width: 2)
                            }

                            // PHASE_4C2C_COMPLETE_REGION_OUTLINE
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                Rectangle()
                                    .fill(regionColor.opacity(0.82))
                                    .frame(height: 2)
                            }

                            if renderedWidth >= 18 {
                                Text(label)
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.96))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(regionColor.opacity(0.82))
                                    )
                                    .padding(4)
                            }
                        }
                        .frame(width: renderedWidth)
                        .offset(x: x)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
        }
        // M2-02 is intentionally presentation-only. It must never intercept
        // waveform seek, START/END drag, or any later gesture layer.
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
