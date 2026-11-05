import Foundation
import XCTest
@testable import DJAnthemMapper

final class AnthemMapReadEngineTests: XCTestCase {
    private let engine = AnthemMapReadEngine()
    private var track: AnthemMapDocument.TrackIdentity { .init(fileName:"Track.mp3",fileSize:UInt64(4096),durationMilliseconds:Int64(300000)) }
    private func region(_ slot:Int=0,id:UUID=UUID(),start:Int64=10000,end:Int64=20000)->AnthemMapDocument.Region { .init(id:id,slot:slot,startMilliseconds:start,endMilliseconds:end) }
    private func data(_ document:AnthemMapDocument) throws -> Data { try JSONEncoder().encode(document) }
    private func tempURL()->URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("anthemmap") }

    func testValidDocumentDecodesIdentically() throws { let d=AnthemMapDocument(track:track,regions:[region()]); XCTAssertEqual(try engine.decode(data:try data(d)),d) }
    func testValidSavedFileLoadsIdentically() throws { let d=AnthemMapDocument(track:track,regions:[region()]); let u=tempURL(); defer{try? FileManager.default.removeItem(at:u)}; try AnthemMapSaveEngine().save(document:d,to:u); XCTAssertEqual(try engine.load(from:u),d) }
    func testMalformedJSONIsRejected() { XCTAssertThrowsError(try engine.decode(data:Data("not-json".utf8))) { XCTAssertEqual($0 as? AnthemMapReadError,.decodingFailed) } }
    func testMissingFileIsReadFailure() { let u=tempURL(); XCTAssertThrowsError(try engine.load(from:u)) { XCTAssertEqual($0 as? AnthemMapReadError,.readFailed) } }
    func testUnsupportedFormatVersionIsRejected() throws { let d=AnthemMapDocument(formatVersion:99,track:track,regions:[region()]); XCTAssertThrowsError(try engine.decode(data:try data(d))) { XCTAssertEqual($0 as? AnthemMapReadError,.invalidDocument([.unsupportedFormatVersion(99)])) } }
    func testInvalidTrackDurationIsRejected() throws { let t=AnthemMapDocument.TrackIdentity(fileName:"Track.mp3",fileSize:nil,durationMilliseconds:0); let d=AnthemMapDocument(track:t,regions:[]); XCTAssertThrowsError(try engine.decode(data:try data(d))) }
    func testInvalidRegionOrderingIsRejected() throws { let d=AnthemMapDocument(track:track,regions:[region(start:20000,end:10000)]); XCTAssertThrowsError(try engine.decode(data:try data(d))) }
    func testRegionBeyondTrackIsRejected() throws { let d=AnthemMapDocument(track:track,regions:[region(start:299000,end:301000)]); XCTAssertThrowsError(try engine.decode(data:try data(d))) }
    func testDuplicateSlotIsRejected() throws { let d=AnthemMapDocument(track:track,regions:[region(0),region(0)]); XCTAssertThrowsError(try engine.decode(data:try data(d))) }
    func testDuplicateUUIDIsRejected() throws { let id=UUID(); let d=AnthemMapDocument(track:track,regions:[region(0,id:id),region(1,id:id,start:30000,end:40000)]); XCTAssertThrowsError(try engine.decode(data:try data(d))) }
    func testIdentitySlotAndTimingArePreserved() throws { let id=UUID(); let d=AnthemMapDocument(track:track,regions:[region(3,id:id,start:12345,end:67890)]); let r=try engine.decode(data:try data(d)).regions[0]; XCTAssertEqual(r.id,id); XCTAssertEqual(r.slot,3); XCTAssertEqual(r.startMilliseconds,12345); XCTAssertEqual(r.endMilliseconds,67890) }
    func testMultipleRegionOrderingIsPreserved() throws { let a=region(0,start:1000,end:2000), b=region(2,start:3000,end:4000), c=region(5,start:5000,end:6000); let d=AnthemMapDocument(track:track,regions:[a,b,c]); XCTAssertEqual(try engine.decode(data:try data(d)).regions,[a,b,c]) }
    func testLoadDoesNotModifySourceFile() throws { let d=AnthemMapDocument(track:track,regions:[region()]); let bytes=try data(d); let u=tempURL(); defer{try? FileManager.default.removeItem(at:u)}; try bytes.write(to:u); _=try engine.load(from:u); XCTAssertEqual(try Data(contentsOf:u),bytes) }
}
