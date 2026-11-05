import Foundation

// PHASE_4C2F_MULTI_REGION_WAVEFORM_HIT_TESTING
struct MultiRegionWaveformHitTesting {
    enum Decision: Equatable, Sendable {
        case activeMarkerPriority
        case selectRegion(UUID)
        case seekWaveform
    }

    static func decision(
        x: Double,
        layouts: [MultiRegionWaveformGeometry.RegionGeometry],
        activeRegionID: UUID,
        activeMarkerHitWidth: Double = 34
    ) -> Decision {
        guard x.isFinite, activeMarkerHitWidth.isFinite, activeMarkerHitWidth >= 0 else { return .seekWaveform }
        if let active = layouts.first(where: { $0.id == activeRegionID }) {
            let radius = activeMarkerHitWidth / 2
            if let sx = active.startX, abs(x - sx) <= radius { return .activeMarkerPriority }
            if let ex = active.endX, abs(x - ex) <= radius { return .activeMarkerPriority }
        }
        // Reverse order makes the visually topmost/latest rendered inactive region win
        // in an overlap. The active region is deliberately excluded from selection.
        for g in layouts.reversed() where g.id != activeRegionID {
            if let sx = g.shadeX, let w = g.shadeWidth, w > 0, x >= sx, x <= sx + w {
                return .selectRegion(g.id)
            }
        }
        return .seekWaveform
    }
}
