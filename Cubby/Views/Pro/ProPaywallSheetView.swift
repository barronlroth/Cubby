import RevenueCat
import SwiftUI

struct ProPaywallSheetView: View {
    let context: PaywallContext

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var proAccessManager: ProAccessManager

    @State private var didTimeout = false
    @State private var selectedPackageIdentifier: String?
    @State private var purchasingPackageIdentifier: String?
    @State private var purchaseErrorMessage: String?

    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let privacyURL = URL(string: "https://alfred.barronroth.com/cubby/privacy")!

    var body: some View {
        NavigationStack {
            ZStack {
                PaywallPalette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        heroSection
                        perksSection
                        plansSection

                        if let message = proAccessManager.restoreMessage {
                            Text(message)
                                .font(.custom("CircularStd-Book", size: 13, relativeTo: .footnote))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }

                        complianceSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 140)
                }
            }
            .safeAreaInset(edge: .bottom) {
                purchaseBar
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .task {
                await loadOfferingsIfNeeded()
            }
            .task {
                try? await Task.sleep(for: .seconds(10))
                if proAccessManager.isLoadingOfferings || purchasePackages.isEmpty {
                    didTimeout = true
                }
            }
            .onChange(of: availablePackageIdentifiers) { _, _ in
                ensureSelectedPackage()
            }
            .onChange(of: proAccessManager.isPro) { _, isPro in
                if isPro {
                    dismiss()
                }
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: 10) {
            Image("ProPaywallHero")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 146)
                .padding(.horizontal, -14)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("Cubby Pro")
                    .font(.custom("AwesomeSerif-ExtraTall", size: 50, relativeTo: .largeTitle))
                    .foregroundStyle(PaywallPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(subtitle)
                    .font(.custom("CircularStd-Book", size: 17, relativeTo: .body))
                    .foregroundStyle(PaywallPalette.softInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var perksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(perks) { perk in
                HStack(alignment: .top, spacing: 12) {
                    Text(perk.emoji)
                        .font(.system(size: 24))
                        .frame(width: 34, height: 34)
                        .background(PaywallPalette.iconBackground, in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(perk.title)
                            .font(.custom("CircularStd-Medium", size: 16, relativeTo: .body))
                            .foregroundStyle(PaywallPalette.ink)

                        Text(perk.detail)
                            .font(.custom("CircularStd-Book", size: 13, relativeTo: .footnote))
                            .foregroundStyle(PaywallPalette.softInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(PaywallPalette.hairline, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.05), radius: 18, x: 0, y: 10)
    }

    @ViewBuilder
    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Choose your plan")
                    .font(.custom("CircularStd-Medium", size: 15, relativeTo: .body))
                    .foregroundStyle(PaywallPalette.ink)

                Spacer()

                Text("Free: 1 home, 10 items")
                    .font(.custom("CircularStd-Medium", size: 12, relativeTo: .caption))
                    .foregroundStyle(PaywallPalette.copper)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(PaywallPalette.copper.opacity(0.12), in: Capsule())
            }

            if let error = proAccessManager.offeringsErrorMessage {
                errorRetryView(message: error)
            } else if didTimeout && purchasePackages.isEmpty {
                errorRetryView(message: "Unable to load purchase options. Please check your connection and try again.")
            } else if purchasePackages.isEmpty {
                loadingPlanView
            } else {
                ForEach(purchasePackages, id: \.storeProduct.productIdentifier) { package in
                    Button {
                        selectedPackageIdentifier = packageIdentifier(package)
                    } label: {
                        ProPlanRow(
                            title: planTitle(for: package),
                            subtitle: planSubtitle(for: package),
                            price: priceText(for: package),
                            badge: isAnnualPackage(package) ? "Best value" : nil,
                            isSelected: selectedPackage?.storeProduct.productIdentifier == package.storeProduct.productIdentifier
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedPackage?.storeProduct.productIdentifier == package.storeProduct.productIdentifier ? .isSelected : [])
                }
            }
        }
    }

    private var loadingPlanView: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(proAccessManager.isRevenueCatConfigured ? "Loading purchase options..." : "Purchase options are not available in this build.")
                .font(.custom("CircularStd-Book", size: 14, relativeTo: .body))
                .foregroundStyle(PaywallPalette.softInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PaywallPalette.hairline, lineWidth: 1)
        }
    }

    private func errorRetryView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message)
                .font(.custom("CircularStd-Book", size: 14, relativeTo: .body))
                .foregroundStyle(PaywallPalette.softInk)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button("Try Again") {
                    didTimeout = false
                    Task { await proAccessManager.loadOfferings() }
                }
                .buttonStyle(.borderedProminent)
                .tint(PaywallPalette.ink)

                Button("Restore") {
                    Task { await proAccessManager.restorePurchases() }
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PaywallPalette.hairline, lineWidth: 1)
        }
    }

    private var purchaseBar: some View {
        VStack(spacing: 9) {
            if let purchaseErrorMessage {
                Text(purchaseErrorMessage)
                    .font(.custom("CircularStd-Book", size: 12, relativeTo: .caption))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task { await purchaseSelectedPackage() }
            } label: {
                HStack(spacing: 10) {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(isPurchasing ? "Unlocking..." : "Unlock Pro")
                        .font(.custom("CircularStd-Medium", size: 17, relativeTo: .headline))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
            }
            .buttonStyle(.plain)
            .background(ctaBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .foregroundStyle(.white)
            .disabled(selectedPackage == nil || isPurchasing)
            .opacity(selectedPackage == nil ? 0.55 : 1)

            HStack(spacing: 16) {
                Button("Restore Purchase") {
                    Task { await proAccessManager.restorePurchases() }
                }
                .disabled(proAccessManager.isRestoringPurchases)

                Link("Terms", destination: termsURL)
                Link("Privacy", destination: privacyURL)
            }
            .font(.custom("CircularStd-Book", size: 12, relativeTo: .caption))
            .foregroundStyle(PaywallPalette.softInk)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background {
            PaywallPalette.background
                .opacity(0.96)
                .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: -8)
                .ignoresSafeArea()
        }
    }

    private var complianceSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Subscription Information")
                .font(.custom("CircularStd-Medium", size: 13, relativeTo: .footnote))
                .foregroundStyle(PaywallPalette.ink)

            if subscriptionDetails.isEmpty {
                Text("Subscription title, length, and price are shown in the purchase options above.")
                    .font(.custom("CircularStd-Book", size: 11, relativeTo: .caption2))
                    .foregroundStyle(PaywallPalette.softInk)
            } else {
                ForEach(subscriptionDetails, id: \.self) { detail in
                    Text(detail)
                        .font(.custom("CircularStd-Book", size: 11, relativeTo: .caption2))
                        .foregroundStyle(PaywallPalette.softInk)
                }
            }

            Text("Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period. Manage or cancel in your App Store account settings.")
                .font(.custom("CircularStd-Book", size: 11, relativeTo: .caption2))
                .foregroundStyle(PaywallPalette.softInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
    }

    private var purchasePackages: [Package] {
        proAccessManager.availablePackages
            .filter { $0.storeProduct.productCategory == .subscription }
            .sorted { lhs, rhs in
                packageRank(lhs) < packageRank(rhs)
            }
    }

    private var selectedPackage: Package? {
        if let selectedPackageIdentifier,
           let selected = purchasePackages.first(where: { packageIdentifier($0) == selectedPackageIdentifier }) {
            return selected
        }

        return purchasePackages.first
    }

    private var availablePackageIdentifiers: [String] {
        purchasePackages.map(packageIdentifier)
    }

    private var isPurchasing: Bool {
        purchasingPackageIdentifier != nil
    }

    private var ctaBackground: Color {
        selectedPackage == nil || isPurchasing ? PaywallPalette.softInk : PaywallPalette.ink
    }

    private var subscriptionDetails: [String] {
        purchasePackages.map { package in
            "\(planTitle(for: package)): \(priceText(for: package)) \(subscriptionCadence(for: package))"
        }
    }

    private var perks: [ProPerk] {
        [
            ProPerk(emoji: "🏠", title: "Unlimited homes", detail: "Track every place you store things."),
            ProPerk(emoji: "📦", title: "Unlimited items", detail: "Catalog the whole inventory, not just the first 10."),
            ProPerk(emoji: "🤝", title: "Shared home inventories", detail: "Keep a household organized together."),
            ProPerk(emoji: "📸", title: "Photos, notes, exact paths", detail: "Remember the item and the shelf it lives on.")
        ]
    }

    private var subtitle: String {
        switch context.reason {
        case .homeLimitReached:
            "Add every home without bumping into the free limit."
        case .itemLimitReached:
            "Make room for the rest of your inventory."
        case .overLimit:
            "Keep creating without deleting what you already organized."
        case .manualUpgrade:
            "Room for every home, every item, every detail."
        }
    }

    @MainActor
    private func loadOfferingsIfNeeded() async {
        guard proAccessManager.offerings?.current == nil || purchasePackages.isEmpty else {
            ensureSelectedPackage()
            return
        }

        didTimeout = false
        await proAccessManager.loadOfferings()
        ensureSelectedPackage()
    }

    private func ensureSelectedPackage() {
        guard !purchasePackages.isEmpty else {
            selectedPackageIdentifier = nil
            return
        }

        if let selectedPackageIdentifier,
           purchasePackages.contains(where: { packageIdentifier($0) == selectedPackageIdentifier }) {
            return
        }

        selectedPackageIdentifier = purchasePackages.first.map(packageIdentifier)
    }

    @MainActor
    private func purchaseSelectedPackage() async {
        guard let selectedPackage else { return }

        purchaseErrorMessage = nil
        purchasingPackageIdentifier = packageIdentifier(selectedPackage)
        defer { purchasingPackageIdentifier = nil }

        do {
            try await proAccessManager.purchase(package: selectedPackage)
        } catch {
            purchaseErrorMessage = "Purchase failed. Please try again."
            DebugLogger.warning("RevenueCat purchase failed: \(error.localizedDescription)")
        }
    }

    private func packageIdentifier(_ package: Package) -> String {
        package.storeProduct.productIdentifier
    }

    private func packageRank(_ package: Package) -> Int {
        let identifier = package.storeProduct.productIdentifier.lowercased()
        if identifier.contains("annual") || identifier.contains("year") {
            return 0
        }
        if identifier.contains("monthly") || identifier.contains("month") {
            return 1
        }
        return 2
    }

    private func isAnnualPackage(_ package: Package) -> Bool {
        packageRank(package) == 0
    }

    private func planTitle(for package: Package) -> String {
        let identifier = package.storeProduct.productIdentifier.lowercased()
        if identifier.contains("annual") || identifier.contains("year") {
            return "Annual"
        }
        if identifier.contains("monthly") || identifier.contains("month") {
            return "Monthly"
        }

        let title = package.storeProduct.localizedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Cubby Pro" : title
    }

    private func planSubtitle(for package: Package) -> String {
        if isAnnualPackage(package) {
            return "Best for keeping every home organized."
        }
        return "Flexible access to every Pro feature."
    }

    private func priceText(for package: Package) -> String {
        package.storeProduct.localizedPriceString
    }

    private func subscriptionCadence(for package: Package) -> String {
        "every \(subscriptionLengthDescription(package.storeProduct.subscriptionPeriod))"
    }

    private func subscriptionLengthDescription(_ period: SubscriptionPeriod?) -> String {
        guard let period else { return "period" }
        let unit: String
        switch period.unit {
        case .day:
            unit = period.value == 1 ? "day" : "days"
        case .week:
            unit = period.value == 1 ? "week" : "weeks"
        case .month:
            unit = period.value == 1 ? "month" : "months"
        case .year:
            unit = period.value == 1 ? "year" : "years"
        @unknown default:
            unit = "period"
        }
        return "\(period.value) \(unit)"
    }
}

private struct ProPerk: Identifiable {
    let id = UUID()
    let emoji: String
    let title: String
    let detail: String
}

private struct ProPlanRow: View {
    let title: String
    let subtitle: String
    let price: String
    let badge: String?
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.custom("CircularStd-Medium", size: 17, relativeTo: .body))
                        .foregroundStyle(PaywallPalette.ink)

                    if let badge {
                        Text(badge)
                            .font(.custom("CircularStd-Medium", size: 11, relativeTo: .caption2))
                            .foregroundStyle(PaywallPalette.copper)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(PaywallPalette.copper.opacity(0.13), in: Capsule())
                    }
                }

                Text(subtitle)
                    .font(.custom("CircularStd-Book", size: 13, relativeTo: .footnote))
                    .foregroundStyle(PaywallPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 6) {
                Text(price)
                    .font(.custom("CircularStd-Medium", size: 17, relativeTo: .body))
                    .foregroundStyle(PaywallPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(isSelected ? PaywallPalette.copper : PaywallPalette.softInk.opacity(0.42))
            }
        }
        .padding(14)
        .background(.white.opacity(isSelected ? 0.92 : 0.68), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? PaywallPalette.copper.opacity(0.72) : PaywallPalette.hairline, lineWidth: isSelected ? 1.5 : 1)
        }
        .shadow(color: .black.opacity(isSelected ? 0.08 : 0.035), radius: isSelected ? 16 : 8, x: 0, y: isSelected ? 9 : 5)
    }
}

private enum PaywallPalette {
    static let background = Color(red: 0.980, green: 0.976, blue: 0.965)
    static let ink = Color(red: 0.090, green: 0.080, blue: 0.068)
    static let softInk = Color(red: 0.405, green: 0.381, blue: 0.346)
    static let copper = Color(red: 0.740, green: 0.330, blue: 0.105)
    static let iconBackground = Color(red: 0.925, green: 0.859, blue: 0.741)
    static let hairline = Color(red: 0.780, green: 0.730, blue: 0.650).opacity(0.38)
}
