import Foundation
import Demucs

struct VocalSeparationPCM: Equatable, Sendable {
    let left: [Float]
    let right: [Float]
    let sampleRate: UInt32

    init(left: [Float], right: [Float], sampleRate: UInt32) throws {
        guard sampleRate > 0 else { throw VocalSeparationError.invalidSampleRate }
        guard !left.isEmpty, left.count == right.count else { throw VocalSeparationError.invalidStereoInput }
        guard left.allSatisfy(\.isFinite), right.allSatisfy(\.isFinite) else { throw VocalSeparationError.nonFiniteSamples }
        self.left = left
        self.right = right
        self.sampleRate = sampleRate
    }
}

enum VocalSeparationError: Error, Equatable, Sendable {
    case invalidSampleRate
    case invalidStereoInput
    case nonFiniteSamples
    case noVocalStem
    case modelUnavailable
    case separationFailed
}

@MainActor
protocol VocalSeparationBackend: AnyObject {
    func prepare() async throws
    func separate(_ input: VocalSeparationPCM) async throws -> VocalSeparationPCM
}

@MainActor
final class HTDemucsVocalBackend: VocalSeparationBackend {
    private let model: DemucsModel
    private let engine: DemucsEngine
    private var prepared = false

    init(model: DemucsModel) {
        self.model = model
        self.engine = DemucsEngine()
    }

    convenience init() {
        self.init(model: HTDemucsVocalModelConfiguration.model)
    }

    func prepare() async throws {
        guard !prepared else { return }
        do {
            if !DemucsEngine.isDownloaded(model) {
                try await DemucsEngine.download(model)
            }
            _ = try await engine.load(model)
            try await engine.warmup()
            prepared = true
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw VocalSeparationError.modelUnavailable
        }
    }

    func separate(_ input: VocalSeparationPCM) async throws -> VocalSeparationPCM {
        if !prepared { try await prepare() }
        do {
            let stems = try await engine.separate(left: input.left, right: input.right, sampleRate: input.sampleRate)
            guard let vocal = stems.first(where: { $0.kind == .vocals }) else { throw VocalSeparationError.noVocalStem }
            return try VocalSeparationPCM(left: vocal.left, right: vocal.right, sampleRate: input.sampleRate)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as VocalSeparationError {
            throw error
        } catch {
            throw VocalSeparationError.separationFailed
        }
    }
}

@MainActor
final class HTDemucsVocalSeparator {
    private let backend: any VocalSeparationBackend

    init(backend: any VocalSeparationBackend) {
        self.backend = backend
    }

    convenience init() {
        self.init(backend: HTDemucsVocalBackend())
    }

    func prepare() async throws {
        try Task.checkCancellation()
        try await backend.prepare()
        try Task.checkCancellation()
    }

    func separate(left: [Float], right: [Float], sampleRate: UInt32) async throws -> VocalSeparationPCM {
        try Task.checkCancellation()
        let input = try VocalSeparationPCM(left: left, right: right, sampleRate: sampleRate)
        try await backend.prepare()
        try Task.checkCancellation()
        let output = try await backend.separate(input)
        try Task.checkCancellation()
        return output
    }
}
