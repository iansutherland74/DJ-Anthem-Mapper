import XCTest
@testable import DJAnthemMapper

final class AnthemCandidateScorerTests: XCTestCase {
    func testRanksHighestEnergyCandidateFirst() {
        let frames = AnthemAnalysisFoundation.frames(
            from: [0.1, 0.2, 0.9, 1.0, 0.2, 0.1],
            trackDuration: 60
        )
        let candidates = AnthemCandidateScorer.rankedCandidates(
            from: frames,
            preferredDuration: 20,
            maximumCount: 3
        )

        XCTAssertFalse(candidates.isEmpty)
        XCTAssertEqual(candidates[0].startTime, 20, accuracy: 0.0001)
        XCTAssertEqual(candidates[0].score, 0.95, accuracy: 0.0001)
    }

    func testSuppressesHeavilyOverlappingCandidates() {
        let frames = AnthemAnalysisFoundation.frames(
            from: [1.0, 0.9, 0.8, 0.7, 0.2],
            trackDuration: 50
        )
        let candidates = AnthemCandidateScorer.rankedCandidates(
            from: frames,
            preferredDuration: 30,
            maximumCount: 5,
            maximumOverlapRatio: 0.50
        )

        XCTAssertGreaterThanOrEqual(candidates.count, 1)
        if candidates.count > 1 {
            XCTAssertGreaterThanOrEqual(
                candidates[1].startTime,
                candidates[0].endTime - 15
            )
        }
    }

    func testEqualScoresUseEarlierStartAsDeterministicTieBreak() {
        let frames = AnthemAnalysisFoundation.frames(
            from: [0.5, 0.5, 0.5, 0.5],
            trackDuration: 40
        )
        let candidates = AnthemCandidateScorer.rankedCandidates(
            from: frames,
            preferredDuration: 10,
            maximumCount: 4,
            maximumOverlapRatio: 0
        )

        XCTAssertEqual(candidates.map(\.startTime), [0, 10, 20, 30])
    }

    func testCandidateEndDoesNotExtendBeyondAvailableFrames() {
        let frames = AnthemAnalysisFoundation.frames(
            from: [0.2, 0.8],
            trackDuration: 8
        )
        let candidates = AnthemCandidateScorer.rankedCandidates(
            from: frames,
            preferredDuration: 20,
            maximumCount: 2
        )

        XCTAssertTrue(candidates.allSatisfy { $0.startTime >= 0 && $0.endTime <= 8 })
    }

    func testShortTrackStillProducesCandidate() {
        let frames = AnthemAnalysisFoundation.frames(from: [0.7], trackDuration: 3)
        let candidates = AnthemCandidateScorer.rankedCandidates(
            from: frames,
            preferredDuration: 20
        )

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].startTime, 0, accuracy: 0.0001)
        XCTAssertEqual(candidates[0].endTime, 3, accuracy: 0.0001)
    }

    func testSilentInputIsDeterministic() {
        let frames = AnthemAnalysisFoundation.frames(
            from: [0, 0, 0],
            trackDuration: 30
        )
        let first = AnthemCandidateScorer.rankedCandidates(
            from: frames,
            preferredDuration: 10,
            maximumCount: 3,
            maximumOverlapRatio: 0
        )
        let second = AnthemCandidateScorer.rankedCandidates(
            from: frames,
            preferredDuration: 10,
            maximumCount: 3,
            maximumOverlapRatio: 0
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.map(\.startTime), [0, 10, 20])
        XCTAssertTrue(first.allSatisfy { $0.score == 0 })
    }

    func testInvalidConfigurationReturnsNoCandidates() {
        let frames = AnthemAnalysisFoundation.frames(from: [1], trackDuration: 1)

        XCTAssertTrue(AnthemCandidateScorer.rankedCandidates(from: []).isEmpty)
        XCTAssertTrue(AnthemCandidateScorer.rankedCandidates(from: frames, preferredDuration: 0).isEmpty)
        XCTAssertTrue(AnthemCandidateScorer.rankedCandidates(from: frames, maximumCount: 0).isEmpty)
        XCTAssertTrue(AnthemCandidateScorer.rankedCandidates(from: frames, maximumOverlapRatio: .nan).isEmpty)
    }
}

extension AnthemCandidateScorerTests {
    func testDurationWeightedCandidateScoreUsesUnequalFrameDurations() {
        let frames = [AnthemAnalysisFrame(startTime: 0, duration: 1, energy: 1), AnthemAnalysisFrame(startTime: 1, duration: 3, energy: 0)]
        let result = AnthemCandidateScorer.rankedCandidates(from: frames, preferredDuration: 4, maximumCount: 1)
        XCTAssertEqual(result.first?.score ?? -1, 0.25, accuracy: 0.0001)
    }
}
