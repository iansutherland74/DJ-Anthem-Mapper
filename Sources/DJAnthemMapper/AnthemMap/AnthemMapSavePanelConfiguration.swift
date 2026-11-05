import Foundation

// M3_02B6_SAVE_PANEL_CONFIGURATION
struct AnthemMapSavePanelConfiguration: Equatable, Sendable {
    let suggestedFileName: String
    let requiredFileExtension: String
    let canCreateDirectories: Bool
    let isExtensionHidden: Bool
    let allowsOtherFileTypes: Bool

    static func make(
        preparedSave: AnthemMapSaveCoordinator.PreparedSave
    ) -> Self {
        Self(
            suggestedFileName: preparedSave.suggestedFileName,
            requiredFileExtension: AnthemMapSuggestedFileName.fileExtension,
            canCreateDirectories: true,
            isExtensionHidden: false,
            allowsOtherFileTypes: false
        )
    }
}
