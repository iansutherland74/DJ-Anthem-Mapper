import XCTest
@testable import DJAnthemMapper

final class PrecisionFieldInputSanitiserTests: XCTestCase {
    func testSpaceRestoresPreviousValue() {
        XCTAssertEqual(PrecisionFieldInputSanitiser.sanitise(oldValue: "31", newValue: " ", maximumDigits: 2), "31")
    }
    func testLetterRestoresPreviousValue() {
        XCTAssertEqual(PrecisionFieldInputSanitiser.sanitise(oldValue: "250", newValue: "x", maximumDigits: 3), "250")
    }
    func testIntentionalEmptyValueIsAllowed() {
        XCTAssertEqual(PrecisionFieldInputSanitiser.sanitise(oldValue: "31", newValue: "", maximumDigits: 2), "")
    }
    func testNumericInputIsPreserved() {
        XCTAssertEqual(PrecisionFieldInputSanitiser.sanitise(oldValue: "31", newValue: "42", maximumDigits: 2), "42")
    }
    func testMixedInputRetainsDigits() {
        XCTAssertEqual(PrecisionFieldInputSanitiser.sanitise(oldValue: "31", newValue: "1a2", maximumDigits: 2), "12")
    }
    func testInputIsLimitedToMaximumDigits() {
        XCTAssertEqual(PrecisionFieldInputSanitiser.sanitise(oldValue: "01", newValue: "123", maximumDigits: 2), "12")
    }
    func testInvalidInputWithEmptyPreviousValueRemainsEmpty() {
        XCTAssertEqual(PrecisionFieldInputSanitiser.sanitise(oldValue: "", newValue: " ", maximumDigits: 2), "")
    }
}
