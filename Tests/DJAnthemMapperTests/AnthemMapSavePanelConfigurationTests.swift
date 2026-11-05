import Foundation
import XCTest
@testable import DJAnthemMapper

final class AnthemMapSavePanelConfigurationTests: XCTestCase {
    @MainActor func testConfigurationUsesPreparedSuggestedFilename(){ XCTAssertEqual(makeConfiguration(suggestedFileName:"Mr Brightside.anthemmap").suggestedFileName,"Mr Brightside.anthemmap") }
    @MainActor func testRequiredExtensionIsAnthemMap(){ XCTAssertEqual(makeConfiguration().requiredFileExtension,"anthemmap") }
    @MainActor func testRequiredExtensionMatchesB4Constant(){ XCTAssertEqual(makeConfiguration().requiredFileExtension,AnthemMapSuggestedFileName.fileExtension) }
    @MainActor func testDirectoriesCanBeCreated(){ XCTAssertTrue(makeConfiguration().canCreateDirectories) }
    @MainActor func testExtensionIsVisible(){ XCTAssertFalse(makeConfiguration().isExtensionHidden) }
    @MainActor func testOtherFileTypesAreNotAllowed(){ XCTAssertFalse(makeConfiguration().allowsOtherFileTypes) }
    @MainActor func testConfigurationPreservesFilenameSpaces(){ XCTAssertEqual(makeConfiguration(suggestedFileName:"Live Forever Wembley.anthemmap").suggestedFileName,"Live Forever Wembley.anthemmap") }
    @MainActor func testConfigurationPreservesMultipleDots(){ XCTAssertEqual(makeConfiguration(suggestedFileName:"Oasis.Live.1996.anthemmap").suggestedFileName,"Oasis.Live.1996.anthemmap") }
    @MainActor func testConfigurationCreationDoesNotMutatePreparedSave(){ let p=makePreparedSave(suggestedFileName:"Track.anthemmap"); let before=p; _=AnthemMapSavePanelConfiguration.make(preparedSave:p); XCTAssertEqual(p,before) }
    @MainActor func testEmptySuggestedFilenameIsPreservedWithoutConfigurationMutation(){ let c=makeConfiguration(suggestedFileName:""); XCTAssertEqual(c.suggestedFileName,""); XCTAssertEqual(c.requiredFileExtension,"anthemmap") }
    @MainActor func testFilenameAlreadyUsingAnthemMapExtensionIsPreservedExactly(){ XCTAssertEqual(makeConfiguration(suggestedFileName:"Existing.anthemmap").suggestedFileName,"Existing.anthemmap") }
    @MainActor func testUppercaseFilenameIsPreservedExactly(){ XCTAssertEqual(makeConfiguration(suggestedFileName:"ANTHEM MAP.anthemmap").suggestedFileName,"ANTHEM MAP.anthemmap") }
    @MainActor func testLeadingAndTrailingFilenameSpacesAreNotSilentlyRewritten(){ XCTAssertEqual(makeConfiguration(suggestedFileName:"  Track Name.anthemmap  ").suggestedFileName,"  Track Name.anthemmap  ") }
    @MainActor func testFilenameContainingMultipleExtensionLikeSegmentsIsPreserved(){ XCTAssertEqual(makeConfiguration(suggestedFileName:"Track.mp3.backup.anthemmap").suggestedFileName,"Track.mp3.backup.anthemmap") }
    @MainActor func testConfigurationDoesNotDeriveExtensionFromSuggestedFilename(){ let c=makeConfiguration(suggestedFileName:"Unexpected.txt"); XCTAssertEqual(c.suggestedFileName,"Unexpected.txt"); XCTAssertEqual(c.requiredFileExtension,AnthemMapSuggestedFileName.fileExtension) }
    @MainActor func testTwoConfigurationsFromSamePreparedSaveAreEqual(){ let p=makePreparedSave(suggestedFileName:"Track.anthemmap"); XCTAssertEqual(AnthemMapSavePanelConfiguration.make(preparedSave:p),AnthemMapSavePanelConfiguration.make(preparedSave:p)) }

    @MainActor private func makeConfiguration(suggestedFileName:String="Test Track.anthemmap") -> AnthemMapSavePanelConfiguration { AnthemMapSavePanelConfiguration.make(preparedSave:makePreparedSave(suggestedFileName:suggestedFileName)) }
    @MainActor private func makePreparedSave(suggestedFileName:String="Test Track.anthemmap") -> AnthemMapSaveCoordinator.PreparedSave { AnthemMapSaveCoordinator.PreparedSave(document:makeDocument(),suggestedFileName:suggestedFileName) }
    private func makeDocument() -> AnthemMapDocument {
        let track=AnthemMapDocument.TrackIdentity(fileName:"Test Track.mp3",fileSize:UInt64(4_096),durationMilliseconds:Int64(300_000))
        let region=AnthemMapDocument.Region(id:UUID(),slot:0,startMilliseconds:Int64(10_000),endMilliseconds:Int64(20_000))
        return AnthemMapDocument(track:track,regions:[region])
    }
}
