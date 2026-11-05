import SwiftUI
import AppKit

@MainActor
final class AnthemAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApp.activate()
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldTerminate(
        _ sender: NSApplication
    ) -> NSApplication.TerminateReply {
        guard let bridge = AnthemMapLifecycleRegistry.shared.bridge else {
            return .terminateNow
        }

        switch bridge.requestTermination(
            reply: { allowTermination in
                sender.reply(
                    toApplicationShouldTerminate: allowTermination
                )
            }
        ) {
        case .terminateNow:
            return .terminateNow
        case .terminateLater:
            return .terminateLater
        case .terminateCancel:
            return .terminateCancel
        }
    }
}

@main
struct DJAnthemMapperApp: App {
    @NSApplicationDelegateAdaptor(AnthemAppDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup { MainShellView().preferredColorScheme(.dark) }
            .defaultSize(width: AnthemLayout.preferredWindowWidth, height: AnthemLayout.preferredWindowHeight)
            .windowStyle(.titleBar)
    }
}
