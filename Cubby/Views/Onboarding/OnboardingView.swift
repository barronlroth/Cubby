import SwiftUI

struct OnboardingView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    let onComplete: (FirstRunInventoryResult) -> Void

    @EnvironmentObject private var appStore: AppStore

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            OnboardingWelcomeView {
                coordinator.startSetup()
            }
            .navigationDestination(for: OnboardingCoordinator.Stage.self) { stage in
                destination(for: stage)
            }
        }
        .background(CubbyDesign.Palette.canvas.ignoresSafeArea())
    }

    @ViewBuilder
    private func destination(for stage: OnboardingCoordinator.Stage) -> some View {
        switch stage {
        case .welcome:
            OnboardingWelcomeView {
                coordinator.startSetup()
            }
        case .home:
            OnboardingHomeView(coordinator: coordinator)
        case .item:
            OnboardingFirstItemView(coordinator: coordinator)
        case .location:
            OnboardingLocationView(coordinator: coordinator)
        case .review:
            OnboardingReviewView(
                coordinator: coordinator,
                onStore: storeFirstItem
            )
        }
    }

    private func storeFirstItem() {
        guard let result = coordinator.submit(using: appStore.createFirstRunInventory) else {
            return
        }
        onComplete(result)
    }
}

private struct OnboardingWelcomeView: View {
    let onStart: () -> Void

    var body: some View {
        OnboardingScrollContainer(centersContentWhenShort: true) {
            VStack(spacing: CubbyDesign.Spacing.xxLarge) {
                VStack(spacing: CubbyDesign.Spacing.large) {
                    Image("OnboardingLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 112, height: 112)
                        .clipShape(.rect(cornerRadius: CubbyDesign.Radius.xLarge))
                        .shadow(
                            color: .black.opacity(0.08),
                            radius: 16,
                            y: 8
                        )
                        .accessibilityHidden(true)

                    VStack(spacing: CubbyDesign.Spacing.medium) {
                        Text("Welcome to Cubby")
                            .font(CubbyDesign.Typography.display)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Know where your things are.")
                            .font(CubbyDesign.Typography.bodyLarge)
                            .foregroundStyle(CubbyDesign.Palette.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: CubbyDesign.Spacing.medium) {
                    Label("Save one real item", systemImage: "shippingbox")
                    Label("Give it an exact spot", systemImage: "mappin.and.ellipse")
                    Label("Find it in seconds later", systemImage: "magnifyingglass")
                }
                .font(CubbyDesign.Typography.bodyEmphasized)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CubbyDesign.Spacing.large)
                .cubbySurface(.card)
                .accessibilityElement(children: .combine)

                Button("Set Up My Home", action: onStart)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .font(CubbyDesign.Typography.callToAction)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("onboarding-welcome-primary")

                Text("You’ll create your home, store one item, and review its path before choosing a Cubby Pro plan.")
                    .font(CubbyDesign.Typography.caption)
                    .foregroundStyle(CubbyDesign.Palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct OnboardingHomeView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @FocusState private var fieldIsFocused: Bool

    private let suggestions = ["Home", "Apartment", "Cabin", "Beach House"]

    var body: some View {
        OnboardingScrollContainer(addsNavigationClearance: true) {
            VStack(spacing: CubbyDesign.Spacing.xLarge) {
                OnboardingStepHeader(
                    step: 1,
                    label: "Home",
                    title: "What should we call your home?",
                    detail: "Use the name you naturally think or say."
                )

                VStack(alignment: .leading, spacing: CubbyDesign.Spacing.medium) {
                    Text("Home name")
                        .font(CubbyDesign.Typography.bodySmallEmphasized)

                    TextField("Home", text: $coordinator.draft.homeName)
                        .textFieldStyle(.roundedBorder)
                        .font(CubbyDesign.Typography.body)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.continue)
                        .focused($fieldIsFocused)
                        .accessibilityIdentifier("onboarding-home-name")
                        .onSubmit {
                            coordinator.continueFromHome()
                        }

                    OnboardingSuggestionGrid(
                        suggestions: suggestions,
                        selectedValue: coordinator.draft.homeName
                    ) { suggestion in
                        coordinator.draft.homeName = suggestion
                        fieldIsFocused = false
                    }
                }

                OnboardingValidationMessage(message: coordinator.validationMessage)

                Button("Continue") {
                    coordinator.continueFromHome()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .font(CubbyDesign.Typography.callToAction)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("onboarding-home-continue")
            }
        }
        .navigationTitle("Your Home")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct OnboardingFirstItemView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @FocusState private var fieldIsFocused: Bool

    var body: some View {
        OnboardingScrollContainer(addsNavigationClearance: true) {
            VStack(spacing: CubbyDesign.Spacing.xLarge) {
                OnboardingStepHeader(
                    step: 2,
                    label: "First Item",
                    title: "Add something you often need to find.",
                    detail: "Try a passport, spare batteries, gift wrap, or a cable."
                )

                VStack(alignment: .leading, spacing: CubbyDesign.Spacing.medium) {
                    Text("Item name")
                        .font(CubbyDesign.Typography.bodySmallEmphasized)

                    TextField("Passport", text: $coordinator.draft.itemTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(CubbyDesign.Typography.body)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.continue)
                        .focused($fieldIsFocused)
                        .accessibilityIdentifier("onboarding-item-name")
                        .onSubmit {
                            coordinator.continueFromItem()
                        }

                    Label(
                        "You can add a photo, tags, and notes later.",
                        systemImage: "sparkles"
                    )
                    .font(CubbyDesign.Typography.caption)
                    .foregroundStyle(CubbyDesign.Palette.secondaryText)
                }

                OnboardingValidationMessage(message: coordinator.validationMessage)

                Button("Choose Its Spot") {
                    coordinator.continueFromItem()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .font(CubbyDesign.Typography.callToAction)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("onboarding-item-continue")
            }
        }
        .navigationTitle("First Item")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct OnboardingLocationView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @FocusState private var customFieldIsFocused: Bool

    private let suggestions = ["Closet", "Kitchen Drawer", "Garage Shelf", "Nightstand"]

    var body: some View {
        OnboardingScrollContainer(addsNavigationClearance: true) {
            VStack(spacing: CubbyDesign.Spacing.xLarge) {
                OnboardingStepHeader(
                    step: 3,
                    label: "Location",
                    title: "Where does it live?",
                    detail: "A specific spot makes Cubby useful later."
                )

                VStack(alignment: .leading, spacing: CubbyDesign.Spacing.medium) {
                    Text("Choose a common spot")
                        .font(CubbyDesign.Typography.bodySmallEmphasized)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 132), spacing: CubbyDesign.Spacing.small)],
                        spacing: CubbyDesign.Spacing.small
                    ) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            locationButton(suggestion)
                        }
                    }

                    Text("Or name the exact spot")
                        .font(CubbyDesign.Typography.bodySmallEmphasized)
                        .padding(.top, CubbyDesign.Spacing.small)

                    TextField(
                        "Entryway drawer",
                        text: Binding(
                            get: { coordinator.customLocationName },
                            set: coordinator.setCustomLocationName
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(CubbyDesign.Typography.body)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.continue)
                    .focused($customFieldIsFocused)
                    .accessibilityIdentifier("onboarding-location-custom")
                    .onSubmit {
                        coordinator.continueFromLocation()
                    }
                }

                OnboardingValidationMessage(message: coordinator.validationMessage)

                VStack(spacing: CubbyDesign.Spacing.medium) {
                    Button("Review") {
                        coordinator.continueFromLocation()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .font(CubbyDesign.Typography.callToAction)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("onboarding-location-review")

                    Button("Use Unsorted for Now") {
                        coordinator.useUnsorted()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("onboarding-use-unsorted")
                }
            }
        }
        .navigationTitle("Item Location")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func locationButton(_ suggestion: String) -> some View {
        let isSelected = coordinator.draft.locationChoice == .named(suggestion)

        return Button {
            coordinator.selectSuggestedLocation(suggestion)
            customFieldIsFocused = false
        } label: {
            HStack(spacing: CubbyDesign.Spacing.small) {
                Text(suggestion)
                    .font(CubbyDesign.Typography.bodyEmphasized)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                }
            }
            .frame(maxWidth: .infinity, minHeight: CubbyDesign.Layout.minimumTapTarget)
            .padding(.horizontal, CubbyDesign.Spacing.standard)
            .background(
                isSelected
                    ? CubbyDesign.Palette.accent.opacity(0.14)
                    : CubbyDesign.Palette.surface,
                in: RoundedRectangle(
                    cornerRadius: CubbyDesign.Radius.large,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: CubbyDesign.Radius.large,
                    style: .continuous
                )
                .stroke(
                    isSelected
                        ? CubbyDesign.Palette.accent
                        : CubbyDesign.Palette.separator.opacity(0.35),
                    lineWidth: isSelected
                        ? CubbyDesign.Stroke.emphasized
                        : CubbyDesign.Stroke.hairline
                )
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(
            isSelected
                ? CubbyDesign.Palette.accent
                : CubbyDesign.Palette.primaryText
        )
        .accessibilityIdentifier(
            "onboarding-location-suggestion-\(suggestion.lowercased().replacingOccurrences(of: " ", with: "-"))"
        )
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct OnboardingReviewView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    let onStore: () -> Void

    @AccessibilityFocusState private var errorIsFocused: Bool

    var body: some View {
        OnboardingScrollContainer(addsNavigationClearance: true) {
            VStack(spacing: CubbyDesign.Spacing.xLarge) {
                VStack(spacing: CubbyDesign.Spacing.medium) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 48, weight: .regular))
                        .foregroundStyle(CubbyDesign.Palette.accent)
                        .accessibilityHidden(true)

                    Text("Ready to store it?")
                        .font(CubbyDesign.Typography.title)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("This is the path Cubby will show when you search.")
                        .font(CubbyDesign.Typography.body)
                        .foregroundStyle(CubbyDesign.Palette.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let path = coordinator.reviewPath {
                    VStack(alignment: .leading, spacing: CubbyDesign.Spacing.small) {
                        Text("YOUR FIRST CUBBY")
                            .font(CubbyDesign.Typography.label)
                            .foregroundStyle(CubbyDesign.Palette.secondaryText)

                        Text(path)
                            .font(CubbyDesign.Typography.path)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(CubbyDesign.Spacing.large)
                    .cubbySurface(.raised)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Storage path, \(path)")
                    .accessibilityIdentifier("onboarding-review-path")
                }

                if let errorMessage = coordinator.saveErrorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(CubbyDesign.Typography.bodySmall)
                        .foregroundStyle(CubbyDesign.Palette.destructive)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(CubbyDesign.Spacing.standard)
                        .cubbySurface(.card)
                        .accessibilityFocused($errorIsFocused)
                        .accessibilityIdentifier("onboarding-save-error")
                }

                Button(action: onStore) {
                    if coordinator.isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(coordinator.saveErrorMessage == nil ? "Store My First Item" : "Try Again")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .font(CubbyDesign.Typography.callToAction)
                .disabled(coordinator.isSaving)
                .accessibilityIdentifier("onboarding-store-first-item")
            }
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: coordinator.saveErrorMessage) { _, newValue in
            errorIsFocused = newValue != nil
        }
    }
}

private struct OnboardingStepHeader: View {
    let step: Int
    let label: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: CubbyDesign.Spacing.medium) {
            VStack(alignment: .leading, spacing: CubbyDesign.Spacing.small) {
                Text("Step \(step) of 3")
                    .font(CubbyDesign.Typography.label)
                    .foregroundStyle(CubbyDesign.Palette.secondaryText)
                    .accessibilityLabel("Step \(step) of 3, \(label)")

                ProgressView(value: Double(step), total: 3)
                    .tint(CubbyDesign.Palette.accent)
                    .accessibilityHidden(true)
            }

            Text(title)
                .font(CubbyDesign.Typography.title)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(detail)
                .font(CubbyDesign.Typography.body)
                .foregroundStyle(CubbyDesign.Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct OnboardingSuggestionGrid: View {
    let suggestions: [String]
    let selectedValue: String
    let onSelect: (String) -> Void

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 120), spacing: CubbyDesign.Spacing.small)],
            spacing: CubbyDesign.Spacing.small
        ) {
            ForEach(suggestions, id: \.self) { suggestion in
                let isSelected = selectedValue == suggestion
                Button {
                    onSelect(suggestion)
                } label: {
                    HStack(spacing: CubbyDesign.Spacing.small) {
                        Text(suggestion)
                            .font(CubbyDesign.Typography.bodyEmphasized)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        if isSelected {
                            Image(systemName: "checkmark")
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: CubbyDesign.Layout.minimumTapTarget)
                }
                .buttonStyle(.bordered)
                .tint(isSelected ? CubbyDesign.Palette.accent : CubbyDesign.Palette.secondaryText)
                .accessibilityIdentifier(
                    "onboarding-home-suggestion-\(suggestion.lowercased().replacingOccurrences(of: " ", with: "-"))"
                )
                .accessibilityValue(isSelected ? "Selected" : "Not selected")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

private struct OnboardingValidationMessage: View {
    let message: String?

    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(CubbyDesign.Typography.bodySmall)
                .foregroundStyle(CubbyDesign.Palette.destructive)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("onboarding-validation-error")
        }
    }
}

private struct OnboardingScrollContainer<Content: View>: View {
    let centersContentWhenShort: Bool
    let addsNavigationClearance: Bool
    let content: Content

    init(
        centersContentWhenShort: Bool = false,
        addsNavigationClearance: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.centersContentWhenShort = centersContentWhenShort
        self.addsNavigationClearance = addsNavigationClearance
        self.content = content()
    }

    var body: some View {
        Group {
            if centersContentWhenShort {
                scrollContent
                    .defaultScrollAnchor(.center, for: .alignment)
            } else {
                scrollContent
            }
        }
        .safeAreaPadding(
            .top,
            addsNavigationClearance
                ? CubbyDesign.Spacing.xxxLarge * 3
                : 0
        )
        .scrollDismissesKeyboard(.interactively)
        .background(CubbyDesign.Palette.canvas)
    }

    private var scrollContent: some View {
        ScrollView {
            content
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, CubbyDesign.Spacing.xLarge)
                .padding(.vertical, CubbyDesign.Spacing.xxLarge)
        }
        .defaultScrollAnchor(.top, for: .initialOffset)
    }
}
