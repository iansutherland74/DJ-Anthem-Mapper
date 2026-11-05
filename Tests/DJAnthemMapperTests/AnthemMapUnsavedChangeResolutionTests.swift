import XCTest
@testable import DJAnthemMapper

final class AnthemMapUnsavedChangeResolutionTests: XCTestCase {
    private let resolution = AnthemMapUnsavedChangeResolution()

    func testSaveChoiceReturnsSaveThenProceed() {
        XCTAssertEqual(resolution.resolve(.save), .saveThenProceed)
    }

    func testDiscardChoiceReturnsDiscardAndProceed() {
        XCTAssertEqual(resolution.resolve(.discard), .discardAndProceed)
    }

    func testCancelChoiceReturnsCancel() {
        XCTAssertEqual(resolution.resolve(.cancel), .cancel)
    }

    func testNilChoiceReturnsCancel() {
        XCTAssertEqual(resolution.resolve(nil), .cancel)
    }

    func testResolutionIsDeterministicForEveryChoice() {
        XCTAssertEqual(resolution.resolve(.save), resolution.resolve(.save))
        XCTAssertEqual(resolution.resolve(.discard), resolution.resolve(.discard))
        XCTAssertEqual(resolution.resolve(.cancel), resolution.resolve(.cancel))
        XCTAssertEqual(resolution.resolve(nil), resolution.resolve(nil))
    }

    func testRepeatedResolutionPreservesEachInstruction() {
        for _ in 0..<3 {
            XCTAssertEqual(resolution.resolve(.save), .saveThenProceed)
            XCTAssertEqual(resolution.resolve(.discard), .discardAndProceed)
            XCTAssertEqual(resolution.resolve(.cancel), .cancel)
            XCTAssertEqual(resolution.resolve(nil), .cancel)
        }
    }

    func testChoiceValuesHaveExpectedEqualitySemantics() {
        XCTAssertEqual(AnthemMapUnsavedChangeResolution.Choice.save, .save)
        XCTAssertEqual(AnthemMapUnsavedChangeResolution.Choice.discard, .discard)
        XCTAssertEqual(AnthemMapUnsavedChangeResolution.Choice.cancel, .cancel)
        XCTAssertNotEqual(AnthemMapUnsavedChangeResolution.Choice.save, .discard)
    }

    func testInstructionValuesHaveExpectedEqualitySemantics() {
        XCTAssertEqual(AnthemMapUnsavedChangeResolution.Instruction.saveThenProceed, .saveThenProceed)
        XCTAssertEqual(AnthemMapUnsavedChangeResolution.Instruction.discardAndProceed, .discardAndProceed)
        XCTAssertEqual(AnthemMapUnsavedChangeResolution.Instruction.cancel, .cancel)
    }

    func testInstructionsAreDistinct() {
        XCTAssertNotEqual(
            AnthemMapUnsavedChangeResolution.Instruction.saveThenProceed,
            .discardAndProceed
        )
        XCTAssertNotEqual(AnthemMapUnsavedChangeResolution.Instruction.saveThenProceed, .cancel)
        XCTAssertNotEqual(AnthemMapUnsavedChangeResolution.Instruction.discardAndProceed, .cancel)
    }

    func testIndependentEvaluatorValuesBehaveEquivalently() {
        let first = AnthemMapUnsavedChangeResolution()
        let second = AnthemMapUnsavedChangeResolution()

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.resolve(.save), second.resolve(.save))
        XCTAssertEqual(first.resolve(.discard), second.resolve(.discard))
        XCTAssertEqual(first.resolve(.cancel), second.resolve(.cancel))
        XCTAssertEqual(first.resolve(nil), second.resolve(nil))
    }

    func testEvaluatorRequiresOnlyChoiceInput() {
        XCTAssertEqual(resolution.resolve(.save), .saveThenProceed)
    }

    func testNilChoiceFailsClosedRatherThanPermittingDiscard() {
        XCTAssertEqual(resolution.resolve(nil), .cancel)
        XCTAssertNotEqual(resolution.resolve(nil), .discardAndProceed)
    }
}
