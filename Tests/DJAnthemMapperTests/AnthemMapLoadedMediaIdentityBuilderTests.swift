import Foundation
import XCTest
@testable import DJAnthemMapper

final class AnthemMapLoadedMediaIdentityBuilderTests: XCTestCase {
    private let builder = AnthemMapLoadedMediaIdentityBuilder()

    private func media(url: URL) -> MediaDescription {
        MediaDescription(
            sourceURL: url,
            fileSize: 0,
            container: url.pathExtension.uppercased(),
            duration: nil,
            overallBitRate: nil,
            metadata: MediaMetadata(title: nil, artist: nil, album: nil, genre: nil),
            audioStreams: [],
            hasVideo: false
        )
    }

    private func temporaryFile(extension ext: String, data: Data = Data("M3-03G".utf8)) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try data.write(to: url)
        return url
    }

    func testNoLoadedMediaThrowsNoLoadedMedia() {
        XCTAssertThrowsError(try builder.makeIdentity(media: nil, trackDuration: 100)) { error in
            XCTAssertEqual(error as? AnthemMapLoadedMediaIdentityError, .noLoadedMedia)
        }
    }

    func testMP3UsesOriginalSourceIdentity() throws {
        let url = try temporaryFile(extension: "mp3"); defer { try? FileManager.default.removeItem(at: url) }
        let result = try builder.makeIdentity(media: media(url: url), trackDuration: 100)
        XCTAssertEqual(result.fileName, url.lastPathComponent)
    }

    func testM4AUsesOriginalSourceIdentity() throws {
        let url = try temporaryFile(extension: "m4a"); defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(try builder.makeIdentity(media: media(url: url), trackDuration: 100).fileName, url.lastPathComponent)
    }

    func testMP4UsesOriginalSourceIdentity() throws {
        let url = try temporaryFile(extension: "mp4"); defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(try builder.makeIdentity(media: media(url: url), trackDuration: 100).fileName, url.lastPathComponent)
    }

    func testMKVUsesOriginalSourceIdentity() throws {
        let url = try temporaryFile(extension: "mkv"); defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(try builder.makeIdentity(media: media(url: url), trackDuration: 100).fileName, url.lastPathComponent)
    }

    func testWAVUsesOriginalSourceIdentity() throws {
        let url = try temporaryFile(extension: "wav"); defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(try builder.makeIdentity(media: media(url: url), trackDuration: 100).fileName, url.lastPathComponent)
    }

    func testZeroDurationPropagatesTypedIdentityFailure() throws {
        let url = try temporaryFile(extension: "mp3"); defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try builder.makeIdentity(media: media(url: url), trackDuration: 0)) { error in
            XCTAssertEqual(error as? AnthemMapLoadedMediaIdentityError, .invalidIdentity(.invalidTrackDuration))
        }
    }

    func testNonFiniteDurationPropagatesTypedIdentityFailure() throws {
        let url = try temporaryFile(extension: "mp3"); defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try builder.makeIdentity(media: media(url: url), trackDuration: .infinity)) { error in
            XCTAssertEqual(error as? AnthemMapLoadedMediaIdentityError, .invalidIdentity(.invalidTrackDuration))
        }
    }

    func testDurationUsesExistingBuilderRoundingPolicy() throws {
        let url = try temporaryFile(extension: "mp3"); defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(try builder.makeIdentity(media: media(url: url), trackDuration: 1.2346).durationMilliseconds, 1_235)
    }

    func testExistingSourceFileSizeIsCapturedExactly() throws {
        let data = Data(repeating: 7, count: 4_321)
        let url = try temporaryFile(extension: "mkv", data: data); defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(try builder.makeIdentity(media: media(url: url), trackDuration: 100).fileSize, UInt64(data.count))
    }

    func testBridgeMatchesDirectCertifiedBuilderOutput() throws {
        let url = try temporaryFile(extension: "m4a", data: Data(repeating: 3, count: 500)); defer { try? FileManager.default.removeItem(at: url) }
        let bridged = try builder.makeIdentity(media: media(url: url), trackDuration: 123.456)
        let direct = try AnthemMapTrackIdentityBuilder().makeIdentity(mediaURL: url, trackDuration: 123.456)
        XCTAssertEqual(bridged, direct)
    }

    func testIdentityBuildingDoesNotModifySourceFile() throws {
        let original = Data("M3-03G-original-source".utf8)
        let url = try temporaryFile(extension: "mp3", data: original); defer { try? FileManager.default.removeItem(at: url) }
        _ = try builder.makeIdentity(media: media(url: url), trackDuration: 100)
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
}
