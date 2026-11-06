import XCTest
@testable import DJAnthemMapper

@MainActor
final class AnthemVocalAnalysisAcceptanceTests: XCTestCase {
    private let waveform: [Float] = [
        0.10, 0.35, 0.90, 0.55, 0.15,
        0.10, 0.40, 0.88, 0.52, 0.12,
        0.10, 0.38, 0.86, 0.50, 0.10
    ]
    private let trackDuration: TimeInterval = 150
    private let sampleRate: UInt32 = 10

    private func request() -> AnalysisAudioDecodeRequest {
        .init(sourceURL: URL(fileURLWithPath: "/tmp/D11.wav"))
    }

    private func structuralBaseline() -> AnthemStructuralAnalysisResult {
        AnthemStructuralAnalysisPipeline.analyse(
            waveformSamples: waveform,
            trackDuration: trackDuration
        )
    }

    private func pcm(
        valueAtTime: (TimeInterval) -> Float
    ) throws -> VocalSeparationPCM {
        let frameCount = Int(trackDuration * Double(sampleRate))
        precondition(frameCount > 0)
        let samples = (0..<frameCount).map { index in
            valueAtTime(Double(index) / Double(sampleRate))
        }
        return try VocalSeparationPCM(
            left: samples,
            right: samples,
            sampleRate: sampleRate
        )
    }

    private func constantPCM(_ value: Float) throws -> VocalSeparationPCM {
        try pcm { _ in value }
    }

    private func positiveAdjustmentPCM() throws -> VocalSeparationPCM {
        try pcm { time in
            Int(time) % 2 == 0 ? 1.0 : 0.10
        }
    }

    private func patternedPCM(
        strongRange: Range<TimeInterval>,
        weakRange: Range<TimeInterval>
    ) throws -> VocalSeparationPCM {
        try pcm { time in
            if strongRange.contains(time) { return 1.0 }
            if weakRange.contains(time) { return 0.02 }
            return 0.50
        }
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

    private func clamp(_ value: Float) -> Float {
        min(1, max(0, value))
    }

    func testEndToEndPositiveVocalInfluenceIsAuditableAndBounded() async throws {
        let vocalPCM = try positiveAdjustmentPCM()
        let result = try await AnthemVocalAnalysisPipeline.analyse(
            waveformSamples: waveform,
            trackDuration: trackDuration,
            request: request(),
            separateVocals: { _ in vocalPCM }
        )

        XCTAssertEqual(result.status, .adjusted)
        XCTAssertFalse(result.candidates.isEmpty)
        XCTAssertTrue(result.candidates.contains { item in
            guard let score = item.vocalScore else { return false }
            return score.transitionStrength > 0.5 &&
                score.sustainedStrength > 0 &&
                score.overallStrength > 0.5 &&
                item.vocalAdjustment > 0.000001
        })

        for item in result.candidates {
            XCTAssertNotNil(item.vocalEvidence)
            XCTAssertNotNil(item.vocalScore)
            XCTAssertTrue((-0.10...0.10).contains(item.vocalAdjustment))
            XCTAssertEqual(
                item.finalScore,
                clamp(item.baseline.compositeScore + item.vocalAdjustment),
                accuracy: 0.000001
            )
        }
    }

    func testControlledCandidateSpecificVocalsCanRefineCloseRanking() async throws {
        let baseline = structuralBaseline()
        XCTAssertEqual(baseline.status, .analysed)
        XCTAssertGreaterThanOrEqual(baseline.candidates.count, 2)

        let pairs = baseline.candidates.enumerated().flatMap { leftIndex, left in
            baseline.candidates.dropFirst(leftIndex + 1).map { right in (left, right) }
        }
        guard let pair = pairs.min(by: {
            abs($0.0.compositeScore - $0.1.compositeScore) <
            abs($1.0.compositeScore - $1.1.compositeScore)
        }) else {
            return XCTFail("Expected at least one candidate pair")
        }

        let first = pair.0
        let second = pair.1
        let difference = abs(first.compositeScore - second.compositeScore)
        XCTAssertLessThan(difference, 0.20, "Fixture must provide candidates close enough for bounded vocal refinement")

        let lower = first.compositeScore <= second.compositeScore ? first : second
        let higher = first.compositeScore <= second.compositeScore ? second : first
        let vocalPCM = try patternedPCM(
            strongRange: lower.candidate.startTime..<lower.candidate.endTime,
            weakRange: higher.candidate.startTime..<higher.candidate.endTime
        )

        let result = try await AnthemVocalAnalysisPipeline.analyse(
            waveformSamples: waveform,
            trackDuration: trackDuration,
            request: request(),
            separateVocals: { _ in vocalPCM }
        )

        XCTAssertEqual(result.status, .adjusted)
        guard let lowerResult = result.candidates.first(where: { $0.baseline.candidate == lower.candidate }),
              let higherResult = result.candidates.first(where: { $0.baseline.candidate == higher.candidate }) else {
            return XCTFail("Expected both structural candidates to survive D9")
        }
        XCTAssertGreaterThan(lowerResult.vocalAdjustment, higherResult.vocalAdjustment)
        let adjustmentSwing = lowerResult.vocalAdjustment - higherResult.vocalAdjustment
        XCTAssertGreaterThan(
            adjustmentSwing,
            difference,
            "Controlled vocal fixture must be strong enough to rerank the selected close candidates"
        )
        XCTAssertGreaterThan(lowerResult.finalScore, higherResult.finalScore)
    }

    func testBoundedVocalsCannotOverturnBaselineLeadGreaterThanMaximumPairwiseSwing() {
        let strongCandidate = AnthemCandidate(startTime: 0, endTime: 10, score: 1.0)
        let weakCandidate = AnthemCandidate(startTime: 20, endTime: 30, score: 0.0)
        let strongBaseline = AnthemCompositeCandidate(
            candidate: strongCandidate,
            structuralEvidence: nil,
            originalScore: 1.0,
            structuralStrength: 1.0,
            compositeScore: 1.0
        )
        let weakBaseline = AnthemCompositeCandidate(
            candidate: weakCandidate,
            structuralEvidence: nil,
            originalScore: 0.0,
            structuralStrength: 0.0,
            compositeScore: 0.0
        )
        XCTAssertGreaterThan(strongBaseline.compositeScore - weakBaseline.compositeScore, 0.20)

        let strongEvidence = AnthemCandidateVocalEvidence(
            candidateStartTime: strongCandidate.startTime,
            candidateEndTime: strongCandidate.endTime,
            transitionEvidence: [.init(startTime: 0, endTime: 1, riseStrength: 0, fallStrength: 0, entryStrength: 0, exitStrength: 0)],
            sustainedEvidence: []
        )
        let weakEvidence = AnthemCandidateVocalEvidence(
            candidateStartTime: weakCandidate.startTime,
            candidateEndTime: weakCandidate.endTime,
            transitionEvidence: [.init(startTime: 20, endTime: 21, riseStrength: 1, fallStrength: 0, entryStrength: 0, exitStrength: 0)],
            sustainedEvidence: []
        )

        let result = AnthemVocalAdjustedCompositeScorer.rank(
            baseline: [weakBaseline, strongBaseline],
            vocalEvidence: [strongEvidence, weakEvidence]
        )
        XCTAssertEqual(result.first?.baseline.candidate, strongCandidate)
        XCTAssertTrue(result.allSatisfy { (-0.10...0.10).contains($0.vocalAdjustment) })
    }

    func testValidSilenceIsExactlyNeutralEndToEnd() async throws {
        let baseline = structuralBaseline()
        let silent = try constantPCM(0)
        let result = try await AnthemVocalAnalysisPipeline.analyse(
            waveformSamples: waveform,
            trackDuration: trackDuration,
            request: request(),
            separateVocals: { _ in silent }
        )
        assertExactStructuralFallback(result, baseline: baseline)
    }

    func testOrdinaryVocalFailureIsExactlyNeutralEndToEnd() async throws {
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

    func testCancellationRemainsCancellation() async {
        do {
            _ = try await AnthemVocalAnalysisPipeline.analyse(
                waveformSamples: waveform,
                trackDuration: trackDuration,
                request: request(),
                separateVocals: { _ in throw CancellationError() }
            )
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAdjustedResultsPreserveCandidateIdentityProvenanceAndBounds() async throws {
        let baseline = structuralBaseline()
        let vocalPCM = try constantPCM(0.80)
        let result = try await AnthemVocalAnalysisPipeline.analyse(
            waveformSamples: waveform,
            trackDuration: trackDuration,
            request: request(),
            separateVocals: { _ in vocalPCM }
        )

        XCTAssertEqual(result.status, .adjusted)
        let actualCandidates = result.candidates.map { $0.baseline.candidate }
        let expectedCandidates = baseline.candidates.map(\.candidate)
        XCTAssertEqual(actualCandidates.count, expectedCandidates.count)
        XCTAssertTrue(actualCandidates.allSatisfy { expectedCandidates.contains($0) })
        XCTAssertTrue(expectedCandidates.allSatisfy { actualCandidates.contains($0) })

        for item in result.candidates {
            XCTAssertNotNil(item.vocalEvidence)
            guard let vocalScore = item.vocalScore else {
                return XCTFail("Adjusted candidate must preserve its D7 vocal score")
            }
            XCTAssertTrue((0...1).contains(vocalScore.transitionStrength))
            XCTAssertTrue((0...1).contains(vocalScore.sustainedStrength))
            XCTAssertTrue((0...1).contains(vocalScore.overallStrength))
            XCTAssertTrue((-0.10...0.10).contains(item.vocalAdjustment))
            XCTAssertTrue((0...1).contains(item.finalScore))
            XCTAssertTrue(item.finalScore.isFinite)
            XCTAssertEqual(item.finalScore, clamp(item.baseline.compositeScore + item.vocalAdjustment), accuracy: 0.000001)
        }
    }

    func testControlledEndToEndAnalysisIsDeterministic() async throws {
        let vocalPCM = try constantPCM(0.80)
        let first = try await AnthemVocalAnalysisPipeline.analyse(
            waveformSamples: waveform,
            trackDuration: trackDuration,
            request: request(),
            separateVocals: { _ in vocalPCM }
        )
        let second = try await AnthemVocalAnalysisPipeline.analyse(
            waveformSamples: waveform,
            trackDuration: trackDuration,
            request: request(),
            separateVocals: { _ in vocalPCM }
        )
        XCTAssertEqual(first.status, .adjusted)
        XCTAssertEqual(second.status, .adjusted)
        XCTAssertEqual(first, second)
    }
}
