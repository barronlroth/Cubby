import Foundation

extension String {
    func formatAsTag() -> String {
        let allowed = CharacterSet.lowercaseLetters
            .union(.decimalDigits)
            .union(CharacterSet(charactersIn: "-"))
        
        return self.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .unicodeScalars
            .filter { allowed.contains($0) }
            .map { String($0) }
            .joined()
            .prefix(30)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

struct TagValidator {
    static let maxTags = 10
    static let minLength = 1
    static let maxLength = 30
    
    static func isValid(_ tag: String) -> Bool {
        let formatted = tag.formatAsTag()
        return formatted.count >= minLength && formatted.count <= maxLength
    }
}