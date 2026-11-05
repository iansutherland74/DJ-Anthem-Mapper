import XCTest
@testable import DJAnthemMapper

final class AnthemMapSuggestedFileNameTests: XCTestCase {
    private let builder = AnthemMapSuggestedFileName()
    func testMP3BecomesAnthemMap() { XCTAssertEqual(name("/Music/Mr Brightside.mp3"), "Mr Brightside.anthemmap") }
    func testM4ABecomesAnthemMap() { XCTAssertEqual(name("/Music/track.m4a"), "track.anthemmap") }
    func testMP4BecomesAnthemMap() { XCTAssertEqual(name("/Video/track.mp4"), "track.anthemmap") }
    func testMKVBecomesAnthemMap() { XCTAssertEqual(name("/Video/Live Forever.mkv"), "Live Forever.anthemmap") }
    func testParentPathIsNotIncluded() { XCTAssertEqual(name("/Users/sutherland/Music/DJ/Sets/song.mp3"), "song.anthemmap") }
    func testOnlyFinalExtensionIsReplaced() { XCTAssertEqual(name("/Music/Oasis.Live.1996.mp3"), "Oasis.Live.1996.anthemmap") }
    func testUppercaseSourceExtensionIsHandled() { XCTAssertEqual(name("/Music/ANTHEM.MP3"), "ANTHEM.anthemmap") }
    func testUnicodeAndSpacesArePreserved() { XCTAssertEqual(name("/Music/Cafe - Set 01.m4a"), "Cafe - Set 01.anthemmap") }
    func testNoSourceExtensionGetsAnthemMapExtension() { XCTAssertEqual(name("/Music/Untitled"), "Untitled.anthemmap") }
    func testWhitespaceStemUsesSafeFallback() { XCTAssertEqual(name("/Music/   .mp3"), "Anthem Map.anthemmap") }
    private func name(_ path: String) -> String { builder.make(for: URL(fileURLWithPath: path)) }
}
