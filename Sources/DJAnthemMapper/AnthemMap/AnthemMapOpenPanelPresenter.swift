import AppKit
import UniformTypeIdentifiers

// M3_03E_OPEN_PANEL_PRESENTER
@MainActor
final class AnthemMapOpenPanelPresenter {
    enum Result: Equatable {
        case selected(URL)
        case cancelled
        case unavailable
    }

    func present(completion: @escaping @MainActor (Result) -> Void) {
        let configuration = AnthemMapOpenPanelConfiguration.make()
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
            completion(.unavailable)
            return
        }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = configuration.allowsMultipleSelection
        panel.canChooseFiles = configuration.canChooseFiles
        panel.canChooseDirectories = configuration.canChooseDirectories
        guard let contentType = UTType(filenameExtension: configuration.allowedFileExtension) else {
            completion(.unavailable)
            return
        }
        panel.allowedContentTypes = [contentType]
        panel.beginSheetModal(for: window) { response in
            Task { @MainActor in
                guard response == .OK else { completion(.cancelled); return }
                guard let url = panel.url else { completion(.unavailable); return }
                completion(.selected(url))
            }
        }
    }
}
