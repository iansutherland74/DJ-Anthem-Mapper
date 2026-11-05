import AppKit
import UniformTypeIdentifiers

// M3_02B7_SAVE_PANEL_PRESENTER
@MainActor
final class AnthemMapSavePanelPresenter {
    enum Result: Equatable {
        case selected(URL)
        case cancelled
        case unavailable
    }

    func present(
        preparedSave: AnthemMapSaveCoordinator.PreparedSave,
        completion: @escaping @MainActor (Result) -> Void
    ) {
        let configuration = AnthemMapSavePanelConfiguration.make(preparedSave: preparedSave)

        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
            completion(.unavailable)
            return
        }

        let panel = NSSavePanel()
        // M3_02B9_FIX1_DUPLICATE_EXTENSION
        let requiredSuffix = "." + configuration.requiredFileExtension.lowercased()
        let suggestedName = configuration.suggestedFileName
        if suggestedName.lowercased().hasSuffix(requiredSuffix) {
            panel.nameFieldStringValue = String(suggestedName.dropLast(requiredSuffix.count))
        } else {
            panel.nameFieldStringValue = suggestedName
        }
        panel.canCreateDirectories = configuration.canCreateDirectories
        panel.isExtensionHidden = configuration.isExtensionHidden
        panel.allowsOtherFileTypes = configuration.allowsOtherFileTypes

        if let contentType = UTType(filenameExtension: configuration.requiredFileExtension) {
            panel.allowedContentTypes = [contentType]
        }

        panel.beginSheetModal(for: window) { response in
            Task { @MainActor in
                guard response == .OK else {
                    completion(.cancelled)
                    return
                }
                guard let url = panel.url else {
                    completion(.unavailable)
                    return
                }
                completion(.selected(url))
            }
        }
    }
}
