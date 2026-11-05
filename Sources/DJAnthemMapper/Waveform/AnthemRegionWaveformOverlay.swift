import SwiftUI

// PHASE_4B1_WAVEFORM_REGION_VISUALISATION
struct AnthemRegionWaveformOverlay: View {
    let region: AnthemRegion
    let windowStart: TimeInterval
    let windowEnd: TimeInterval

    private var span: TimeInterval { max(0.001, windowEnd - windowStart) }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                if let start = visibleX(region.start, width: geometry.size.width) {
                    marker(x: start, colour: .green, label: "START", width: geometry.size.width)
                }

                if let end = visibleX(region.end, width: geometry.size.width) {
                    marker(x: end, colour: .orange, label: "END", width: geometry.size.width)
                }

                if region.isValid, let startTime = region.start, let endTime = region.end {
                    let clippedStart = max(windowStart, startTime)
                    let clippedEnd = min(windowEnd, endTime)
                    if clippedEnd > clippedStart {
                        let x1 = xPosition(clippedStart, width: geometry.size.width)
                        let x2 = xPosition(clippedEnd, width: geometry.size.width)
                        Rectangle()
                            .fill(AnthemTheme.anthemHighlight.opacity(0.16))
                            .frame(width: max(0, x2 - x1), height: geometry.size.height)
                            .offset(x: x1)
                    }
                }
            }
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func marker(x: CGFloat, colour: Color, label: String, width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(colour)
                .frame(width: 2)
                .offset(x: max(0, min(width - 2, x - 1)))
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(colour.opacity(0.90), in: RoundedRectangle(cornerRadius: 3))
                .offset(x: label == "END" ? max(0, min(width - 34, x - 32)) : max(0, min(width - 42, x + 3)), y: 3)
        }
    }

    private func visibleX(_ time: TimeInterval?, width: CGFloat) -> CGFloat? {
        guard let time, time.isFinite, time >= windowStart, time <= windowEnd else { return nil }
        return xPosition(time, width: width)
    }

    private func xPosition(_ time: TimeInterval, width: CGFloat) -> CGFloat {
        let ratio = min(1, max(0, (time - windowStart) / span))
        return width * CGFloat(ratio)
    }
}
