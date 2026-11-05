import XCTest
@testable import DJAnthemMapper

final class AnthemMapTrackIdentityBuilderTests: XCTestCase {
    private let builder = AnthemMapTrackIdentityBuilder()

    func testMP3FilenameIsPreserved() throws { XCTAssertEqual(try identity("/Music/Mr Brightside.mp3").fileName, "Mr Brightside.mp3") }
    func testM4AFilenameIsPreserved() throws { XCTAssertEqual(try identity("/Music/track.m4a").fileName, "track.m4a") }
    func testMP4FilenameIsPreserved() throws { XCTAssertEqual(try identity("/Video/track.mp4").fileName, "track.mp4") }
    func testMKVFilenameIsPreserved() throws { XCTAssertEqual(try identity("/Video/track.mkv").fileName, "track.mkv") }
    func testOnlyLastPathComponentIsStored() throws { XCTAssertEqual(try identity("/Users/sutherland/Music/DJ/Sets/song.mp3").fileName, "song.mp3") }
    func testDurationConvertsExactlyToMilliseconds() throws { XCTAssertEqual(try identity("/Music/song.mp3", duration:123.456).durationMilliseconds, 123_456) }
    func testDurationUsesM3RoundingPolicy() throws { XCTAssertEqual(try identity("/Music/song.mp3", duration:1.2346).durationMilliseconds, 1_235) }
    func testZeroDurationIsRejected() { assertDurationError(0) }
    func testNegativeDurationIsRejected() { assertDurationError(-1) }
    func testNaNDurationIsRejected() { assertDurationError(.nan) }
    func testInfiniteDurationIsRejected() { assertDurationError(.infinity) }
    func testEmptyFilenameIsRejected() { XCTAssertThrowsError(try builder.validatedFileName("")) { XCTAssertEqual($0 as? AnthemMapTrackIdentityError,.invalidFileName) } }
    func testWhitespaceOnlyFilenameIsRejected() { XCTAssertThrowsError(try builder.validatedFileName("   ")) { XCTAssertEqual($0 as? AnthemMapTrackIdentityError,.invalidFileName) } }
    func testExistingFileSizeIsCapturedExactly() throws { let u=temp("mp3"); defer{try? FileManager.default.removeItem(at:u)}; try Data(repeating:0x41,count:4096).write(to:u); XCTAssertEqual(try builder.makeIdentity(mediaURL:u,trackDuration:100).fileSize,4096) }
    func testUnavailableFileSizeProducesNil() throws { let u=temp("mp3"); XCTAssertNil(try builder.makeIdentity(mediaURL:u,trackDuration:100).fileSize) }
    func testZeroByteFileProducesZeroFileSize() throws { let u=temp("m4a"); defer{try? FileManager.default.removeItem(at:u)}; XCTAssertTrue(FileManager.default.createFile(atPath:u.path,contents:Data())); XCTAssertEqual(try builder.makeIdentity(mediaURL:u,trackDuration:100).fileSize,0) }
    func testSameInputProducesEqualTrackIdentity() throws { let u=URL(fileURLWithPath:"/Music/song.mp3"); XCTAssertEqual(try builder.makeIdentity(mediaURL:u,trackDuration:123.456),try builder.makeIdentity(mediaURL:u,trackDuration:123.456)) }
    func testIdentityBuildingDoesNotModifySourceFile() throws { let u=temp("mkv"); defer{try? FileManager.default.removeItem(at:u)}; let d=Data("M3-B2-source-data".utf8); try d.write(to:u); _=try builder.makeIdentity(mediaURL:u,trackDuration:100); XCTAssertEqual(try Data(contentsOf:u),d) }
    func testBuilderDoesNotRequireSourceFileToExist() throws { let u=temp("mp3"); let x=try builder.makeIdentity(mediaURL:u,trackDuration:100); XCTAssertEqual(x.fileName,u.lastPathComponent); XCTAssertNil(x.fileSize); XCTAssertEqual(x.durationMilliseconds,100_000) }
    func testBuiltIdentityProducesValidM3Document() throws { let x=try identity("/Music/song.mp3"); let id=UUID(); let d=AnthemMapDocument(track:x,regions:[AnthemMapDocument.Region(id:id,slot:0,startMilliseconds:10_000,endMilliseconds:20_000)]); XCTAssertTrue(d.isValid); XCTAssertEqual(d.track,x); XCTAssertEqual(d.regions[0].id,id) }

    private func identity(_ path:String,duration:TimeInterval=100) throws -> AnthemMapDocument.TrackIdentity { try builder.makeIdentity(mediaURL:URL(fileURLWithPath:path),trackDuration:duration) }
    private func assertDurationError(_ duration:TimeInterval,file:StaticString=#filePath,line:UInt=#line) { XCTAssertThrowsError(try builder.makeIdentity(mediaURL:URL(fileURLWithPath:"/Music/song.mp3"),trackDuration:duration),file:file,line:line) { XCTAssertEqual($0 as? AnthemMapTrackIdentityError,.invalidTrackDuration,file:file,line:line) } }
    private func temp(_ ext:String)->URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext) }
}
