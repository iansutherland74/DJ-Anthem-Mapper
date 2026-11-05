import Foundation

// M3_03B_RESTORATION_BUILDER
enum AnthemMapRestorationError: Error, Equatable, Sendable {
    case invalidDocument([AnthemMapDocument.ValidationError])
}

struct AnthemMapRestoration: Equatable, Sendable {
    let track: AnthemMapDocument.TrackIdentity
    let regions: [AnthemRegionItem]
}

struct AnthemMapRestorationBuilder: Sendable {
    func makeRestoration(from document: AnthemMapDocument) throws -> AnthemMapRestoration {
        let errors = document.validationErrors()
        guard errors.isEmpty else { throw AnthemMapRestorationError.invalidDocument(errors) }
        let restored = document.regions.sorted { $0.slot < $1.slot }.map { persistent in
            AnthemRegionItem(
                id: persistent.id,
                region: AnthemRegion(
                    start: TimeInterval(persistent.startMilliseconds) / 1000.0,
                    end: TimeInterval(persistent.endMilliseconds) / 1000.0
                )
            )
        }
        return AnthemMapRestoration(track: document.track, regions: restored)
    }
}
