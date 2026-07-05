import Testing
@testable import Cubby

@Suite("Trial Offer Copy Tests")
struct TrialOfferCopyTests {
    @Test("Seven-day trial renders trial-forward title and CTA")
    func sevenDayTrialCopy() throws {
        let copy = try #require(TrialOfferCopy(durationText: "7 days"))

        #expect(copy.title == "Start your 7-day free trial")
        #expect(copy.ctaTitle == "Start 7-Day Free Trial")
        #expect(copy.priceText == "7 days free")
        #expect(copy.blockingSubtitle() == "Cubby Pro is required to create and use your home inventory. Start with 7 days free.")
        #expect(copy.termsText(renewalText: "$29.99/year") == "7 days free, then $29.99/year.")
    }

    @Test("Three-day trial uses the same formatter path")
    func threeDayTrialCopy() throws {
        let copy = try #require(TrialOfferCopy(durationText: "3 days"))

        #expect(copy.title == "Start your 3-day free trial")
        #expect(copy.ctaTitle == "Start 3-Day Free Trial")
        #expect(copy.priceText == "3 days free")
        #expect(copy.blockingSubtitle() == "Cubby Pro is required to create and use your home inventory. Start with 3 days free.")
    }

    @Test("Missing trial duration does not create trial copy")
    func missingTrialDuration() {
        #expect(TrialOfferCopy(durationText: nil) == nil)
        #expect(TrialOfferCopy(durationText: "   ") == nil)
    }
}
