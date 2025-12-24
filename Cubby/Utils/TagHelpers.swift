import Foundation

extension String {
    func formatAsTag() -> String {
        formatAsTag(maxLength: TagValidator.maxLength)
    }

    func formatAsTag(maxLength: Int) -> String {
        let allowed = CharacterSet.lowercaseLetters
            .union(.decimalDigits)
            .union(CharacterSet(charactersIn: "-"))
        
        return self.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .unicodeScalars
            .filter { allowed.contains($0) }
            .map { String($0) }
            .joined()
            .prefix(maxLength)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
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
