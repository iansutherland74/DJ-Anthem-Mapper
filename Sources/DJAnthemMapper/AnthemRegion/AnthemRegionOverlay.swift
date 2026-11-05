import SwiftUI

struct AnthemRegionOverlay: View {
    let start: TimeInterval?
    let end: TimeInterval?
    let visibleStart: TimeInterval
    let visibleDuration: TimeInterval

    var body: some View {
        GeometryReader { proxy in
            let layout = AnthemRegionOverlayGeometry.layout(
                start: start,
                end: end,
                visibleStart: visibleStart,
                visibleDuration: visibleDuration,
                width: proxy.size.width
            )

            ZStack(alignment: .leading) {
                if let x = layout.shadeX, let width = layout.shadeWidth {
                    Rectangle()
                        .fill(Color.blue.opacity(0.16))
                        .frame(width: width)
                        .offset(x: x)
                }
                if let x = layout.startX {
                    marker("START", colour: .green).offset(x: x)
                }
                if let x = layout.endX {
                    marker("END", colour: .orange).offset(x: x)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func marker(_ title: String, colour: Color) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(colour).frame(width: 2)
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .foregroundStyle(.black)
                .background(colour, in: RoundedRectangle(cornerRadius: 3))
        }
    }
}
