import Foundation

struct AnthemRegionOverlayGeometry: Equatable, Sendable {
    struct Layout: Equatable, Sendable {
        var startX: Double?
        var endX: Double?
        var shadeX: Double?
        var shadeWidth: Double?

        init(startX: Double? = nil, endX: Double? = nil, shadeX: Double? = nil, shadeWidth: Double? = nil) {
            self.startX = startX; self.endX = endX; self.shadeX = shadeX; self.shadeWidth = shadeWidth
        }
    }

    // PHASE_4BH2_CENTRALISED_WAVEFORM_COORDINATES
    static func layout(start: TimeInterval?, end: TimeInterval?, viewport: WaveformViewport) -> Layout {
        guard viewport.isValid else { return Layout() }
        let startX = start.flatMap { viewport.visibleX(forTime: $0) }
        let endX = end.flatMap { viewport.visibleX(forTime: $0) }
        guard let start, let end, start.isFinite, end.isFinite, end > start else {
            return Layout(startX: startX, endX: endX)
        }
        let lower = max(start, viewport.start), upper = min(end, viewport.end)
        guard upper > lower else { return Layout(startX: startX, endX: endX) }
        let x1 = viewport.x(forTime: lower)
        let x2 = viewport.x(forTime: upper)
        return Layout(startX: startX, endX: endX, shadeX: x1, shadeWidth: x2 - x1)
    }

    static func layout(start: TimeInterval?, end: TimeInterval?, visibleStart: TimeInterval,
                       visibleDuration: TimeInterval, width: Double) -> Layout {
        layout(start: start, end: end,
               viewport: WaveformViewport(start: visibleStart, duration: visibleDuration, width: width))
    }
}
