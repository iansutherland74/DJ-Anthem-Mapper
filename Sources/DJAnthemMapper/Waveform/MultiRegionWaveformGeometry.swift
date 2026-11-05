import Foundation

// PHASE_4C2A_MULTI_REGION_WAVEFORM_GEOMETRY
struct MultiRegionWaveformGeometry {
    struct RegionGeometry: Equatable, Sendable, Identifiable {
        let id: UUID
        let isActive: Bool
        let startX: Double?
        let endX: Double?
        let shadeX: Double?
        let shadeWidth: Double?

        var hasVisibleShading: Bool {
            guard let shadeWidth else { return false }
            return shadeWidth > 0
        }
    }

    static func layout(
        regions: [AnthemRegionItem],
        activeRegionID: UUID,
        viewport: WaveformViewport
    ) -> [RegionGeometry] {
        regions.map { item in
            let geometry = AnthemRegionOverlayGeometry.layout(
                start: item.region.start,
                end: item.region.end,
                viewport: viewport
            )

            // Incomplete/invalid regions may have individual marker positions in the
            // single-region editor, but they must not create multi-region shading.
            guard item.region.isValid else {
                return RegionGeometry(
                    id: item.id,
                    isActive: item.id == activeRegionID,
                    startX: geometry.startX,
                    endX: geometry.endX,
                    shadeX: nil,
                    shadeWidth: nil
                )
            }

            return RegionGeometry(
                id: item.id,
                isActive: item.id == activeRegionID,
                startX: geometry.startX,
                endX: geometry.endX,
                shadeX: geometry.shadeX,
                shadeWidth: geometry.shadeWidth
            )
        }
    }
}
