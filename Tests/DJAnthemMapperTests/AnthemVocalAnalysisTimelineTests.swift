import XCTest
@testable import DJAnthemMapper

final class AnthemVocalAnalysisTimelineTests: XCTestCase {
    private func pcm(frames: Int, rate: UInt32, value: Float = 0.5) throws -> VocalSeparationPCM {
        try VocalSeparationPCM(left: .init(repeating: value, count: frames), right: .init(repeating: value, count: frames), sampleRate: rate)
    }

    func testOneSecondWindowsCoverWholePCMExactly() throws {
        let frames = AnthemVocalAnalysisTimeline.frames(from: try pcm(frames: 12, rate: 4), windowDuration: 1)
        XCTAssertEqual(frames.count, 3)
        XCTAssertEqual(frames.map(\.startTime), [0,1,2])
        XCTAssertEqual(frames.map(\.duration), [1,1,1])
        XCTAssertEqual(frames.last?.endTime, 3)
    }

    func testFinalWindowIsClippedToAvailablePCM() throws {
        let frames = AnthemVocalAnalysisTimeline.frames(from: try pcm(frames: 10, rate: 4), windowDuration: 1)
        XCTAssertEqual(frames.count, 3)
        XCTAssertEqual(frames[2].startTime, 2)
        XCTAssertEqual(frames[2].duration, 0.5)
        XCTAssertEqual(frames[2].endTime, 2.5)
    }

    func testTimelineUsesD2MeasurementsForEachWindow() throws {
        let input = try VocalSeparationPCM(left: [0,0,1,1], right: [0,0,1,1], sampleRate: 2)
        let frames = AnthemVocalAnalysisTimeline.frames(from: input, windowDuration: 1)
        XCTAssertEqual(frames.count, 2)
        XCTAssertEqual(frames[0].energy, 0)
        XCTAssertEqual(frames[0].activity, 0)
        XCTAssertEqual(frames[1].energy, 1)
        XCTAssertEqual(frames[1].activity, 1)
    }

    func testAsymmetricStereoRemainsSymmetricThroughTimeline() throws {
        let left = try VocalSeparationPCM(left: [1,1], right: [0,0], sampleRate: 2)
        let right = try VocalSeparationPCM(left: [0,0], right: [1,1], sampleRate: 2)
        XCTAssertEqual(AnthemVocalAnalysisTimeline.frames(from: left), AnthemVocalAnalysisTimeline.frames(from: right))
    }

    func testDifferentSampleRatesProduceCorrectTimeCoordinates() throws {
        for rate: UInt32 in [32_000, 44_100, 48_000] {
            let input = try pcm(frames: Int(rate) + Int(rate / 2), rate: rate)
            let frames = AnthemVocalAnalysisTimeline.frames(from: input, windowDuration: 1)
            XCTAssertEqual(frames.count, 2)
            XCTAssertEqual(frames[0].duration, 1, accuracy: 0.000001)
            XCTAssertEqual(frames[1].startTime, 1, accuracy: 0.000001)
            XCTAssertEqual(frames[1].endTime, 1.5, accuracy: 0.000001)
        }
    }

    func testSubSecondWindowRoundsToNearestSampleCountDeterministically() throws {
        let input = try pcm(frames: 10, rate: 10)
        let first = AnthemVocalAnalysisTimeline.frames(from: input, windowDuration: 0.25)
        let second = AnthemVocalAnalysisTimeline.frames(from: input, windowDuration: 0.25)
        XCTAssertEqual(first, second)

        guard let firstFrame = first.first,
              let lastFrame = first.last else {
            return XCTFail("Expected vocal-analysis timeline frames")
        }

        XCTAssertEqual(firstFrame.duration, 0.3, accuracy: 0.000001)
        XCTAssertEqual(lastFrame.endTime, 1.0, accuracy: 0.000001)
    }

    func testInvalidWindowDurationOrThresholdReturnsEmpty() throws {
        let input = try pcm(frames: 10, rate: 10)
        XCTAssertTrue(AnthemVocalAnalysisTimeline.frames(from: input, windowDuration: 0).isEmpty)
        XCTAssertTrue(AnthemVocalAnalysisTimeline.frames(from: input, windowDuration: .nan).isEmpty)
        XCTAssertTrue(AnthemVocalAnalysisTimeline.frames(from: input, activityThreshold: -1).isEmpty)
        XCTAssertTrue(AnthemVocalAnalysisTimeline.frames(from: input, activityThreshold: .nan).isEmpty)
    }

    func testTimelineNeverExtendsBeyondPCMDuration() throws {
        let input = try pcm(frames: 7, rate: 3)
        let frames = AnthemVocalAnalysisTimeline.frames(from: input, windowDuration: 1)
        let sourceDuration = Double(input.left.count) / Double(input.sampleRate)
        XCTAssertLessThanOrEqual(frames.last?.endTime ?? .infinity, sourceDuration)
        XCTAssertEqual(frames.last?.endTime ?? -1, sourceDuration, accuracy: 0.000001)
    }
}
