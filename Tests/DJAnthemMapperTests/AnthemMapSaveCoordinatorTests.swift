import Foundation
import XCTest
@testable import DJAnthemMapper

final class AnthemMapSaveCoordinatorTests: XCTestCase {
    @MainActor func testInitialStateIsIdleAndNotSaveable() {
        let c=AnthemMapSaveCoordinator(); XCTAssertEqual(c.status,.idle); XCTAssertNil(c.eligibility); XCTAssertNil(c.preparedSave); XCTAssertFalse(c.canSave); XCTAssertTrue(c.blockers.isEmpty)
    }
    @MainActor func testValidEditorStateEvaluatesReady() {
        let c=AnthemMapSaveCoordinator(); let i=makeValidItem(start:10,end:20); let r=c.evaluate(mediaURL:mediaURL(),trackDuration:300,regions:[i]); XCTAssertTrue(r.canSave); XCTAssertTrue(c.canSave); XCTAssertEqual(c.status,.ready); XCTAssertEqual(c.eligibility,r); XCTAssertTrue(c.blockers.isEmpty); XCTAssertNil(c.preparedSave)
    }
    @MainActor func testMissingMediaIsNotSaveable() {
        let c=AnthemMapSaveCoordinator(); let r=c.evaluate(mediaURL:nil,trackDuration:300,regions:[makeValidItem(start:10,end:20)]); XCTAssertFalse(r.canSave); XCTAssertFalse(c.canSave); XCTAssertEqual(c.status,.idle); XCTAssertTrue(c.blockers.contains(.noLoadedMedia)); XCTAssertNil(c.preparedSave)
    }
    @MainActor func testInvalidTrackDurationIsNotSaveable() {
        let c=AnthemMapSaveCoordinator(); let r=c.evaluate(mediaURL:mediaURL(),trackDuration:0,regions:[makeValidItem(start:10,end:20)]); XCTAssertFalse(r.canSave); XCTAssertFalse(c.canSave); XCTAssertTrue(c.blockers.contains(.invalidTrackDuration)); XCTAssertEqual(c.status,.idle)
    }
    @MainActor func testNoCompleteRegionIsNotSaveable() {
        let c=AnthemMapSaveCoordinator(); let r=c.evaluate(mediaURL:mediaURL(),trackDuration:300,regions:[AnthemRegionItem()]); XCTAssertFalse(r.canSave); XCTAssertFalse(c.canSave); XCTAssertTrue(c.blockers.contains(.noCompleteValidRegion))
    }
    @MainActor func testValidStatePreparesSuccessfully() throws {
        let c=AnthemMapSaveCoordinator(); let p=try c.prepare(mediaURL:mediaURL(),trackDuration:300,regions:[makeValidItem(start:10,end:20)]); XCTAssertEqual(c.status,.prepared); XCTAssertTrue(c.canSave); XCTAssertNotNil(c.eligibility); XCTAssertEqual(c.preparedSave,p)
    }
    @MainActor func testPreparedTrackIdentityIsCorrect() throws {
        let c=AnthemMapSaveCoordinator(); let t=try temporaryMediaFile(named:"Track.mp3",byteCount:4096); defer{try? FileManager.default.removeItem(at:t.directoryURL)}; let p=try c.prepare(mediaURL:t.fileURL,trackDuration:300,regions:[makeValidItem(start:10,end:20)]); XCTAssertEqual(p.document.track.fileName,"Track.mp3"); XCTAssertEqual(p.document.track.fileSize,UInt64(4096)); XCTAssertEqual(p.document.track.durationMilliseconds,300_000)
    }
    @MainActor func testPreparedDocumentContainsCorrectRegion() throws {
        let c=AnthemMapSaveCoordinator(); let id=UUID(); let p=try c.prepare(mediaURL:mediaURL(),trackDuration:300,regions:[makeValidItem(id:id,start:10.123,end:20.456)]); XCTAssertEqual(p.document.regions.count,1); XCTAssertEqual(p.document.regions[0].id,id); XCTAssertEqual(p.document.regions[0].slot,0); XCTAssertEqual(p.document.regions[0].startMilliseconds,10_123); XCTAssertEqual(p.document.regions[0].endMilliseconds,20_456)
    }
    @MainActor func testRegionUUIDsAndSlotsArePreserved() throws {
        let c=AnthemMapSaveCoordinator(); let a=UUID(),b=UUID(),d=UUID(); let rs=[makeValidItem(id:a,start:10,end:20),makeValidItem(id:b,start:30,end:40),makeValidItem(id:d,start:50,end:60)]; let p=try c.prepare(mediaURL:mediaURL(),trackDuration:300,regions:rs); XCTAssertEqual(p.document.regions.map(\.id),[a,b,d]); XCTAssertEqual(p.document.regions.map(\.slot),[0,1,2])
    }
    @MainActor func testIncompleteFinalRegionIsOmittedFromPreparedDocument() throws {
        let c=AnthemMapSaveCoordinator(); let id=UUID(); let p=try c.prepare(mediaURL:mediaURL(),trackDuration:300,regions:[makeValidItem(id:id,start:10,end:20),makeStartOnlyItem(start:30)]); XCTAssertEqual(p.document.regions.count,1); XCTAssertEqual(p.document.regions[0].id,id); XCTAssertEqual(p.document.regions[0].slot,0)
    }
    @MainActor func testSuggestedFilenameComesFromB4() throws {
        let c=AnthemMapSaveCoordinator(); let p=try c.prepare(mediaURL:URL(fileURLWithPath:"/Music/Mr Brightside.mp3"),trackDuration:300,regions:[makeValidItem(start:10,end:20)]); XCTAssertEqual(p.suggestedFileName,"Mr Brightside.anthemmap")
    }
    @MainActor func testPreparationDoesNotMutateInputRegions() throws {
        let c=AnthemMapSaveCoordinator(); let rs=[makeValidItem(start:10,end:20),makeValidItem(start:30,end:40)]; let before=rs; _=try c.prepare(mediaURL:mediaURL(),trackDuration:300,regions:rs); XCTAssertEqual(rs,before)
    }
    @MainActor func testIneligiblePreparationThrowsNotEligible() {
        let c=AnthemMapSaveCoordinator(); XCTAssertThrowsError(try c.prepare(mediaURL:mediaURL(),trackDuration:300,regions:[AnthemRegionItem()])) { XCTAssertEqual($0 as? AnthemMapSaveCoordinator.CoordinatorError,.notEligible) }; XCTAssertFalse(c.canSave); XCTAssertEqual(c.status,.idle); XCTAssertNil(c.preparedSave)
    }
    @MainActor func testReevaluationClearsPreviouslyPreparedSave() throws {
        let c=AnthemMapSaveCoordinator(); let i=makeValidItem(start:10,end:20); _=try c.prepare(mediaURL:mediaURL(),trackDuration:300,regions:[i]); XCTAssertNotNil(c.preparedSave); let r=c.evaluate(mediaURL:mediaURL(),trackDuration:300,regions:[i]); XCTAssertTrue(r.canSave); XCTAssertTrue(c.canSave); XCTAssertEqual(c.status,.ready); XCTAssertNil(c.preparedSave)
    }
    @MainActor func testInvalidReevaluationClearsPreparedSaveAndDisablesSave() throws {
        let c=AnthemMapSaveCoordinator(); let i=makeValidItem(start:10,end:20); _=try c.prepare(mediaURL:mediaURL(),trackDuration:300,regions:[i]); XCTAssertNotNil(c.preparedSave); let r=c.evaluate(mediaURL:nil,trackDuration:300,regions:[i]); XCTAssertFalse(r.canSave); XCTAssertFalse(c.canSave); XCTAssertEqual(c.status,.idle); XCTAssertNil(c.preparedSave)
    }
    @MainActor func testResetReturnsCoordinatorToInitialState() throws {
        let c=AnthemMapSaveCoordinator(); _=try c.prepare(mediaURL:mediaURL(),trackDuration:300,regions:[makeValidItem(start:10,end:20)]); c.reset(); XCTAssertEqual(c.status,.idle); XCTAssertNil(c.eligibility); XCTAssertNil(c.preparedSave); XCTAssertFalse(c.canSave); XCTAssertTrue(c.blockers.isEmpty)
    }

    private struct TemporaryMedia { let directoryURL: URL; let fileURL: URL }
    private func mediaURL() -> URL { URL(fileURLWithPath:"/Music/Test Track.mp3") }
    private func temporaryMediaFile(named fileName:String,byteCount:Int) throws -> TemporaryMedia {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true); try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true); let file=dir.appendingPathComponent(fileName); try Data(repeating:0x41,count:byteCount).write(to:file); return TemporaryMedia(directoryURL:dir,fileURL:file)
    }
    @MainActor private func makeValidItem(id:UUID=UUID(),start:TimeInterval,end:TimeInterval,trackDuration:TimeInterval=300) -> AnthemRegionItem {
        let c=AnthemRegionController(); guard c.setStart(at:start,trackDuration:trackDuration) else { XCTFail("Failed to create START marker"); return AnthemRegionItem(id:id) }; guard c.setEnd(at:end,trackDuration:trackDuration) else { XCTFail("Failed to create END marker"); return AnthemRegionItem(id:id,region:c.region) }; XCTAssertTrue(c.region.isComplete); XCTAssertTrue(c.region.isValid); return AnthemRegionItem(id:id,region:c.region)
    }
    @MainActor private func makeStartOnlyItem(id:UUID=UUID(),start:TimeInterval,trackDuration:TimeInterval=300) -> AnthemRegionItem {
        let c=AnthemRegionController(); guard c.setStart(at:start,trackDuration:trackDuration) else { XCTFail("Failed to create START-only marker"); return AnthemRegionItem(id:id) }; XCTAssertTrue(c.region.hasStart); XCTAssertFalse(c.region.hasEnd); XCTAssertFalse(c.region.isComplete); return AnthemRegionItem(id:id,region:c.region)
    }
}
