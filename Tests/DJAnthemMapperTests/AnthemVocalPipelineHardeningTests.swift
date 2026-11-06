import XCTest
@testable import DJAnthemMapper

@MainActor
final class AnthemVocalPipelineHardeningTests: XCTestCase {
    private let waveform: [Float] = [0.1, 0.4, 0.9, 0.5, 0.2, 0.1, 0.4, 0.9, 0.5]
    private let trackDuration: TimeInterval = 90

    private func request() -> AnalysisAudioDecodeRequest {
        .init(sourceURL: URL(fileURLWithPath: "/tmp/D10.wav"))
    }

    private func validPCM(frames: Int = 400, sampleRate: UInt32 = 10, value: Float = 0.8) throws -> VocalSeparationPCM {
        precondition(frames > 0)
        return try VocalSeparationPCM(
            left: .init(repeating: value, count: frames),
            right: .init(repeating: value, count: frames),
            sampleRate: sampleRate
        )
    }

    private func structuralBaseline() -> AnthemStructuralAnalysisResult {
        AnthemStructuralAnalysisPipeline.analyse(
            waveformSamples: waveform,
            trackDuration: trackDuration
        )
    }

    private func assertExactStructuralFallback(
        _ result: AnthemVocalAnalysisPipelineResult,
        baseline: AnthemStructuralAnalysisResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(result.status, .structuralFallback, file: file, line: line)
        XCTAssertEqual(result.candidates.count, baseline.candidates.count, file: file, line: line)
        for (actual, expected) in zip(result.candidates, baseline.candidates) {
            XCTAssertEqual(actual.baseline, expected, file: file, line: line)
            XCTAssertNil(actual.vocalEvidence, file: file, line: line)
            XCTAssertNil(actual.vocalScore, file: file, line: line)
            XCTAssertEqual(actual.vocalAdjustment, 0, accuracy: 0.000001, file: file, line: line)
            XCTAssertEqual(actual.finalScore, expected.compositeScore, accuracy: 0.000001, file: file, line: line)
        }
    }

    func testOrdinaryVocalFailurePreservesExactStructuralBaseline() async throws {
        enum Marker: Error { case failed }
        let baseline = structuralBaseline()
        let result = try await AnthemVocalAnalysisPipeline.analyse(
            waveformSamples: waveform,
            trackDuration: trackDuration,
            request: request(),
            separateVocals: { _ in throw Marker.failed }
        )
        assertExactStructuralFallback(result, baseline: baseline)
    }

    func testValidSilencePreservesExactStructuralBaselineWithoutPenalty() async throws {
        let baseline = structuralBaseline()
        let silent = try validPCM(value: 0)
        let result = try await AnthemVocalAnalysisPipeline.analyse(
            waveformSamples: waveform,
            trackDuration: trackDuration,
            request: request(),
            separateVocals: { _ in silent }
        )
        assertExactStructuralFallback(result, baseline: baseline)
    }

    func testInvalidStructuralInputNeverStartsVocalWork() async throws {
        var called = false
        let result = try await AnthemVocalAnalysisPipeline.analyse(
            waveformSamples: [], trackDuration: trackDuration, request: request(),
            separateVocals: { _ in called = true; return try self.validPCM() }
        )
        XCTAssertEqual(result.status, .invalidInput)
        XCTAssertFalse(called)
    }

    func testNoStructuralCandidatesNeverStartVocalWork() async throws {
        var called = false
        let result = try await AnthemVocalAnalysisPipeline.analyse(
            waveformSamples: [0, 0, 0, 0], trackDuration: 40, request: request(),
            separateVocals: { _ in called = true; return try self.validPCM() }
        )
        XCTAssertEqual(result.status, .noCandidates)
        XCTAssertFalse(called)
    }

    func testSeparatorCancellationPropagates() async {
        do {
            _ = try await AnthemVocalAnalysisPipeline.analyse(
                waveformSamples: waveform, trackDuration: trackDuration, request: request(),
                separateVocals: { _ in throw CancellationError() }
            )
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMinimumPracticalValidFixtureConstructsBeforePipelineUse() async throws {
        let pcm = try validPCM(frames: 1, sampleRate: 1, value: 0.8)
        XCTAssertEqual(pcm.left.count, 1)
        XCTAssertEqual(pcm.right.count, 1)
        let baseline = structuralBaseline()
        let result = try await AnthemVocalAnalysisPipeline.analyse(
            waveformSamples: waveform, trackDuration: trackDuration, request: request(),
            separateVocals: { _ in pcm }
        )
        XCTAssertEqual(result.candidates.count, baseline.candidates.count)
        XCTAssertTrue(result.status == .adjusted || result.status == .structuralFallback)
        XCTAssertTrue(result.candidates.allSatisfy { $0.finalScore.isFinite && (0...1).contains($0.finalScore) })
    }

    func testIntegratedAdjustmentsRemainBoundedAndFinalScoresMatchFormula() async throws {
        let pcm = try validPCM(value: 0.8)
        let result = try await AnthemVocalAnalysisPipeline.analyse(
            waveformSamples: waveform, trackDuration: trackDuration, request: request(),
            separateVocals: { _ in pcm }
        )
        XCTAssertEqual(result.status, .adjusted)
        for item in result.candidates {
            XCTAssertTrue((-0.10...0.10).contains(item.vocalAdjustment))
            XCTAssertTrue((0...1).contains(item.finalScore))
            let expected = min(Float(1), max(Float(0), item.baseline.compositeScore + item.vocalAdjustment))
            XCTAssertEqual(item.finalScore, expected, accuracy: 0.000001)
        }
    }

    func testSuccessfulPathNeverManufacturesCandidateRanges() async throws {
        let baseline = structuralBaseline()
        let pcm = try validPCM(value: 0.8)
        let result = try await AnthemVocalAnalysisPipeline.analyse(
            waveformSamples: waveform, trackDuration: trackDuration, request: request(),
            separateVocals: { _ in pcm }
        )
        XCTAssertEqual(result.status, .adjusted)
        let actual = result.candidates.map { $0.baseline.candidate }
        let expected = baseline.candidates.map(\.candidate)
        XCTAssertEqual(actual.count, expected.count)
        XCTAssertTrue(actual.allSatisfy { expected.contains($0) })
        XCTAssertTrue(expected.allSatisfy { actual.contains($0) })
    }

    func testControlledIntegratedAnalysisIsDeterministic() async throws {
        let pcm = try validPCM(value: 0.8)
        let first = try await AnthemVocalAnalysisPipeline.analyse(
            waveformSamples: waveform, trackDuration: trackDuration, request: request(),
            separateVocals: { _ in pcm }
        )
        let second = try await AnthemVocalAnalysisPipeline.analyse(
            waveformSamples: waveform, trackDuration: trackDuration, request: request(),
            separateVocals: { _ in pcm }
        )
        XCTAssertEqual(first.status, .adjusted)
        XCTAssertEqual(second.status, .adjusted)
        XCTAssertEqual(first, second)
    }
}
