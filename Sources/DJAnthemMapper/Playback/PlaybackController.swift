import AVFoundation
import Combine
import Foundation

@MainActor
final class PlaybackController: ObservableObject {
    enum State: Equatable {
        case idle
        case preparing
        case ready
        case playing
        case paused
        case failed(String)

        var label: String {
            switch self {
            case .idle: return "Idle"
            case .preparing: return "Preparing"
            case .ready: return "Ready"
            case .playing: return "Playing"
            case .paused: return "Paused"
            case .failed: return "Failed"
            }
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var errorMessage: String?

    var isPlaying: Bool { state == .playing }
    var canPlay: Bool {
        switch state {
        case .ready, .paused, .playing: return true
        default: return false
        }
    }

    private let player = AVPlayer()
    private var statusObservation: NSKeyValueObservation?
    private var periodicTimeObserver: Any?
    private var regionBoundaryObserver: Any?

    // PHASE_4BH1_EXPLICIT_PLAYBACK_MODE
    enum BoundedPlaybackMode: Equatable, Sendable {
        case region
        case loop
        case startAudition
        case endAudition
        case preRoll
        case postRoll
    }

    private struct BoundedPlayback: Equatable, Sendable {
        var mode: BoundedPlaybackMode
        var start: TimeInterval
        var end: TimeInterval
    }

    private var activeBoundedPlayback: BoundedPlayback?
    @Published private(set) var boundedPlaybackMode: BoundedPlaybackMode?
    var isPlayingRegion: Bool { boundedPlaybackMode != nil }
    var isLoopingRegion: Bool { boundedPlaybackMode == .loop }
    private var endObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?
    private var stallObserver: NSObjectProtocol?
    private var generation = 0
    private var actionWhenReady: (@MainActor () -> Void)?
    private var fadeTask: Task<Void, Never>?

    func whenReady(_ action: @escaping @MainActor () -> Void) {
        if state == .ready || state == .paused || state == .playing {
            action()
        } else {
            actionWhenReady = action
        }
    }

    func beginExternalPreparation() {
        reset()
        state = .preparing
        errorMessage = nil
    }

    func failExternalPreparation(_ message: String) {
        fail(message)
    }

    func prepare(url: URL) {
        reset()
        generation += 1
        let expectedGeneration = generation
        state = .preparing
        errorMessage = nil

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)

        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self, weak item] _, _ in
            guard let self, let item else { return }
            Task { @MainActor in
                guard expectedGeneration == self.generation,
                      self.player.currentItem === item else { return }
                switch item.status {
                case .readyToPlay:
                    self.updateDuration()
                    if self.state == .preparing { self.state = .ready }
                    let readyAction = self.actionWhenReady
                    self.actionWhenReady = nil
                    readyAction?()
                case .failed:
                    self.fail(item.error?.localizedDescription ?? "Playback preparation failed.")
                case .unknown:
                    break
                @unknown default:
                    self.fail("AVPlayer returned an unknown playback status.")
                }
            }
        }

        installTimeObserver(generation: expectedGeneration)
        installNotifications(for: item, generation: expectedGeneration)
    }

    func play() {
        guard canPlay else { return }
        if duration > 0, currentTime >= duration - 0.05 {
            seek(to: 0)
        }
        player.play()
        state = .playing
        errorMessage = nil
    }

    func pause() {
        removeRegionBoundaryObserver()
        activeBoundedPlayback = nil
        boundedPlaybackMode = nil
        guard player.currentItem != nil else { return }
        player.pause()
        if state == .playing { state = .paused }
    }

    func togglePlayback() { isPlaying ? pause() : play() }

    func skipBackward(seconds: TimeInterval = 15) {
        guard seconds > 0 else { return }
        seek(to: max(0, currentTime - seconds))
    }

    func skipForward(seconds: TimeInterval = 15) {
        guard seconds > 0 else { return }
        let target = duration > 0 ? min(duration, currentTime + seconds) : currentTime + seconds
        seek(to: target)
    }

    static func validRegionBounds(start: TimeInterval, end: TimeInterval, duration: TimeInterval) -> Bool {
        start.isFinite && end.isFinite && duration.isFinite && duration > 0 && start >= 0 && start < end && end <= duration
    }

    func playRegion(start: TimeInterval, end: TimeInterval) {
        startBoundedPlayback(mode: .region, start: start, end: end)
    }

    // PHASE_4B3D_PRE_POST_ROLL
    func preRollStart(_ markerTime: TimeInterval, seconds: TimeInterval) {
        guard markerTime.isFinite, duration.isFinite, duration > 0, seconds > 0 else { return }
        startBoundedPlayback(mode: .preRoll, start: max(0, markerTime - seconds), end: min(duration, markerTime))
    }

    func postRollEnd(_ markerTime: TimeInterval, seconds: TimeInterval) {
        guard markerTime.isFinite, duration.isFinite, duration > 0, seconds > 0 else { return }
        startBoundedPlayback(mode: .postRoll, start: max(0, markerTime), end: min(duration, markerTime + seconds))
    }

    // PHASE_4B3C_END_AUDITION
    func auditionEnd(_ markerTime: TimeInterval, context: TimeInterval = 2.0) {
        guard markerTime.isFinite, duration.isFinite, duration > 0, context > 0 else { return }
        startBoundedPlayback(mode: .endAudition, start: max(0, markerTime - context), end: min(duration, markerTime + context))
    }

    // PHASE_4B3B_START_AUDITION
    func auditionStart(_ markerTime: TimeInterval, context: TimeInterval = 2.0) {
        guard markerTime.isFinite, duration.isFinite, duration > 0, context > 0 else { return }
        startBoundedPlayback(mode: .startAudition, start: max(0, markerTime - context), end: min(duration, markerTime + context))
    }

    // PHASE_4B3A_LOOP_REGION
    func loopRegion(start: TimeInterval, end: TimeInterval) {
        startBoundedPlayback(mode: .loop, start: start, end: end)
    }

    // PHASE_4BH1_EXPLICIT_PLAYBACK_MODE
    private func startBoundedPlayback(mode: BoundedPlaybackMode, start: TimeInterval, end: TimeInterval) {
        guard Self.validRegionBounds(start: start, end: end, duration: duration) else { return }
        cancelRegionPlayback()
        activeBoundedPlayback = BoundedPlayback(mode: mode, start: start, end: end)
        boundedPlaybackMode = mode
        seek(to: start) { [weak self] in
            guard let self, let active = self.activeBoundedPlayback,
                  active.mode == mode, active.start == start else { return }
            self.installRegionBoundaryObserver(end: active.end)
            self.player.play()
            self.state = .playing
        }
    }

    // FIX4B3A1_LIVE_START_LOOP_BOUNDARY
    func updateActiveRegionStart(_ start: TimeInterval) {
        guard var active = activeBoundedPlayback, active.mode == .loop,
              start.isFinite, duration.isFinite,
              start >= 0, start < active.end, start < duration else { return }
        active.start = start
        activeBoundedPlayback = active
    }

    // FIX4B2E_LIVE_END_PLAYBACK_BOUNDARY
    func updateActiveRegionEnd(_ end: TimeInterval) {
        guard var active = activeBoundedPlayback,
              active.mode == .region || active.mode == .loop,
              end.isFinite, duration.isFinite,
              end > active.start, end <= duration else { return }
        active.end = end
        activeBoundedPlayback = active
        if currentTime >= end {
            finishBoundedPlayback(at: end)
            return
        }
        installRegionBoundaryObserver(end: end)
    }

    func cancelRegionPlayback() {
        removeRegionBoundaryObserver()
        activeBoundedPlayback = nil
        boundedPlaybackMode = nil
        player.pause()
        if player.currentItem != nil { state = .paused }
    }

    private func installRegionBoundaryObserver(end: TimeInterval) {
        removeRegionBoundaryObserver()
        let time = CMTime(seconds: end, preferredTimescale: 1_000)
        regionBoundaryObserver = player.addBoundaryTimeObserver(forTimes: [NSValue(time: time)], queue: .main) { [weak self] in
            Task { @MainActor in
                self?.finishBoundedPlayback(at: end)
            }
        }
    }

    private func finishBoundedPlayback(at observedEnd: TimeInterval) {
        guard let active = activeBoundedPlayback else { return }

        if active.mode == .loop,
           Self.validRegionBounds(start: active.start, end: active.end, duration: duration) {
            removeRegionBoundaryObserver()
            seek(to: active.start) { [weak self] in
                guard let self, let current = self.activeBoundedPlayback,
                      current.mode == .loop else { return }
                self.installRegionBoundaryObserver(end: current.end)
                self.player.play()
                self.state = .playing
            }
            return
        }

        let finalEnd = active.end
        player.pause()
        removeRegionBoundaryObserver()
        activeBoundedPlayback = nil
        boundedPlaybackMode = nil
        seek(to: finalEnd) { [weak self] in
            guard let self else { return }
            self.currentTime = finalEnd
            self.state = .paused
        }
    }

    private func removeRegionBoundaryObserver() {
        guard let observer = regionBoundaryObserver else { return }
        player.removeTimeObserver(observer)
        regionBoundaryObserver = nil
    }
    func seek(
        to seconds: TimeInterval,
        completion: (@MainActor () -> Void)? = nil
    ) {
        guard player.currentItem != nil, seconds.isFinite, !seconds.isNaN else {
            completion?()
            return
        }
        var target = max(0, seconds)
        if duration > 0 { target = min(duration, target) }
        currentTime = target
        player.currentItem?.cancelPendingSeeks()
        player.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] finished in
            Task { @MainActor in
                guard let self else { return }
                if finished { self.currentTime = target }
                completion?()
            }
        }
    }

    func fadeOutForStreamSwitch(
        duration: TimeInterval = 0.25,
        completion: @escaping @MainActor () -> Void
    ) {
        fadeTask?.cancel()
        let startingVolume = player.volume
        guard duration > 0, startingVolume > 0 else {
            player.volume = 0
            player.pause()
            completion()
            return
        }
        let steps = 10
        let stepNanoseconds = UInt64(max(0.001, duration / Double(steps)) * 1_000_000_000)

        fadeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for step in 1...steps {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: stepNanoseconds)
                if Task.isCancelled { return }
                let progress = Float(step) / Float(steps)
                self.player.volume = max(0, startingVolume * (1 - progress))
            }
            self.player.volume = 0
            self.player.pause()
            self.fadeTask = nil
            completion()
        }
    }

    func fadeInAfterStreamSwitch(duration: TimeInterval = 0.25) {
        fadeTask?.cancel()
        player.volume = 0
        player.play()
        state = .playing
        errorMessage = nil
        guard duration > 0 else {
            player.volume = 1
            return
        }

        let steps = 10
        let stepNanoseconds = UInt64(max(0.001, duration / Double(steps)) * 1_000_000_000)
        fadeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for step in 1...steps {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: stepNanoseconds)
                if Task.isCancelled { return }
                self.player.volume = min(1, Float(step) / Float(steps))
            }
            self.player.volume = 1
            self.fadeTask = nil
        }
    }

    func stop() {
        guard player.currentItem != nil else { reset(); return }
        removeRegionBoundaryObserver()
        activeBoundedPlayback = nil
        boundedPlaybackMode = nil
        player.pause()
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = 0
        state = .ready
    }

    func reset() {
        removeRegionBoundaryObserver()
        activeBoundedPlayback = nil
        boundedPlaybackMode = nil
        generation += 1
        actionWhenReady = nil
        fadeTask?.cancel()
        fadeTask = nil
        player.volume = 1
        player.pause()
        statusObservation?.invalidate()
        statusObservation = nil
        removeTimeObserver()
        removeNotifications()
        player.replaceCurrentItem(with: nil)
        currentTime = 0
        duration = 0
        errorMessage = nil
        state = .idle
    }

    private func updateDuration() {
        guard let seconds = player.currentItem?.duration.seconds,
              seconds.isFinite, !seconds.isNaN, seconds > 0 else { return }
        duration = seconds
    }

    private func fail(_ message: String) {
        actionWhenReady = nil
        fadeTask?.cancel()
        fadeTask = nil
        player.volume = 1
        player.pause()
        errorMessage = message
        state = .failed(message)
    }

    private func installTimeObserver(generation expectedGeneration: Int) {
        removeTimeObserver()
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        periodicTimeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            Task { @MainActor in
                guard expectedGeneration == self.generation else { return }
                let seconds = time.seconds
                guard seconds.isFinite, !seconds.isNaN else { return }
                self.currentTime = max(0, seconds)
                if self.duration == 0 { self.updateDuration() }

                // FIX8 Phase 3A periodic END failsafe.
                // The boundary observer remains primary; this catches a missed/skipped boundary.
                if let active = self.activeBoundedPlayback,
                   self.currentTime >= active.end {
                    self.finishBoundedPlayback(at: active.end)
                }
            }
        }
    }

    private func removeTimeObserver() {
        guard let observer = periodicTimeObserver else { return }
        player.removeTimeObserver(observer)
        periodicTimeObserver = nil
    }

    private func installNotifications(for item: AVPlayerItem, generation expectedGeneration: Int) {
        removeNotifications()
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard expectedGeneration == self.generation else { return }
                if self.duration > 0 { self.currentTime = self.duration }
                self.state = .paused
            }
        }
        failureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main
        ) { [weak self] note in
            guard let self else { return }
            let error = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            Task { @MainActor in
                guard expectedGeneration == self.generation else { return }
                self.fail(error?.localizedDescription ?? "Playback failed before reaching the end of the track.")
            }
        }
        stallObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled, object: item, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard expectedGeneration == self.generation else { return }
                self.fail("Playback stalled and could not continue.")
            }
        }
    }

    private func removeNotifications() {
        [endObserver, failureObserver, stallObserver].compactMap { $0 }.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        endObserver = nil
        failureObserver = nil
        stallObserver = nil
    }
}
