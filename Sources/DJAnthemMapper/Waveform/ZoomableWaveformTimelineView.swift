import SwiftUI

struct ZoomableWaveformTimelineView: View {
    let samples: [Float]
    let isLoading: Bool
    let errorMessage: String?
    @ObservedObject var playback: PlaybackController
    @ObservedObject var anthemRegion: AnthemRegionController

    private enum ZoomLevel: String, CaseIterable, Identifiable {
        case full = "Full Song"
        case s30 = "30s"
        case s15 = "15s"
        case s10 = "10s"
        case s5 = "5s"
        case s1 = "1s"
        case half = "0.5s"
        var id: String { rawValue }
        var seconds: Double? {
            switch self {
            case .full: return nil
            case .s30: return 30
            case .s15: return 15
            case .s10: return 10
            case .s5: return 5
            case .s1: return 1
            case .half: return 0.5
            }
        }
    }

    @State private var zoom: ZoomLevel = .full
    @State private var windowStart: Double = 0
    @State private var userHasPanned = false

    private var progress: Double {
        guard playback.duration > 0 else { return 0 }
        return min(1, max(0, playback.currentTime / playback.duration))
    }

    private var visibleDuration: Double {
        guard playback.duration > 0 else { return 0.001 }
        return min(playback.duration, zoom.seconds ?? playback.duration)
    }

    private var maxWindowStart: Double { max(0, playback.duration - visibleDuration) }
    private var windowEnd: Double { min(playback.duration, windowStart + visibleDuration) }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("WAVEFORM ZOOM")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(AnthemTheme.textMuted)
                Spacer()
                Text(zoom == .full ? "Entire track" : "Visible window: \(zoom.rawValue)")
                    .font(.caption)
                    .foregroundStyle(AnthemTheme.textSecondary)
            }

            HStack(spacing: 4) {
                ForEach(ZoomLevel.allCases) { level in
                    Button {
                        setZoom(level)
                    } label: {
                        Text(level.rawValue)
                            .font(.system(.callout, design: .rounded).weight(zoom == level ? .bold : .medium))
                            .foregroundStyle(zoom == level ? Color.white : AnthemTheme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(zoom == level ? AnthemTheme.actionBlue : Color.white.opacity(0.10))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(zoom == level ? AnthemTheme.anthemHighlight.opacity(0.95) : AnthemTheme.border, lineWidth: zoom == level ? 1.5 : 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Waveform zoom \(level.rawValue)")
                    .accessibilityValue(zoom == level ? "Selected" : "Not selected")
                }
                Spacer()
                Button { pan(by: -0.5) } label: { Label("Pan left", systemImage: "chevron.left") }
                    .labelStyle(.iconOnly)
                    .disabled(zoom == .full || windowStart <= 0)
                    .help("Pan earlier by half the visible window")
                Button { centreOn(playback.currentTime); userHasPanned = false } label: { Label("Centre playhead", systemImage: "scope") }
                    .labelStyle(.iconOnly)
                    .disabled(zoom == .full)
                    .help("Centre the visible window on the playhead")
                Button { pan(by: 0.5) } label: { Label("Pan right", systemImage: "chevron.right") }
                    .labelStyle(.iconOnly)
                    .disabled(zoom == .full || windowStart >= maxWindowStart)
                    .help("Pan later by half the visible window")
            }

            VStack(spacing: 2) {
                HStack {
                    Text(formatPrecise(windowStart))
                    Spacer()
                    Text(zoom == .full ? "FULL SONG" : "VISIBLE \(zoom.rawValue)")
                        .foregroundStyle(AnthemTheme.textMuted)
                    Spacer()
                    Text(formatPrecise(windowEnd))
                }
                .font(.system(.caption, design: .monospaced))

                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { index in
                        VStack(spacing: 2) {
                            Rectangle()
                                .fill(index == 0 || index == 6 ? AnthemTheme.textSecondary : AnthemTheme.border)
                                .frame(width: 1, height: index == 0 || index == 6 ? 8 : 5)
                            Text(formatRuler(windowStart + visibleDuration * Double(index) / 6.0))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(AnthemTheme.textMuted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityLabel("Visible waveform time ruler")
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 9).fill(AnthemTheme.waveformBackground)
                    if isLoading {
                        ProgressView("Building waveform…").frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMessage {
                        Text(errorMessage).font(.caption).foregroundStyle(.red).frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if samples.isEmpty {
                        Text("Waveform unavailable").font(.caption).foregroundStyle(AnthemTheme.textMuted).frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Canvas { context, size in
                            let visible = visibleSampleRange()
                            let pixelColumns = max(1, Int(size.width.rounded(.up)))
                            let midY = size.height / 2
                            for column in 0..<pixelColumns {
                                let a = visible.lowerBound + (visible.count * column / pixelColumns)
                                let b = visible.lowerBound + (visible.count * (column + 1) / pixelColumns)
                                let upper = max(a + 1, min(visible.upperBound, b))
                                var peak: Float = 0
                                if a < visible.upperBound {
                                    for index in a..<upper { peak = max(peak, samples[index]) }
                                }
                                let height = max(1, CGFloat(peak) * (size.height - 12))
                                let rect = CGRect(x: CGFloat(column), y: midY - height / 2, width: 1, height: height)
                                context.fill(Path(rect), with: .color(AnthemTheme.waveformBright.opacity(0.9)))
                            }
                        }

                        if visiblePlayheadRatio() >= 0 && visiblePlayheadRatio() <= 1 {
                            Rectangle().fill(AnthemTheme.actionBlue.opacity(0.16))
                                .frame(width: geometry.size.width * visiblePlayheadRatio())
                                .allowsHitTesting(false)
                            Rectangle().fill(AnthemTheme.anthemHighlight)
                                .frame(width: 2)
                                .offset(x: max(0, geometry.size.width * visiblePlayheadRatio() - 1))
                                .allowsHitTesting(false)
                        }
                    }
                    // PHASE_4B1_WAVEFORM_REGION_VISUALISATION
                    // FIX4B2B: visualisation is now provided by the interactive overlay above the waveform.
                    // PHASE_4B2_INTERACTIVE_ANTHEM_REGION_EDITING
                    // FIX4B2B_MARKER_VISIBILITY
                    // PHASE_4C2B_INACTIVE_REGIONS_RENDERING
                    // Read-only inactive regions sit beneath the certified active overlay.
                    InactiveAnthemRegionsOverlay(
                        controller: anthemRegion,
                        visibleStart: windowStart,
                        visibleDuration: visibleDuration
                    )
                    .allowsHitTesting(false)

                    InteractiveAnthemRegionOverlay(
                        controller: anthemRegion,
                        trackDuration: playback.duration,
                        visibleStart: windowStart,
                        visibleDuration: visibleDuration
                    )
                }
                .overlay { RoundedRectangle(cornerRadius: 9).stroke(AnthemTheme.border, lineWidth: 1) }
                .contentShape(Rectangle())
                // PHASE_4C2G_CLICK_TO_SELECT
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("anthemWaveform"))
                        .onChanged { value in
                            guard playback.duration > 0 else { return }
                            let viewport = WaveformViewport(start: windowStart, duration: visibleDuration, width: max(1, geometry.size.width))
                            let layouts = MultiRegionWaveformGeometry.layout(
                                regions: anthemRegion.collection.regions,
                                activeRegionID: anthemRegion.activeRegionID,
                                viewport: viewport
                            )
                            switch MultiRegionWaveformHitTesting.decision(
                                x: value.location.x,
                                layouts: layouts,
                                activeRegionID: anthemRegion.activeRegionID
                            ) {
                            case .activeMarkerPriority:
                                // The certified marker overlay owns this interaction.
                                break
                            case .selectRegion(let id):
                                if anthemRegion.selectRegion(id: id) {
                                    // Match the existing selector's playback-safety rule.
                                    playback.cancelRegionPlayback()
                                }
                            case .seekWaveform:
                                playback.seek(to: viewport.time(forX: value.location.x))
                            }
                        }
                )
            }
            .coordinateSpace(name: "anthemWaveform")
            .frame(height: 132)

            HStack {
                ProgressView(value: progress).progressViewStyle(.linear)
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(AnthemTheme.textSecondary)
                    .frame(width: 42, alignment: .trailing)
            }
        }
        .onAppear { normaliseWindow() }
        .onChange(of: playback.duration) { _, _ in normaliseWindow() }
        .onChange(of: playback.currentTime) { _, newTime in
            guard zoom != .full, !userHasPanned else { return }
            let edge = visibleDuration * 0.10
            if newTime < windowStart + edge || newTime > windowEnd - edge { centreOn(newTime) }
        }
    }

    private func setZoom(_ level: ZoomLevel) {
        zoom = level
        userHasPanned = false
        if level == .full { windowStart = 0 } else { centreOn(playback.currentTime) }
    }

    private func pan(by fraction: Double) {
        guard zoom != .full else { return }
        userHasPanned = true
        windowStart = min(maxWindowStart, max(0, windowStart + visibleDuration * fraction))
    }

    private func centreOn(_ time: Double) {
        windowStart = min(maxWindowStart, max(0, time - visibleDuration / 2))
    }

    private func normaliseWindow() {
        if zoom == .full { windowStart = 0 } else { centreOn(playback.currentTime) }
    }

    private func visibleSampleRange() -> Range<Int> {
        guard !samples.isEmpty, playback.duration > 0 else { return 0..<0 }
        let startRatio = min(1, max(0, windowStart / playback.duration))
        let endRatio = min(1, max(startRatio, windowEnd / playback.duration))
        let lower = min(samples.count - 1, Int((Double(samples.count) * startRatio).rounded(.down)))
        let upper = min(samples.count, max(lower + 1, Int((Double(samples.count) * endRatio).rounded(.up))))
        return lower..<upper
    }

    private func visiblePlayheadRatio() -> Double {
        let viewport = WaveformViewport(start: windowStart, duration: visibleDuration, width: 1)
        return viewport.ratio(forTime: playback.currentTime)
    }

    private func formatRuler(_ seconds: Double) -> String {
        guard seconds.isFinite, !seconds.isNaN, seconds >= 0 else { return "00:00" }
        if visibleDuration <= 1.0 {
            let ms = Int64((seconds * 1000).rounded())
            return String(format: "%02lld.%03lld", (ms / 1000) % 60, ms % 1000)
        }
        if visibleDuration <= 30.0 {
            let tenths = Int64((seconds * 10).rounded())
            return String(format: "%02lld:%02lld.%01lld", tenths / 600, (tenths / 10) % 60, tenths % 10)
        }
        let total = Int64(seconds.rounded())
        return String(format: "%02lld:%02lld", total / 60, total % 60)
    }

    private func formatPrecise(_ seconds: Double) -> String {
        guard seconds.isFinite, !seconds.isNaN, seconds >= 0 else { return "00:00.000" }
        let ms = Int64((seconds * 1000).rounded())
        return String(format: "%02lld:%02lld.%03lld", ms / 60000, (ms / 1000) % 60, ms % 1000)
    }
}
