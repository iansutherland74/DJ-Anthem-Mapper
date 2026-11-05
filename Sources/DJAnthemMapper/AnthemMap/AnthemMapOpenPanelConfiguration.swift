import Foundation

// M3_03E_OPEN_PANEL_CONFIGURATION
struct AnthemMapOpenPanelConfiguration: Equatable, Sendable {
    let allowedFileExtension: String
    let allowsMultipleSelection: Bool
    let canChooseFiles: Bool
    let canChooseDirectories: Bool

    static func make() -> AnthemMapOpenPanelConfiguration {
        AnthemMapOpenPanelConfiguration(
            allowedFileExtension: AnthemMapSuggestedFileName.fileExtension,
            allowsMultipleSelection: false,
            canChooseFiles: true,
            canChooseDirectories: false
        )
    }
}
