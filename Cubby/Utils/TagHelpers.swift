import Foundation

extension String {
    func formatAsTag() -> String {
        formatAsTag(maxLength: TagValidator.maxLength)
    }

    func formatAsTag(maxLength: Int) -> String {
        formatAsTagInput(maxLength: maxLength)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    func formatAsTagInput() -> String {
        formatAsTagInput(maxLength: TagValidator.maxLength)
    }

    func formatAsTagInput(maxLength: Int) -> String {
        let allowed = CharacterSet.lowercaseLetters
            .union(.decimalDigits)
            .union(CharacterSet(charactersIn: "-"))

        var formatted = self.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .unicodeScalars
            .filter { allowed.contains($0) }
            .map { String($0) }
            .joined()
            .prefix(maxLength)

        while formatted.first == "-" {
            formatted.removeFirst()
        }

        return String(formatted)
    }
}

struct TagValidator {
    static let maxTags = 10
    static let minLength = 1
    static let maxLength = 30
    
    static func isValid(_ tag: String) -> Bool {
        let formatted = tag.formatAsTag(maxLength: .max)
        return formatted.count >= minLength && formatted.count <= maxLength
    }
}
