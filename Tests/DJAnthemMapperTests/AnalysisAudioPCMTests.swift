import XCTest
@testable import DJAnthemMapper

final class AnalysisAudioPCMTests: XCTestCase {
    func testRejectsZeroSampleRate() {
        XCTAssertThrowsError(try AnalysisAudioPCM(left: [0], right: [0], sampleRate: 0)) {
            XCTAssertEqual($0 as? AnalysisAudioPCMError, .invalidSampleRate)
        }
    }

    func testRejectsEmptyChannels() {
        XCTAssertThrowsError(try AnalysisAudioPCM(left: [], right: [], sampleRate: 44_100)) {
            XCTAssertEqual($0 as? AnalysisAudioPCMError, .invalidStereoInput)
        }
    }

    func testRejectsMismatchedChannels() {
        XCTAssertThrowsError(try AnalysisAudioPCM(left: [0, 1], right: [0], sampleRate: 44_100)) {
            XCTAssertEqual($0 as? AnalysisAudioPCMError, .invalidStereoInput)
        }
    }

    func testRejectsNaN() {
        XCTAssertThrowsError(try AnalysisAudioPCM(left: [.nan], right: [0], sampleRate: 44_100)) {
            XCTAssertEqual($0 as? AnalysisAudioPCMError, .nonFiniteSamples)
        }
    }

    func testRejectsPositiveInfinity() {
        XCTAssertThrowsError(try AnalysisAudioPCM(left: [.infinity], right: [0], sampleRate: 44_100)) {
            XCTAssertEqual($0 as? AnalysisAudioPCMError, .nonFiniteSamples)
        }
    }

    func testRejectsNegativeInfinity() {
        XCTAssertThrowsError(try AnalysisAudioPCM(left: [-.infinity], right: [0], sampleRate: 44_100)) {
            XCTAssertEqual($0 as? AnalysisAudioPCMError, .nonFiniteSamples)
        }
    }

    func testAcceptsSilenceExactly() throws {
        let pcm = try AnalysisAudioPCM(left: [0, 0, 0], right: [0, 0, 0], sampleRate: 48_000)
        XCTAssertEqual(pcm.left, [0, 0, 0])
        XCTAssertEqual(pcm.right, [0, 0, 0])
        XCTAssertEqual(pcm.sampleRate, 48_000)
        XCTAssertEqual(pcm.frameCount, 3)
    }

    func testAcceptsOrdinaryStereoExactly() throws {
        let left: [Float] = [-0.5, 0.25, 0.75]
        let right: [Float] = [0.5, -0.25, -0.75]
        let pcm = try AnalysisAudioPCM(left: left, right: right, sampleRate: 44_100)
        XCTAssertEqual(pcm.left, left)
        XCTAssertEqual(pcm.right, right)
    }

    func testAcceptsOddFrameCount() throws {
        let pcm = try AnalysisAudioPCM(left: [1, 2, 3, 4, 5], right: [5, 4, 3, 2, 1], sampleRate: 44_100)
        XCTAssertEqual(pcm.frameCount, 5)
    }

    func testPreservesExtremeFiniteFloatSamples() throws {
        let left: [Float] = [.greatestFiniteMagnitude, -.greatestFiniteMagnitude]
        let right: [Float] = [-.greatestFiniteMagnitude, .greatestFiniteMagnitude]
        let pcm = try AnalysisAudioPCM(left: left, right: right, sampleRate: 96_000)
        XCTAssertEqual(pcm.left, left)
        XCTAssertEqual(pcm.right, right)
    }

    func testVocalSeparationBridgePreservesPCMExactly() throws {
        let left: [Float] = [-0.75, 0, 0.75]
        let right: [Float] = [0.25, -0.25, 0.5]
        let pcm = try AnalysisAudioPCM(left: left, right: right, sampleRate: 32_000)
        let bridged = try pcm.vocalSeparationPCM()
        XCTAssertEqual(bridged.left, left)
        XCTAssertEqual(bridged.right, right)
        XCTAssertEqual(bridged.sampleRate, 32_000)
    }

    func testRepeatedConstructionIsDeterministic() throws {
        let left: [Float] = [0.1, 0.2, 0.3]
        let right: [Float] = [0.4, 0.5, 0.6]
        let first = try AnalysisAudioPCM(left: left, right: right, sampleRate: 44_100)
        let second = try AnalysisAudioPCM(left: left, right: right, sampleRate: 44_100)
        XCTAssertEqual(first, second)
    }
}
