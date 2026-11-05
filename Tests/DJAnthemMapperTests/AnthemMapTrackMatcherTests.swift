import Foundation
import XCTest
@testable import DJAnthemMapper

final class AnthemMapTrackMatcherTests: XCTestCase {
    private let matcher = AnthemMapTrackMatcher()
    private func identity(fileName:String="Track.mp3", fileSize:UInt64?=4_096, durationMilliseconds:Int64=300_000) -> AnthemMapDocument.TrackIdentity {
        AnthemMapDocument.TrackIdentity(fileName:fileName,fileSize:fileSize,durationMilliseconds:durationMilliseconds)
    }
    func testIdenticalIdentitiesMatch(){ let r=matcher.compare(expected:identity(),actual:identity()); XCTAssertTrue(r.matches); XCTAssertTrue(r.mismatches.isEmpty) }
    func testFilenameMismatchIsReported(){ let r=matcher.compare(expected:identity(fileName:"Track.mp3"),actual:identity(fileName:"Different.mp3")); XCTAssertFalse(r.matches); XCTAssertEqual(r.mismatches,[.fileName]) }
    func testFileSizeMismatchIsReported(){ let r=matcher.compare(expected:identity(fileSize:4_096),actual:identity(fileSize:8_192)); XCTAssertFalse(r.matches); XCTAssertEqual(r.mismatches,[.fileSize]) }
    func testDurationMismatchIsReported(){ let r=matcher.compare(expected:identity(durationMilliseconds:300_000),actual:identity(durationMilliseconds:300_001)); XCTAssertFalse(r.matches); XCTAssertEqual(r.mismatches,[.duration]) }
    func testAllMismatchesAreReportedTogether(){ let r=matcher.compare(expected:identity(fileName:"Track.mp3",fileSize:4_096,durationMilliseconds:300_000),actual:identity(fileName:"Different.mp3",fileSize:8_192,durationMilliseconds:299_000)); XCTAssertEqual(r.mismatches,[.fileName,.fileSize,.duration]) }
    func testExpectedNilFileSizeDoesNotCauseMismatch(){ let r=matcher.compare(expected:identity(fileSize:nil),actual:identity(fileSize:4_096)); XCTAssertTrue(r.matches); XCTAssertTrue(r.mismatches.isEmpty) }
    func testActualNilFileSizeDoesNotCauseMismatch(){ let r=matcher.compare(expected:identity(fileSize:4_096),actual:identity(fileSize:nil)); XCTAssertTrue(r.matches); XCTAssertTrue(r.mismatches.isEmpty) }
    func testBothNilFileSizesMatch(){ let r=matcher.compare(expected:identity(fileSize:nil),actual:identity(fileSize:nil)); XCTAssertTrue(r.matches); XCTAssertTrue(r.mismatches.isEmpty) }
    func testFilenameSpacesAreComparedExactly(){ let r=matcher.compare(expected:identity(fileName:"Live Forever.mp3"),actual:identity(fileName:"Live  Forever.mp3")); XCTAssertEqual(r.mismatches,[.fileName]) }
    func testFilenameExtensionParticipatesInComparison(){ let r=matcher.compare(expected:identity(fileName:"Track.mp3"),actual:identity(fileName:"Track.m4a")); XCTAssertEqual(r.mismatches,[.fileName]) }
    func testComparisonDoesNotMutateIdentities(){ let e=identity(), a=identity(), eb=e, ab=a; _=matcher.compare(expected:e,actual:a); XCTAssertEqual(e,eb); XCTAssertEqual(a,ab) }
    func testSameInputsProduceSameResult(){ let e=identity(fileName:"Track.mp3",fileSize:4_096,durationMilliseconds:300_000), a=identity(fileName:"Different.mp3",fileSize:8_192,durationMilliseconds:300_001); XCTAssertEqual(matcher.compare(expected:e,actual:a),matcher.compare(expected:e,actual:a)) }
}
