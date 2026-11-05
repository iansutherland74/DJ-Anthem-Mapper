import XCTest
@testable import DJAnthemMapper

final class EditorShortcutDecisionTests: XCTestCase {
    func testSpaceTogglesPlaybackWhenNotEditingAndPlayable() {
        XCTAssertEqual(EditorShortcutDecision.spaceAction(isEditingText: false, canPlay: true), .togglePlayback)
    }
    func testSpaceIgnoredWhileEditingText() {
        XCTAssertEqual(EditorShortcutDecision.spaceAction(isEditingText: true, canPlay: true), .ignored)
    }
    func testSpaceIgnoredWithoutPlayableMedia() {
        XCTAssertEqual(EditorShortcutDecision.spaceAction(isEditingText: false, canPlay: false), .ignored)
    }
    func testEditingProtectionWinsWhenNothingPlayable() {
        XCTAssertEqual(EditorShortcutDecision.spaceAction(isEditingText: true, canPlay: false), .ignored)
    }
}
