import XCTest
@testable import DJAnthemMapper

final class AnthemRepetitionAnalyserTests: XCTestCase {
    private func frames(_ values: [Float]) -> [AnthemAnalysisFrame] {
        AnthemAnalysisFoundation.frames(from: values, trackDuration: Double(max(1, values.count)))
    }

    func testExactSeparatedRepetitionScoresHighly() {
        let result = AnthemRepetitionAnalyser.analyse(frames: frames([0.1,0.4,0.9,0.5, 0.2,0.2,0.2,0.2, 0.1,0.4,0.9,0.5]))
        XCTAssertGreaterThan(result[0].bestSimilarity, 0.99)
        XCTAssertFalse(result[0].matches.isEmpty)
    }

    func testSimilarShapeAtDifferentLevelScoresHighly() {
        let result = AnthemRepetitionAnalyser.analyse(frames: frames([0.2,0.5,0.9,0.6, 0.5,0.5,0.5,0.5, 0.1,0.4,0.8,0.5]))
        XCTAssertGreaterThan(result[0].bestSimilarity, 0.9)
    }

    func testDifferentShapeDoesNotMeetHighThreshold() {
        var config = AnthemRepetitionConfiguration()
        config.similarityThreshold = 0.95
        let result = AnthemRepetitionAnalyser.analyse(frames: frames([0.1,0.4,0.9,0.5, 0.5,0.5,0.5,0.5, 0.9,0.1,0.2,0.8]), configuration: config)
        XCTAssertTrue(result[0].matches.isEmpty)
    }

    func testSilentAndFlatWindowsAreNeutral() {
        let silent = AnthemRepetitionAnalyser.analyse(frames: frames(Array(repeating: 0, count: 8)))
        let loud = AnthemRepetitionAnalyser.analyse(frames: frames(Array(repeating: 0.9, count: 8)))
        XCTAssertTrue(silent.allSatisfy { $0.bestSimilarity == 0 && $0.repetitionStrength == 0 })
        XCTAssertTrue(loud.allSatisfy { $0.bestSimilarity == 0 && $0.repetitionStrength == 0 })
    }

    func testSelfAndHeavyOverlapAreExcluded() {
        let result = AnthemRepetitionAnalyser.analyse(frames: frames([0.1,0.4,0.9,0.5,0.1,0.4,0.9,0.5]))
        XCTAssertTrue(result[0].matches.allSatisfy { $0.matchStartTime != result[0].sourceStartTime })
    }

    func testInvalidConfigurationReturnsEmpty() {
        var config = AnthemRepetitionConfiguration()
        config.comparisonWindowDuration = 0
        XCTAssertTrue(AnthemRepetitionAnalyser.analyse(frames: frames([0.1,0.4,0.9,0.5]), configuration: config).isEmpty)
    }

    func testInputShorterThanWindowUsesActualAvailableRange() {
        var config = AnthemRepetitionConfiguration()
        config.comparisonWindowDuration = 4
        let result = AnthemRepetitionAnalyser.analyse(
            frames: frames([0.1,0.8]),
            configuration: config
        )
        XCTAssertFalse(result.isEmpty)
        XCTAssertEqual(result.first?.sourceStartTime ?? -1, 0, accuracy: 0.0001)
        XCTAssertEqual(result.first?.sourceEndTime ?? -1, 2, accuracy: 0.0001)
        XCTAssertTrue(result.allSatisfy {
            $0.sourceStartTime.isFinite &&
            $0.sourceEndTime.isFinite &&
            $0.sourceEndTime <= 2 &&
            $0.bestSimilarity.isFinite &&
            $0.repetitionStrength.isFinite
        })
    }

    func testUnsortedInputIsDeterministic() {
        let input = frames([0.1,0.4,0.9,0.5,0.2,0.1,0.4,0.9,0.5])
        XCTAssertEqual(AnthemRepetitionAnalyser.analyse(frames: input), AnthemRepetitionAnalyser.analyse(frames: input.reversed()))
    }

    func testRepeatedAnalysisIsDeterministic() {
        let input = frames([0.1,0.4,0.9,0.5,0.2,0.1,0.4,0.9,0.5])
        XCTAssertEqual(AnthemRepetitionAnalyser.analyse(frames: input), AnthemRepetitionAnalyser.analyse(frames: input))
    }

    func testScoresAreNormalised() {
        let result = AnthemRepetitionAnalyser.analyse(frames: frames([0.1,0.4,0.9,0.5,0.2,0.1,0.4,0.9,0.5]))
        XCTAssertTrue(result.allSatisfy { (0...1).contains($0.bestSimilarity) && (0...1).contains($0.repetitionStrength) && $0.matches.allSatisfy { (0...1).contains($0.similarity) } })
    }

    func testMaximumMatchesIsRespected() {
        var config = AnthemRepetitionConfiguration()
        config.maximumMatches = 1
        let result = AnthemRepetitionAnalyser.analyse(frames: frames([0.1,0.4,0.9,0.5,0, 0.1,0.4,0.9,0.5,0, 0.1,0.4,0.9,0.5]), configuration: config)
        XCTAssertTrue(result.allSatisfy { $0.matches.count <= 1 })
    }

    func testModeratelyLargeInputCompletesWithFiniteResults() {
        let values = (0..<240).map { Float(($0 % 12)) / 11 }
        let result = AnthemRepetitionAnalyser.analyse(frames: frames(values))
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { $0.bestSimilarity.isFinite && $0.repetitionStrength.isFinite })
    }
}
