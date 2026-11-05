import SwiftUI
import AppKit

final class AnthemAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApp.activate()
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
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
