import Foundation
import XCTest
@testable import DJAnthemMapper

final class AnthemMapRestorationBuilderTests: XCTestCase {
    private let builder=AnthemMapRestorationBuilder()
    private var track:AnthemMapDocument.TrackIdentity { .init(fileName:"Track.mp3",fileSize:UInt64(4096),durationMilliseconds:300000) }
    private func p(_ slot:Int,id:UUID=UUID(),_ s:Int64,_ e:Int64)->AnthemMapDocument.Region { .init(id:id,slot:slot,startMilliseconds:s,endMilliseconds:e) }
    func testTrackIdentityIsPreservedExactly() throws { let d=AnthemMapDocument(track:track,regions:[p(0,1000,2000)]); XCTAssertEqual(try builder.makeRestoration(from:d).track,track) }
    func testSingleRegionRestoresMillisecondsAsSeconds() throws { let r=try builder.makeRestoration(from:AnthemMapDocument(track:track,regions:[p(0,12345,67890)])).regions[0]; XCTAssertEqual(r.start,12.345); XCTAssertEqual(r.end,67.890) }
    func testStableUUIDIsPreserved() throws { let id=UUID(); let r=try builder.makeRestoration(from:AnthemMapDocument(track:track,regions:[p(0,id:id,1000,2000)])).regions[0]; XCTAssertEqual(r.id,id) }
    func testSlotOrderingControlsRestoredOrdering() throws { let a=p(5,5000,6000),b=p(0,1000,2000),c=p(2,3000,4000); let r=try builder.makeRestoration(from:AnthemMapDocument(track:track,regions:[a,b,c])).regions; XCTAssertEqual(r.map{$0.id},[b.id,c.id,a.id]) }
    func testEightRegionsRestore() throws { let rs=(0..<8).map{p($0,Int64($0*1000+1),Int64($0*1000+500))}; XCTAssertEqual(try builder.makeRestoration(from:AnthemMapDocument(track:track,regions:rs)).regions.count,8) }
    func testRestorationProducesCompleteValidRegions() throws { let r=try builder.makeRestoration(from:AnthemMapDocument(track:track,regions:[p(0,1000,2000)])).regions[0]; XCTAssertTrue(r.isComplete); XCTAssertTrue(r.isValid) }
    func testMillisecondPrecisionIsPreservedExactly() throws { let r=try builder.makeRestoration(from:AnthemMapDocument(track:track,regions:[p(0,1,299999)])).regions[0]; XCTAssertEqual(Int64((r.start!*1000).rounded()),1); XCTAssertEqual(Int64((r.end!*1000).rounded()),299999) }
    func testEmptyPersistentRegionListProducesEmptyRestorationList() throws { XCTAssertTrue(try builder.makeRestoration(from:AnthemMapDocument(track:track,regions:[])).regions.isEmpty) }
    func testInvalidDocumentIsRejected() throws { let d=AnthemMapDocument(formatVersion:99,track:track,regions:[]); XCTAssertThrowsError(try builder.makeRestoration(from:d)) }
    func testBuilderDoesNotMutateDocument() throws { let d=AnthemMapDocument(track:track,regions:[p(0,1000,2000)]), before=d; _=try builder.makeRestoration(from:d); XCTAssertEqual(d,before) }
}
