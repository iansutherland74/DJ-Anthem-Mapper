import XCTest
@testable import DJAnthemMapper

final class AnthemMapSaveEligibilityTests: XCTestCase {
    private func item(_ start: Double?, _ end: Double?) -> AnthemRegionItem { .init(region: AnthemRegion(start:start,end:end)) }
    func testNoLoadedMediaBlocksSave() { let r=AnthemMapSaveEligibility.evaluate(hasLoadedMedia:false,trackDuration:100,regions:[item(1,2)]); XCTAssertFalse(r.canSave); XCTAssertTrue(r.blockers.contains(.noLoadedMedia)) }
    func testZeroDurationBlocksSave() { let r=AnthemMapSaveEligibility.evaluate(hasLoadedMedia:true,trackDuration:0,regions:[item(1,2)]); XCTAssertFalse(r.canSave); XCTAssertTrue(r.blockers.contains(.invalidTrackDuration)) }
    func testNegativeDurationBlocksSave() { XCTAssertFalse(AnthemMapSaveEligibility.evaluate(hasLoadedMedia:true,trackDuration:-1,regions:[item(1,2)]).canSave) }
    func testNonFiniteDurationBlocksSave() { XCTAssertFalse(AnthemMapSaveEligibility.evaluate(hasLoadedMedia:true,trackDuration:.infinity,regions:[item(1,2)]).canSave) }
    func testNoCompleteRegionBlocksSave() { XCTAssertFalse(AnthemMapSaveEligibility.evaluate(hasLoadedMedia:true,trackDuration:100,regions:[item(nil,nil)]).canSave) }
    func testStartOnlyBlocksSaveWhenItIsOnlyRegion() { XCTAssertFalse(AnthemMapSaveEligibility.evaluate(hasLoadedMedia:true,trackDuration:100,regions:[item(1,nil)]).canSave) }
    func testEndOnlyBlocksSaveWhenItIsOnlyRegion() { XCTAssertFalse(AnthemMapSaveEligibility.evaluate(hasLoadedMedia:true,trackDuration:100,regions:[item(nil,2)]).canSave) }
    func testOneCompleteValidRegionEnablesSave() { XCTAssertTrue(AnthemMapSaveEligibility.evaluate(hasLoadedMedia:true,trackDuration:100,regions:[item(1,2)]).canSave) }
    func testValidRegionsPlusEmptyFinalRegionCanSave() { XCTAssertTrue(AnthemMapSaveEligibility.evaluate(hasLoadedMedia:true,trackDuration:100,regions:[item(1,2),item(3,4),item(nil,nil)]).canSave) }
    func testValidRegionPlusPartialFinalRegionCanSave() { XCTAssertTrue(AnthemMapSaveEligibility.evaluate(hasLoadedMedia:true,trackDuration:100,regions:[item(1,2),item(3,nil)]).canSave) }
    func testCompleteInvalidRegionBlocksOtherwiseValidSave() { let r=AnthemMapSaveEligibility.evaluate(hasLoadedMedia:true,trackDuration:100,regions:[item(1,2),item(5,4)]); XCTAssertFalse(r.canSave); XCTAssertTrue(r.blockers.contains(.completeInvalidRegion(slot:1))) }
    func testMoreThanEightRegionsBlocksSave() { let rs=(0..<9).map { item(Double($0*2),Double($0*2+1)) }; let r=AnthemMapSaveEligibility.evaluate(hasLoadedMedia:true,trackDuration:100,regions:rs); XCTAssertFalse(r.canSave); XCTAssertTrue(r.blockers.contains(.tooManyRegions(9))) }
    func testEvaluationDoesNotMutateRegionDataOrIdentity() { let id=UUID(); let rs=[AnthemRegionItem(id:id,region:AnthemRegion(start:1,end:2))]; let before=rs; _=AnthemMapSaveEligibility.evaluate(hasLoadedMedia:true,trackDuration:100,regions:rs); XCTAssertEqual(rs,before); XCTAssertEqual(rs[0].id,id) }
}
