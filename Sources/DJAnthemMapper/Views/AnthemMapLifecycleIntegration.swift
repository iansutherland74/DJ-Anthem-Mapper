import AppKit
import SwiftUI

@MainActor
final class AnthemMapLifecycleStateSource {
    private var sessionProvider: (@MainActor () -> AnthemMapSession?)?
    private var snapshotProvider: (@MainActor () -> AnthemRegionSnapshot?)?
    private var newWorkspaceContentProvider: (@MainActor () -> Bool)?
    private var mediaURLProvider: (@MainActor () -> URL?)?
    private var durationProvider: (@MainActor () -> TimeInterval)?
    private var replacementSessionInstaller:
        (@MainActor (AnthemMapSession) -> Void)?

    func makeProvider() -> AnthemMapLifecycleAppBridge.StateProvider {
        AnthemMapLifecycleAppBridge.StateProvider(
            session: { [weak self] in
                self?.sessionProvider?()
            },
            currentSnapshot: { [weak self] in
                self?.snapshotProvider?()
            },
            hasUnsavedNewWorkspaceContent: { [weak self] in
                self?.newWorkspaceContentProvider?() ?? false
            },
            mediaURL: { [weak self] in
                self?.mediaURLProvider?()
            },
            trackDuration: { [weak self] in
                self?.durationProvider?() ?? 0
            },
            installReplacementSession: { [weak self] session in
                self?.replacementSessionInstaller?(session)
            }
        )
    }

    func configure(
        session: @escaping @MainActor () -> AnthemMapSession?,
        currentSnapshot: @escaping @MainActor () -> AnthemRegionSnapshot?,
        hasUnsavedNewWorkspaceContent:
            @escaping @MainActor () -> Bool,
        mediaURL: @escaping @MainActor () -> URL?,
        trackDuration: @escaping @MainActor () -> TimeInterval,
        installReplacementSession:
            @escaping @MainActor (AnthemMapSession) -> Void
    ) {
        sessionProvider = session
        snapshotProvider = currentSnapshot
        newWorkspaceContentProvider = hasUnsavedNewWorkspaceContent
        mediaURLProvider = mediaURL
        durationProvider = trackDuration
        replacementSessionInstaller = installReplacementSession
    }

    func clear() {
        sessionProvider = nil
        snapshotProvider = nil
        newWorkspaceContentProvider = nil
        mediaURLProvider = nil
        durationProvider = nil
        replacementSessionInstaller = nil
    }
}

@MainActor
final class AnthemMapLifecycleRegistry {
    static let shared = AnthemMapLifecycleRegistry()

    private(set) weak var bridge: AnthemMapLifecycleAppBridge?

    private init() {}

    func install(_ bridge: AnthemMapLifecycleAppBridge) {
        self.bridge = bridge
    }

    func uninstall(_ bridge: AnthemMapLifecycleAppBridge) {
        guard self.bridge === bridge else {
            return
        }

        self.bridge = nil
    }
}

struct AnthemMapLifecycleWindowBridgeView: NSViewRepresentable {
    @ObservedObject var bridge: AnthemMapLifecycleAppBridge

    func makeCoordinator() -> Coordinator {
        Coordinator(bridge: bridge)
    }

    func makeNSView(context: Context) -> WindowProbeView {
        let view = WindowProbeView()

        view.onWindowChange = { [weak coordinator = context.coordinator] window in
            coordinator?.update(window: window)
        }

        context.coordinator.update(window: view.window)

        return view
    }

    func updateNSView(
        _ nsView: WindowProbeView,
        context: Context
    ) {
        context.coordinator.update(window: nsView.window)
    }

    static func dismantleNSView(
        _ nsView: WindowProbeView,
        coordinator: Coordinator
    ) {
        nsView.onWindowChange = nil
        coordinator.detach()
    }

    @MainActor
    final class Coordinator {
        private let bridge: AnthemMapLifecycleAppBridge
        private let attachment: AnthemMapLifecycleWindowAttachment
        private weak var attachedWindow: NSWindow?

        init(bridge: AnthemMapLifecycleAppBridge) {
            self.bridge = bridge

            attachment = AnthemMapLifecycleWindowAttachment {
                [weak bridge] replay in

                guard let bridge else {
                    return false
                }

                return bridge.shouldAllowClose(
                    requestReplay: {
                        Task { @MainActor in
                            await Task.yield()
                            replay()
                        }
                    }
                )
            }
        }

        func update(window: NSWindow?) {
            guard let window else {
                detach()
                return
            }

            if attachedWindow === window,
               attachment.isAttached {
                return
            }

            attachment.detach()
            attachedWindow = nil

            if attachment.attach(to: window) {
                attachedWindow = window
            }
        }

        func detach() {
            attachment.detach()
            attachedWindow = nil
        }
    }

    @MainActor
    final class WindowProbeView: NSView {
        var onWindowChange: (@MainActor (NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindowChange?(window)
        }
    }
}
