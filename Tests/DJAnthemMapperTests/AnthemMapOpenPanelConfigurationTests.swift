import XCTest
@testable import DJAnthemMapper

final class AnthemMapOpenPanelConfigurationTests: XCTestCase {
    func testExtensionIsAnthemMap() {
        XCTAssertEqual(AnthemMapOpenPanelConfiguration.make().allowedFileExtension, "anthemmap")
    }

    func testExtensionUsesSharedSuggestedFilenameConstant() {
        XCTAssertEqual(
            AnthemMapOpenPanelConfiguration.make().allowedFileExtension,
            AnthemMapSuggestedFileName.fileExtension
        )
    }

    func testFilesCanBeSelected() {
        XCTAssertTrue(AnthemMapOpenPanelConfiguration.make().canChooseFiles)
    }

    func testDirectoriesCannotBeSelected() {
        XCTAssertFalse(AnthemMapOpenPanelConfiguration.make().canChooseDirectories)
    }

    func testMultipleSelectionIsDisabled() {
        XCTAssertFalse(AnthemMapOpenPanelConfiguration.make().allowsMultipleSelection)
    }

    func testRepeatedConfigurationCreationIsDeterministic() {
        XCTAssertEqual(
            AnthemMapOpenPanelConfiguration.make(),
            AnthemMapOpenPanelConfiguration.make()
        )
    }
}
