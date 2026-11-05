import Foundation

// M3_03A_ANTHEM_MAP_READ_ENGINE
enum AnthemMapReadError: Error, Equatable, Sendable {
    case readFailed
    case decodingFailed
    case invalidDocument([AnthemMapDocument.ValidationError])
}

struct AnthemMapReadEngine: Sendable {
    func decode(data: Data) throws -> AnthemMapDocument {
        let document: AnthemMapDocument
        do {
            document = try JSONDecoder().decode(AnthemMapDocument.self, from: data)
        } catch {
            throw AnthemMapReadError.decodingFailed
        }
        let errors = document.validationErrors()
        guard errors.isEmpty else { throw AnthemMapReadError.invalidDocument(errors) }
        return document
    }

    func load(from url: URL) throws -> AnthemMapDocument {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch { throw AnthemMapReadError.readFailed }
        return try decode(data: data)
    }
}
