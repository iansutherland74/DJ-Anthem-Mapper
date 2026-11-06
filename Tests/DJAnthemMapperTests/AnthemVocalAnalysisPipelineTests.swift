import XCTest
@testable import DJAnthemMapper

@MainActor
final class AnthemVocalAnalysisPipelineTests: XCTestCase {
    private func request() -> AnalysisAudioDecodeRequest {
        .init(sourceURL: URL(fileURLWithPath: "/tmp/D9.wav"))
    }
    private func vocalPCM(value: Float = 0.8) throws -> VocalSeparationPCM {
        try VocalSeparationPCM(left: .init(repeating: value, count: 400), right: .init(repeating: value, count: 400), sampleRate: 10)
    }
    private let waveform: [Float] = [0.1,0.4,0.9,0.5,0.2,0.1,0.4,0.9,0.5]

    func testSuccessfulVocalAnalysisProducesAuditableCandidates() async throws {
        let result = try await AnthemVocalAnalysisPipeline.analyse(waveformSamples: waveform, trackDuration: 90, request: request(), separateVocals: { _ in try self.vocalPCM() })
        XCTAssertFalse(result.candidates.isEmpty)
        XCTAssertTrue(result.candidates.allSatisfy { $0.finalScore.isFinite && (0...1).contains($0.finalScore) })
        XCTAssertTrue(result.candidates.allSatisfy { $0.vocalEvidence != nil })
    }

    func testDecodeOrSeparatorFailureFallsBackToStructuralResults() async throws {
        enum Marker: Error { case failed }
        let structural = AnthemStructuralAnalysisPipeline.analyse(waveformSamples: waveform, trackDuration: 90)
        let result = try await AnthemVocalAnalysisPipeline.analyse(waveformSamples: waveform, trackDuration: 90, request: request(), separateVocals: { _ in throw Marker.failed })
        XCTAssertEqual(result.status, .structuralFallback)
        XCTAssertEqual(result.candidates.map(\.finalScore), structural.candidates.map(\.compositeScore))
        XCTAssertTrue(result.candidates.allSatisfy { $0.vocalAdjustment == 0 && $0.vocalScore == nil })
    }

    func testCancellationErrorPropagates() async {
        do {
            _ = try await AnthemVocalAnalysisPipeline.analyse(waveformSamples: waveform, trackDuration: 90, request: request(), separateVocals: { _ in throw CancellationError() })
            XCTFail("Expected cancellation")
        } catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
    }

    func testInvalidStructuralInputDoesNotStartVocalSeparation() async throws {
        var called = false
        let result = try await AnthemVocalAnalysisPipeline.analyse(waveformSamples: [], trackDuration: 90, request: request(), separateVocals: { _ in called = true; return try self.vocalPCM() })
        XCTAssertEqual(result.status, .invalidInput)
        XCTAssertFalse(called)
    }

    func testNoStructuralCandidatesDoesNotStartVocalSeparation() async throws {
        var called = false
        let result = try await AnthemVocalAnalysisPipeline.analyse(waveformSamples: [0,0,0,0], trackDuration: 40, request: request(), separateVocals: { _ in called = true; return try self.vocalPCM() })
        XCTAssertEqual(result.status, .noCandidates)
        XCTAssertFalse(called)
    }

    func testSilentValidVocalPCMFallsBackWithoutPenalty() async throws {
        let silent = try VocalSeparationPCM(
            left: .init(repeating: 0, count: 400),
            right: .init(repeating: 0, count: 400),
            sampleRate: 10
        )
        let structural = AnthemStructuralAnalysisPipeline.analyse(waveformSamples: waveform, trackDuration: 90)
        let result = try await AnthemVocalAnalysisPipeline.analyse(
            waveformSamples: waveform,
            trackDuration: 90,
            request: request(),
            separateVocals: { _ in silent }
        )
        XCTAssertEqual(result.status, .structuralFallback)
        XCTAssertEqual(result.candidates.map(\.finalScore), structural.candidates.map(\.compositeScore))
        XCTAssertTrue(result.candidates.allSatisfy {
            $0.vocalEvidence == nil && $0.vocalScore == nil && $0.vocalAdjustment == 0
        })
    }

    func testRepeatedControlledAnalysisIsDeterministic() async throws {
        let pcm = try vocalPCM()
        let first = try await AnthemVocalAnalysisPipeline.analyse(waveformSamples: waveform, trackDuration: 90, request: request(), separateVocals: { _ in pcm })
        let second = try await AnthemVocalAnalysisPipeline.analyse(waveformSamples: waveform, trackDuration: 90, request: request(), separateVocals: { _ in pcm })
        XCTAssertEqual(first, second)
    }

    func testOutputOrderingIsDescendingByFinalScore() async throws {
        let pcm = try vocalPCM()
        let result = try await AnthemVocalAnalysisPipeline.analyse(waveformSamples: waveform, trackDuration: 90, request: request(), separateVocals: { _ in pcm })
        XCTAssertEqual(result.candidates.map(\.finalScore), result.candidates.map(\.finalScore).sorted(by: >))
    }
}
