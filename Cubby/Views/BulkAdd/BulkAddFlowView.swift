import SwiftUI

/// "Add from a list": paste or type a ramble, review the rows Cubby found, then save them.
/// Text from the Shortcuts action skips the compose step and opens straight into review.
struct BulkAddFlowView: View {
    let initialText: String?
    let initialHomeID: UUID?
    var parser: any InventoryTranscriptParsing = FoundationModelInventoryParser()
    var onAppearHandled: () -> Void = {}

    private enum Step: Equatable {
        case compose
        case reading(BulkAddParseProgress?)
        case review
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appStore: AppStore

    @State private var text = ""
    @State private var step: Step = .compose
    @State private var availability: BulkAddAIAvailability = FoundationModelInventoryParser.currentAvailability()
    @State private var review: BulkAddReviewState?
    @State private var errorMessage: String?
    @State private var readTask: Task<Void, Never>?
    @State private var didStart = false
    @FocusState private var editorFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .compose:
                    composeView
                case .reading(let progress):
                    ReadingProgressView(progress: progress)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    readTask?.cancel()
                                    step = .compose
                                }
                            }
                        }
                case .review:
                    if let review = Binding($review) {
                        BulkAddReviewView(review: review, onSaved: { dismiss() })
                    }
                }
            }
            .background(CubbyDesign.Palette.canvas)
        }
        .onAppear(perform: startIfNeeded)
        .onDisappear { readTask?.cancel() }
        .alert(
            "Couldn't Read That",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Compose

    private var composeView: some View {
        Form {
            Section {
                TextEditor(text: $text)
                    .font(CubbyDesign.Typography.body)
                    .frame(minHeight: 220)
                    .focused($editorFocused)
                    .accessibilityLabel("Items to add")
                    .accessibilityIdentifier("bulk-add-text-editor")
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(placeholder)
                                .font(CubbyDesign.Typography.body)
                                .foregroundStyle(CubbyDesign.Palette.secondaryText)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
            } footer: {
                Label(availability.message, systemImage: availability.isAvailable ? "apple.intelligence" : "info.circle")
                    .font(CubbyDesign.Typography.caption)
                    .foregroundStyle(CubbyDesign.Palette.secondaryText)
            }

            if UIPasteboard.general.hasStrings {
                Section {
                    Button {
                        if let pasted = UIPasteboard.general.string { text = pasted }
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Add from a List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Next") { read(text) }
                    .disabled(BulkAddText.clean(text).isEmpty)
                    .accessibilityIdentifier("bulk-add-next-button")
            }
        }
        .onAppear { editorFocused = text.isEmpty }
    }

    private var placeholder: String {
        availability.isAvailable
            ? "Walk around and describe what's where. \"In the garage, on shelf two, there's a red bin with two headlamps and the camping stove…\""
            : "One item per line\nHeadlamps (2)\nCamping Stove"
    }

    // MARK: Reading

    private func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        onAppearHandled()
        if let initialText, !BulkAddText.clean(initialText).isEmpty {
            text = initialText
            read(initialText)
        }
    }

    private var targetHomeID: UUID? {
        let mutableHomes = appStore.homes.filter(\.permission.canMutate)
        if let initialHomeID, mutableHomes.contains(where: { $0.id == initialHomeID }) {
            return initialHomeID
        }
        let lastUsed = UserDefaults.standard.string(forKey: "lastUsedHomeId")
        if let preferred = appStore.preferredHomeForLaunch(lastUsedHomeId: lastUsed),
           preferred.permission.canMutate {
            return preferred.id
        }
        return mutableHomes.first?.id
    }

    private func read(_ input: String) {
        guard let homeID = targetHomeID else {
            errorMessage = "Create a home you can edit before adding items."
            return
        }
        editorFocused = false
        let tree = BulkAddLocationTree(homeID: homeID, locations: appStore.locations)
        let homeName = appStore.home(id: homeID)?.name ?? "this home"
        availability = FoundationModelInventoryParser.currentAvailability()

        switch BulkAddInputInterpreter.route(for: input, availability: availability) {
        case .json:
            do {
                showReview(candidates: try BulkAddJSONInput.parse(input, tree: tree), homeID: homeID)
            } catch BulkAddJSONInput.ParseError.invalidItem(let index) {
                errorMessage = "Item \(index + 1) in the JSON has no name."
            } catch {
                errorMessage = "That looks like JSON but isn't a list of items. Use [{\"name\": \"Headlamps\", \"location\": \"Garage > Shelf 2\"}]."
            }
        case .plainList:
            showReview(candidates: BulkAddPlainListInput.parse(input), homeID: homeID)
        case .model:
            step = .reading(nil)
            readTask?.cancel()
            readTask = Task {
                do {
                    let candidates = try await parser.parse(
                        transcript: input,
                        homeName: homeName,
                        tree: tree,
                        progress: { progress in
                            await MainActor.run { step = .reading(progress) }
                        }
                    )
                    guard !Task.isCancelled else { return }
                    showReview(candidates: candidates, homeID: homeID)
                } catch is CancellationError {
                    return
                } catch {
                    guard !Task.isCancelled else { return }
                    step = .compose
                    errorMessage = (error as? LocalizedError)?.errorDescription
                        ?? BulkAddParserError.modelFailed.errorDescription
                }
            }
        }
    }

    private func showReview(candidates: [BulkAddCandidate], homeID: UUID) {
        review = BulkAddReviewState(
            candidates: candidates,
            homeID: homeID,
            locations: appStore.locations,
            items: appStore.items
        )
        step = .review
    }
}

private struct ReadingProgressView: View {
    let progress: BulkAddParseProgress?

    var body: some View {
        VStack(spacing: CubbyDesign.Spacing.standard) {
            ProgressView()
                .controlSize(.large)

            Text("Reading Your List")
                .font(CubbyDesign.Typography.sectionTitle)

            Text(detail)
                .font(CubbyDesign.Typography.bodySmall)
                .foregroundStyle(CubbyDesign.Palette.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(CubbyDesign.Spacing.xLarge)
        .accessibilityElement(children: .combine)
        .navigationTitle("Add from a List")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var detail: String {
        guard let progress, progress.totalPassages > 1 else {
            return "Apple Intelligence is sorting items by location on this iPhone."
        }
        let current = min(progress.completedPassages + 1, progress.totalPassages)
        return "Reading part \(current) of \(progress.totalPassages) on this iPhone."
    }
}
