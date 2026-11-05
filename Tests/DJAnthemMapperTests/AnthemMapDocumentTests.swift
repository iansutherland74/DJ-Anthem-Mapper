import XCTest
@testable import DJAnthemMapper

final class AnthemMapDocumentTests: XCTestCase {
    private let track = AnthemMapDocument.TrackIdentity(fileName: "track.mp3", fileSize: 1234, durationMilliseconds: 200_000)
    func testCurrentFormatVersionIsOne() { XCTAssertEqual(AnthemMapDocument.currentFormatVersion, 1) }
    func testMaximumRegionCountMatchesCertifiedM2Limit() { XCTAssertEqual(AnthemMapDocument.maximumRegionCount, 8) }
    func testValidDocument() { let d=AnthemMapDocument(track:track,regions:[.init(id:UUID(),slot:0,startMilliseconds:1000,endMilliseconds:2000)]); XCTAssertTrue(d.isValid); XCTAssertEqual(d.regions[0].durationMilliseconds,1000) }
    func testJSONRoundTripPreservesStableIdentityAndTiming() throws { let id=UUID(); let d=AnthemMapDocument(track:track,regions:[.init(id:id,slot:0,startMilliseconds:1234,endMilliseconds:5678)]); let e=JSONEncoder(); e.outputFormatting=[.sortedKeys]; let data=try e.encode(d); let r=try JSONDecoder().decode(AnthemMapDocument.self,from:data); XCTAssertEqual(r,d); XCTAssertEqual(r.regions[0].id,id) }
    func testInvalidOrderRejected() { let d=AnthemMapDocument(track:track,regions:[.init(id:UUID(),slot:0,startMilliseconds:5000,endMilliseconds:4000)]); XCTAssertFalse(d.isValid) }
    func testBeyondTrackRejected() { let d=AnthemMapDocument(track:track,regions:[.init(id:UUID(),slot:0,startMilliseconds:199000,endMilliseconds:201000)]); XCTAssertFalse(d.isValid) }
    func testDuplicateSlotsRejected() { let d=AnthemMapDocument(track:track,regions:[.init(id:UUID(),slot:0,startMilliseconds:1,endMilliseconds:2),.init(id:UUID(),slot:0,startMilliseconds:3,endMilliseconds:4)]); XCTAssertFalse(d.isValid) }
    func testDuplicateIDsRejected() { let id=UUID(); let d=AnthemMapDocument(track:track,regions:[.init(id:id,slot:0,startMilliseconds:1,endMilliseconds:2),.init(id:id,slot:1,startMilliseconds:3,endMilliseconds:4)]); XCTAssertFalse(d.isValid) }
    func testConstructorCapsAtEightRegions() { let rs=(0..<12).map { AnthemMapDocument.Region(id:UUID(),slot:$0,startMilliseconds:Int64($0*1000),endMilliseconds:Int64($0*1000+500)) }; XCTAssertEqual(AnthemMapDocument(track:track,regions:rs).regions.count,8) }
}
