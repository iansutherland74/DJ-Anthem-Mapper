import XCTest
@testable import DJAnthemMapper

final class AnthemStructuralAnalysisPipelineTests: XCTestCase {
    func testEndToEndResultRetainsAllEvidenceLayers() {
        let result = AnthemStructuralAnalysisPipeline.analyse(
            waveformSamples: [0.1,0.4,0.9,0.5,0.2,0.2,0.1,0.4,0.9,0.5],
            trackDuration: 100
        )
        XCTAssertEqual(result.status, .analysed)
        XCTAssertFalse(result.candidates.isEmpty)
        let first = result.candidates[0]
        XCTAssertEqual(first.energyEvidence.candidate, first.candidate)
        XCTAssertEqual(first.structuralEvidence?.candidate, first.candidate)
        XCTAssertTrue((0...1).contains(first.compositeScore))
    }

    func testInvalidConfigurationIsRejected() {
        var config = AnthemStructuralAnalysisConfiguration()
        config.compositeConfiguration.candidateWeight = 0
        config.compositeConfiguration.structuralWeight = 0
        XCTAssertEqual(AnthemStructuralAnalysisPipeline.analyse(waveformSamples: [1], trackDuration: 1, configuration: config).status, .invalidInput)
    }

    func testEmptyAndInvalidTrackInputRejected() {
        XCTAssertEqual(AnthemStructuralAnalysisPipeline.analyse(waveformSamples: [], trackDuration: 10).status, .invalidInput)
        XCTAssertEqual(AnthemStructuralAnalysisPipeline.analyse(waveformSamples: [1], trackDuration: 0).status, .invalidInput)
        XCTAssertEqual(AnthemStructuralAnalysisPipeline.analyse(waveformSamples: [1], trackDuration: .nan).status, .invalidInput)
    }

    func testCompositeOrderingIsDescending() {
        let result = AnthemStructuralAnalysisPipeline.analyse(waveformSamples: [0.1,0.4,0.9,0.5,0.2,0.1,0.4,0.9,0.5,0.1], trackDuration: 100)
        XCTAssertEqual(result.candidates.map(\.compositeScore), result.candidates.map(\.compositeScore).sorted(by: >))
    }

    func testOriginalScoresRemainUnchanged() {
        let samples: [Float] = [0.1,0.2,0.9,1.0,0.2,0.1]
        let duration: Double = 60
        let frames = AnthemAnalysisFoundation.frames(from: samples, trackDuration: duration)
        let originals = AnthemCandidateScorer.rankedCandidates(from: frames)
        let result = AnthemStructuralAnalysisPipeline.analyse(waveformSamples: samples, trackDuration: duration)
        for item in result.candidates {
            XCTAssertEqual(item.originalScore, originals.first(where: { $0 == item.candidate })?.score ?? -1, accuracy: 0.0001)
        }
    }

    func testRepeatedAnalysisIsDeterministic() {
        let samples: [Float] = [0.1,0.4,0.9,0.5,0.2,0.1,0.4,0.9,0.5]
        XCTAssertEqual(
            AnthemStructuralAnalysisPipeline.analyse(waveformSamples: samples, trackDuration: 90),
            AnthemStructuralAnalysisPipeline.analyse(waveformSamples: samples, trackDuration: 90)
        )
    }

    func testCandidateBoundsStayWithinTrack() {
        let duration: Double = 8
        let result = AnthemStructuralAnalysisPipeline.analyse(waveformSamples: [0.2,0.8], trackDuration: duration)
        XCTAssertTrue(result.candidates.allSatisfy { $0.candidate.startTime >= 0 && $0.candidate.endTime <= duration })
    }

    func testSilentWaveformReturnsNoCandidates() {
        let result = AnthemStructuralAnalysisPipeline.analyse(waveformSamples: [0,0,0,0,0], trackDuration: 50)
        XCTAssertEqual(result.status, .noCandidates)
        XCTAssertTrue(result.candidates.isEmpty)
    }

    func testCustomMaximumCandidateCountPropagates() {
        var config = AnthemStructuralAnalysisConfiguration()
        config.candidateConfiguration.maximumCandidateCount = 2
        let result = AnthemStructuralAnalysisPipeline.analyse(waveformSamples: [0.1,0.8,0.2,0.9,0.3,0.7], trackDuration: 60, configuration: config)
        XCTAssertLessThanOrEqual(result.candidates.count, 2)
    }

    func testCustomCompositeWeightsPropagate() {
        var config = AnthemStructuralAnalysisConfiguration()
        config.compositeConfiguration.candidateWeight = 1
        config.compositeConfiguration.structuralWeight = 0
        let result = AnthemStructuralAnalysisPipeline.analyse(waveformSamples: [0.1,0.8,0.2,0.9], trackDuration: 40, configuration: config)
        XCTAssertTrue(result.candidates.allSatisfy { abs($0.compositeScore - $0.originalScore) < 0.0001 })
    }

    func testModeratelyLargeWaveformProducesFiniteResults() {
        let samples = (0..<240).map { Float($0 % 12) / 11 }
        let result = AnthemStructuralAnalysisPipeline.analyse(waveformSamples: samples, trackDuration: 240)
        XCTAssertNotEqual(result.status, .invalidInput)
        XCTAssertTrue(result.candidates.allSatisfy { $0.compositeScore.isFinite })
    }
}
