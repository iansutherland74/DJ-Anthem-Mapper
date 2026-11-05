import XCTest
@testable import DJAnthemMapper

// PHASE_4C1A_MULTI_REGION_DATA_MODEL_TESTS
final class AnthemRegionCollectionTests: XCTestCase {
    func testInitialCollectionContainsOneEmptyRegion() { let c = AnthemRegionCollection(); XCTAssertEqual(c.count, 1); XCTAssertTrue(c.first.isEmpty); XCTAssertEqual(c.displayLabel(for: c.first.id), "A") }
    func testExistingSingleRegionBecomesRegionA() { let r = AnthemRegion(start: 10, end: 20); let i = AnthemRegionItem(region: r); let c = AnthemRegionCollection(regions: [i]); XCTAssertEqual(c.first.id, i.id); XCTAssertEqual(c.first.region, r); XCTAssertEqual(c.displayLabel(for: i.id), "A") }
    func testAddingRegionsCreatesStableIdentities() { var c = AnthemRegionCollection(); let a=c.first.id,b=c.addRegion(),d=c.addRegion(); XCTAssertEqual(c.count,3); XCTAssertNotEqual(a,b); XCTAssertNotEqual(b,d); XCTAssertEqual(c.displayLabel(for:b),"B"); XCTAssertEqual(c.displayLabel(for:d),"C") }
    func testRegionsRemainIndependent() { var c=AnthemRegionCollection(); let a=c.first.id; let b=c.addRegion(region: AnthemRegion(start:30,end:40)); XCTAssertTrue(c.updateRegion(id:a,region:AnthemRegion(start:10,end:20))); XCTAssertEqual(c.region(id:a)?.region,AnthemRegion(start:10,end:20)); XCTAssertEqual(c.region(id:b)?.region,AnthemRegion(start:30,end:40)) }
    func testDeletingMiddlePreservesOtherIDs() { var c=AnthemRegionCollection(); let a=c.first.id,b=c.addRegion(),d=c.addRegion(); XCTAssertTrue(c.deleteRegion(id:b)); XCTAssertEqual(c.count,2); XCTAssertNotNil(c.region(id:a)); XCTAssertNil(c.region(id:b)); XCTAssertNotNil(c.region(id:d)) }
    func testDeletingOnlyRegionClearsIt() { var c=AnthemRegionCollection(regions:[AnthemRegionItem(region:AnthemRegion(start:10,end:20))]); let id=c.first.id; XCTAssertTrue(c.deleteRegion(id:id)); XCTAssertEqual(c.count,1); XCTAssertEqual(c.first.id,id); XCTAssertTrue(c.first.isEmpty) }
    func testNewTrackResetCreatesFreshA() { var c=AnthemRegionCollection(regions:[AnthemRegionItem(region:AnthemRegion(start:10,end:20)),AnthemRegionItem(region:AnthemRegion(start:30,end:40))]); c.resetForNewTrack(); XCTAssertEqual(c.count,1); XCTAssertTrue(c.first.isEmpty); XCTAssertEqual(c.displayLabel(for:c.first.id),"A") }
    func testDuplicateIdentifiersAreDeduplicated() { let id=UUID(); let c=AnthemRegionCollection(regions:[AnthemRegionItem(id:id,region:AnthemRegion(start:10,end:20)),AnthemRegionItem(id:id,region:AnthemRegion(start:30,end:40))]); XCTAssertEqual(c.count,1); XCTAssertEqual(c.first.region,AnthemRegion(start:10,end:20)) }
    func testLabelsContinueAfterZ() { XCTAssertEqual(AnthemRegionCollection.displayLabel(forIndex:25),"Z"); XCTAssertEqual(AnthemRegionCollection.displayLabel(forIndex:26),"AA"); XCTAssertEqual(AnthemRegionCollection.displayLabel(forIndex:27),"AB") }
}
