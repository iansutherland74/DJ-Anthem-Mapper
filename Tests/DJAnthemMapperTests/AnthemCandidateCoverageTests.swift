import XCTest
@testable import DJAnthemMapper

final class AnthemCandidateCoverageTests: XCTestCase {
    func testDefaultCoveragePolicyIsSeventyFivePercent() {
        let config = AnthemAnalysisConfiguration()
        XCTAssertEqual(config.minimumCandidateCoverageRatio, 0.75, accuracy: 0.0001)
        XCTAssertTrue(config.isValid)
    }

    func testInvalidCoveragePolicyRejected() {
        var config = AnthemAnalysisConfiguration()
        config.minimumCandidateCoverageRatio = 0
        XCTAssertFalse(config.isValid)
        config.minimumCandidateCoverageRatio = -0.1
        XCTAssertFalse(config.isValid)
        config.minimumCandidateCoverageRatio = 1.1
        XCTAssertFalse(config.isValid)
        config.minimumCandidateCoverageRatio = .nan
        XCTAssertFalse(config.isValid)
    }

    func testShortTailCandidateBelowCoverageIsRejected() {
        let frames = [
            AnthemAnalysisFrame(startTime: 0, duration: 5, energy: 0.2),
            AnthemAnalysisFrame(startTime: 5, duration: 5, energy: 0.2),
            AnthemAnalysisFrame(startTime: 10, duration: 5, energy: 0.2),
            AnthemAnalysisFrame(startTime: 15, duration: 5, energy: 0.2),
            AnthemAnalysisFrame(startTime: 20, duration: 5, energy: 1.0)
        ]
        let result = AnthemCandidateScorer.rankedCandidates(from: frames, preferredDuration: 20, maximumCount: 10, maximumOverlapRatio: 1, minimumCoverageRatio: 0.75)
        XCTAssertFalse(result.contains(where: { $0.startTime == 20 }))
    }

    func testCandidateAtExactlyCoverageThresholdIsAccepted() {
        let frames = [
            AnthemAnalysisFrame(startTime: 0, duration: 5, energy: 0.1),
            AnthemAnalysisFrame(startTime: 5, duration: 5, energy: 0.4),
            AnthemAnalysisFrame(startTime: 10, duration: 5, energy: 0.8),
            AnthemAnalysisFrame(startTime: 15, duration: 5, energy: 0.9)
        ]
        let result = AnthemCandidateScorer.rankedCandidates(from: frames, preferredDuration: 20, maximumCount: 10, maximumOverlapRatio: 1, minimumCoverageRatio: 0.75)
        XCTAssertTrue(result.contains(where: { $0.startTime == 5 && abs($0.duration - 15) < 0.0001 }))
    }

    func testCompleteShortTrackRemainsEligible() {
        let frames = [AnthemAnalysisFrame(startTime: 0, duration: 6, energy: 0.8)]
        let result = AnthemCandidateScorer.rankedCandidates(from: frames, preferredDuration: 20, maximumCount: 5, minimumCoverageRatio: 0.75)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].duration, 6, accuracy: 0.0001)
    }

    func testStructuralPipelineHonoursCoveragePolicy() {
        var config = AnthemStructuralAnalysisConfiguration()
        config.candidateConfiguration.preferredCandidateDuration = 20
        config.candidateConfiguration.minimumCandidateCoverageRatio = 1
        let result = AnthemStructuralAnalysisPipeline.analyse(waveformSamples: [0.2,0.2,0.2,1.0], trackDuration: 40, configuration: config)
        XCTAssertTrue(result.candidates.allSatisfy { abs($0.candidate.duration - 20) < 0.0001 || abs($0.candidate.duration - 40) < 0.0001 })
    }
}
