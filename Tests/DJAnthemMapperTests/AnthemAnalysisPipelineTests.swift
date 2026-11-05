import XCTest
@testable import DJAnthemMapper

final class AnthemAnalysisPipelineTests: XCTestCase {
    func testPipelineProducesEvidenceBackedCandidates() {
        let result = AnthemAnalysisPipeline.analyse(
            waveformSamples: [0.1, 0.2, 0.9, 1.0, 0.2, 0.1],
            trackDuration: 60
        )
        XCTAssertEqual(result.status, .analysed)
        XCTAssertFalse(result.candidates.isEmpty)
        XCTAssertEqual(result.candidates[0].candidate.startTime, 20, accuracy: 0.0001)
        XCTAssertEqual(result.candidates[0].candidate, result.candidates[0].evidence.candidate)
    }

    func testMaximumCandidateCountPropagates() {
        var config = AnthemAnalysisConfiguration()
        config.maximumCandidateCount = 2
        let result = AnthemAnalysisPipeline.analyse(waveformSamples: [0.2, 0.8, 0.2, 0.8, 0.2], trackDuration: 50, configuration: config)
        XCTAssertLessThanOrEqual(result.candidates.count, 2)
    }

    func testPreferredDurationPropagates() {
        var config = AnthemAnalysisConfiguration()
        config.preferredCandidateDuration = 10
        config.maximumCandidateCount = 1
        let result = AnthemAnalysisPipeline.analyse(waveformSamples: [0.1, 1.0, 0.1], trackDuration: 30, configuration: config)
        XCTAssertEqual(result.candidates.first?.candidate.duration ?? -1, 10, accuracy: 0.0001)
    }

    func testEmptyAndInvalidDurationAreInvalidInput() {
        XCTAssertEqual(AnthemAnalysisPipeline.analyse(waveformSamples: [], trackDuration: 10).status, .invalidInput)
        XCTAssertEqual(AnthemAnalysisPipeline.analyse(waveformSamples: [1], trackDuration: 0).status, .invalidInput)
        XCTAssertEqual(AnthemAnalysisPipeline.analyse(waveformSamples: [1], trackDuration: .nan).status, .invalidInput)
    }

    func testInvalidConfigurationRejected() {
        var config = AnthemAnalysisConfiguration()
        config.maximumCandidateCount = 0
        XCTAssertEqual(AnthemAnalysisPipeline.analyse(waveformSamples: [1], trackDuration: 1, configuration: config).status, .invalidInput)
    }

    func testSilentWaveformIsValidAnalysis() {
        let result = AnthemAnalysisPipeline.analyse(waveformSamples: [0, 0, 0], trackDuration: 30)
        XCTAssertEqual(result.status, .analysed)
        XCTAssertFalse(result.candidates.isEmpty)
    }

    func testRepeatedAnalysisIsDeterministic() {
        let samples: [Float] = [0.2, 0.8, 0.8, 0.2]
        XCTAssertEqual(
            AnthemAnalysisPipeline.analyse(waveformSamples: samples, trackDuration: 40),
            AnthemAnalysisPipeline.analyse(waveformSamples: samples, trackDuration: 40)
        )
    }

    func testCandidatesRemainWithinTrackBounds() {
        let duration: Double = 8
        let result = AnthemAnalysisPipeline.analyse(waveformSamples: [0.2, 0.8], trackDuration: duration)
        XCTAssertTrue(result.candidates.allSatisfy {
            $0.candidate.startTime >= 0 && $0.candidate.endTime <= duration
        })
    }

    func testPipelinePreservesScorerOrdering() {
        let samples: [Float] = [0.1, 0.2, 0.9, 1.0, 0.2, 0.1]
        let duration: Double = 60
        let frames = AnthemAnalysisFoundation.frames(from: samples, trackDuration: duration)
        let expected = AnthemCandidateScorer.rankedCandidates(from: frames)
        let result = AnthemAnalysisPipeline.analyse(waveformSamples: samples, trackDuration: duration)
        XCTAssertEqual(result.candidates.map(\.candidate), expected)
    }
}
