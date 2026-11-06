import XCTest
@testable import DJAnthemMapper

@MainActor
final class AnalysisVocalSeparationBridgeTests: XCTestCase {
    private func request() -> AnalysisAudioDecodeRequest {
        AnalysisAudioDecodeRequest(sourceURL: URL(fileURLWithPath: "/tmp/C5.wav"))
    }

    func testDecodedPCMIsPassedExactlyToSeparatorAndOutputReturned() async throws {
        let input = try AnalysisAudioPCM(left: [0.1, 0.2], right: [0.3, 0.4], sampleRate: 48_000)
        let expected = try VocalSeparationPCM(left: [0.5, 0.6], right: [0.7, 0.8], sampleRate: 48_000)
        var receivedLeft: [Float] = []
        var receivedRight: [Float] = []
        var receivedRate: UInt32 = 0
        let bridge = AnalysisVocalSeparationBridge(
            decode: { _ in input },
            separate: { left, right, rate in
                receivedLeft = left; receivedRight = right; receivedRate = rate
                return expected
            }
        )
        let result = try await bridge.separateVocals(request: request())
        XCTAssertEqual(result, expected)
        XCTAssertEqual(receivedLeft, input.left)
        XCTAssertEqual(receivedRight, input.right)
        XCTAssertEqual(receivedRate, input.sampleRate)
    }

    func testDecodeFailureDoesNotStartSeparation() async {
        enum Marker: Error { case decode }
        var separationCalled = false
        let bridge = AnalysisVocalSeparationBridge(
            decode: { _ in throw Marker.decode },
            separate: { _, _, _ in separationCalled = true; throw Marker.decode }
        )
        do { _ = try await bridge.separateVocals(request: request()); XCTFail("Expected decode failure") }
        catch Marker.decode { XCTAssertFalse(separationCalled) }
        catch { XCTFail("Unexpected error: \(error)") }
    }

    func testSeparatorFailurePropagates() async throws {
        enum Marker: Error { case separator }
        let input = try AnalysisAudioPCM(left: [0], right: [0], sampleRate: 44_100)
        let bridge = AnalysisVocalSeparationBridge(
            decode: { _ in input },
            separate: { _, _, _ in throw Marker.separator }
        )
        do { _ = try await bridge.separateVocals(request: request()); XCTFail("Expected separator failure") }
        catch Marker.separator {}
        catch { XCTFail("Unexpected error: \(error)") }
    }

    func testPreCancelledTaskDoesNotDecode() async {
        var decodeCalled = false
        let bridge = AnalysisVocalSeparationBridge(
            decode: { _ in decodeCalled = true; return try AnalysisAudioPCM(left: [0], right: [0], sampleRate: 44_100) },
            separate: { _, _, _ in try VocalSeparationPCM(left: [0], right: [0], sampleRate: 44_100) }
        )
        let task = Task { try await bridge.separateVocals(request: request()) }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled bridge unexpectedly succeeded") }
        catch is CancellationError { XCTAssertFalse(decodeCalled) }
        catch { XCTFail("Unexpected error: \(error)") }
    }
}
