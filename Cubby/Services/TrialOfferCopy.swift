import Foundation

struct TrialOfferCopy: Equatable {
    let durationText: String

    init?(durationText: String?) {
        guard let durationText else { return nil }
        let trimmed = durationText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        self.durationText = trimmed
    }

    var title: String {
        "Start your \(adjectivalDurationText) free trial"
    }

    var ctaTitle: String {
        "Start \(capitalizedAdjectivalDurationText) Free Trial"
    }

    var priceText: String {
        "\(durationText) free"
    }

    func blockingSubtitle(productName: String = "Cubby Pro") -> String {
        "\(productName) is required to create and use your home inventory. Start with \(durationText) free."
    }

    func termsText(renewalText: String) -> String {
        "\(durationText) free, then \(renewalText)."
    }

    private var adjectivalDurationText: String {
        let parts = durationText.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count == 2 else {
            return durationText
        }

        let value = String(parts[0])
        let rawUnit = String(parts[1]).lowercased()
        let unit = Self.singularUnitName(for: rawUnit)
        return "\(value)-\(unit)"
    }

    private var capitalizedAdjectivalDurationText: String {
        adjectivalDurationText
            .split(separator: "-", omittingEmptySubsequences: false)
            .map { part -> String in
                guard let first = part.first else { return String(part) }
                return String(first).uppercased() + String(part.dropFirst())
            }
            .joined(separator: "-")
    }

    private static func singularUnitName(for unit: String) -> String {
        switch unit {
        case "days":
            return "day"
        case "weeks":
            return "week"
        case "months":
            return "month"
        case "years":
            return "year"
        default:
            return unit
        }
    }
}
