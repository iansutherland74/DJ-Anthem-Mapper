import Foundation

// PHASE_4BH2_CENTRALISED_WAVEFORM_COORDINATES
struct WaveformViewport: Equatable, Sendable {
    let start: TimeInterval
    let duration: TimeInterval
    let width: Double

    var end: TimeInterval { start + duration }
    var isValid: Bool {
        start.isFinite && duration.isFinite && width.isFinite && start >= 0 && duration > 0 && width > 0
    }

    func clampedX(_ x: Double) -> Double {
        guard isValid, x.isFinite else { return 0 }
        return min(width, max(0, x))
    }

    func clampedTime(_ time: TimeInterval) -> TimeInterval {
        guard isValid, time.isFinite else { return start }
        return min(end, max(start, time))
    }

    func time(forX x: Double) -> TimeInterval {
        guard isValid else { return start }
        return start + duration * (clampedX(x) / width)
    }

    func x(forTime time: TimeInterval) -> Double {
        guard isValid else { return 0 }
        return ((clampedTime(time) - start) / duration) * width
    }

    func visibleX(forTime time: TimeInterval) -> Double? {
        guard isValid, time.isFinite, time >= start, time <= end else { return nil }
        return x(forTime: time)
    }

    func ratio(forTime time: TimeInterval) -> Double {
        guard isValid else { return 0 }
        return (time - start) / duration
    }
}
