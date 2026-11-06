import Foundation

enum AnalysisAudioPCMError: Error, Equatable, Sendable {
    case invalidSampleRate
    case invalidStereoInput
    case nonFiniteSamples
}

struct AnalysisAudioPCM: Equatable, Sendable {
    let left: [Float]
    let right: [Float]
    let sampleRate: UInt32

    var frameCount: Int { left.count }

    init(left: [Float], right: [Float], sampleRate: UInt32) throws {
        guard sampleRate > 0 else { throw AnalysisAudioPCMError.invalidSampleRate }
        guard !left.isEmpty, left.count == right.count else {
            throw AnalysisAudioPCMError.invalidStereoInput
        }
        guard left.allSatisfy(\.isFinite), right.allSatisfy(\.isFinite) else {
            throw AnalysisAudioPCMError.nonFiniteSamples
        }
        self.left = left
        self.right = right
        self.sampleRate = sampleRate
    }

    func vocalSeparationPCM() throws -> VocalSeparationPCM {
        try VocalSeparationPCM(left: left, right: right, sampleRate: sampleRate)
    }
}
