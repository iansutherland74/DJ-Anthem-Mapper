import Foundation

enum PrecisionFieldInputSanitiser {
    static func sanitise(oldValue: String, newValue: String, maximumDigits: Int) -> String {
        guard maximumDigits > 0 else { return oldValue }
        // A genuinely empty edit is intentional deletion and is allowed during editing.
        if newValue.isEmpty { return "" }
        let filtered = String(newValue.filter(\.isNumber).prefix(maximumDigits))
        // Non-empty input containing no digits (Space, letters, punctuation) must not erase
        // the previous numeric value.
        return filtered.isEmpty ? oldValue : filtered
    }
}
