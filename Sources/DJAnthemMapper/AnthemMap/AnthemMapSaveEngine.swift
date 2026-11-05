import Foundation

// M3_02A_ANTHEM_MAP_SAVE_ENGINE
enum AnthemMapSaveError: Error, Equatable, Sendable {
    case invalidTrackIdentity
    case invalidTrackDuration
    case tooManyRegions(Int)
    case invalidRegion(slot: Int)
    case invalidDocument([AnthemMapDocument.ValidationError])
    case encodingFailed
    case writeFailed
}

struct AnthemMapSaveRequest: Equatable, Sendable {
    let track: AnthemMapDocument.TrackIdentity
    let regions: [AnthemRegionItem]

    init(track: AnthemMapDocument.TrackIdentity, regions: [AnthemRegionItem]) {
        self.track = track
        self.regions = regions
    }
}

struct AnthemMapSaveEngine: Sendable {
    func makeDocument(from request: AnthemMapSaveRequest) throws -> AnthemMapDocument {
        guard !request.track.fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnthemMapSaveError.invalidTrackIdentity
        }
        guard request.track.durationMilliseconds > 0 else {
            throw AnthemMapSaveError.invalidTrackDuration
        }
        guard request.regions.count <= AnthemMapDocument.maximumRegionCount else {
            throw AnthemMapSaveError.tooManyRegions(request.regions.count)
        }

        var persistentRegions: [AnthemMapDocument.Region] = []
        for (slot, item) in request.regions.enumerated() {
            guard item.isComplete else { continue }
            guard item.isValid, let start = item.start, let end = item.end else {
                throw AnthemMapSaveError.invalidRegion(slot: slot)
            }

            persistentRegions.append(
                AnthemMapDocument.Region(
                    id: item.id,
                    slot: slot,
                    startMilliseconds: milliseconds(from: start),
                    endMilliseconds: milliseconds(from: end)
                )
            )
        }

        let document = AnthemMapDocument(track: request.track, regions: persistentRegions)
        let errors = document.validationErrors()
        guard errors.isEmpty else { throw AnthemMapSaveError.invalidDocument(errors) }
        return document
    }

    func encodedData(for document: AnthemMapDocument) throws -> Data {
        let errors = document.validationErrors()
        guard errors.isEmpty else { throw AnthemMapSaveError.invalidDocument(errors) }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            return try encoder.encode(document)
        } catch {
            throw AnthemMapSaveError.encodingFailed
        }
    }

    func save(document: AnthemMapDocument, to url: URL) throws {
        let data = try encodedData(for: document)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw AnthemMapSaveError.writeFailed
        }
    }

    func save(request: AnthemMapSaveRequest, to url: URL) throws {
        try save(document: makeDocument(from: request), to: url)
    }

    private func milliseconds(from seconds: TimeInterval) -> Int64 {
        Int64((seconds * 1000.0).rounded())
    }
}
