import SwiftUI

// PHASE_4B2_INTERACTIVE_ANTHEM_REGION_EDITING
// FIX4B2B_MARKER_VISIBILITY
struct InteractiveAnthemRegionOverlay: View {
    @ObservedObject var controller: AnthemRegionController
    let trackDuration: TimeInterval
    let visibleStart: TimeInterval
    let visibleDuration: TimeInterval

    private let hitWidth: CGFloat = 34

    var body: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width)
            let viewport = WaveformViewport(start: visibleStart, duration: visibleDuration, width: width)
            let layout = AnthemRegionOverlayGeometry.layout(
                start: controller.start,
                end: controller.end,
                viewport: viewport
            )

            ZStack(alignment: .leading) {
                if let x = layout.shadeX, let shadeWidth = layout.shadeWidth {
                    Rectangle()
                        .fill(AnthemTheme.anthemHighlight.opacity(0.18))
                        .frame(width: max(1, shadeWidth))
                        .offset(x: x)
                        .allowsHitTesting(false)
                }

                if let x = layout.startX {
                    marker(title: "START", colour: .green, marker: .start, markerX: x, width: width, viewport: viewport)
                }
                if let x = layout.endX {
                    marker(title: "END", colour: .orange, marker: .end, markerX: x, width: width, viewport: viewport)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .clipped()
        }
        .accessibilityLabel("Interactive anthem region markers")
    }

    private func marker(title: String, colour: Color,
                        marker: AnthemRegionController.Marker,
                        markerX: CGFloat, width: CGFloat,
                        viewport: WaveformViewport) -> some View {
        ZStack(alignment: .top) {
            Color.clear
            Rectangle().fill(colour).frame(width: 3)
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(colour, in: RoundedRectangle(cornerRadius: 3))
                .padding(.top, 3)
        }
        .frame(width: hitWidth)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .offset(x: min(max(0, markerX - hitWidth / 2), max(0, width - hitWidth)))
        // FIX4B2C2_STABLE_ABSOLUTE_DRAG
        .highPriorityGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("anthemWaveform"))
                .onChanged { value in
                    // PHASE_4BH2_CENTRALISED_WAVEFORM_COORDINATES
                    let time = viewport.time(forX: value.location.x)
                    switch marker {
                    case .start:
                        _ = controller.setStart(at: time, trackDuration: trackDuration)
                    case .end:
                        _ = controller.setEnd(at: time, trackDuration: trackDuration)
                    }
                }
        )
        .accessibilityLabel("Drag anthem \(title) marker")
        .accessibilityHint("Drag horizontally to change the marker time")
    }
}
