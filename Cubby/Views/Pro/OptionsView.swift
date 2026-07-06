import StoreKit
import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
#endif

typealias InventoryImportConfirmAction = (InventoryImportPlan) throws -> InventoryImportCommitResult

struct OptionsView: View {
    let selectedHomeID: UUID?
    private let importCommitter: InventoryImportConfirmAction?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appStore: AppStore
    @EnvironmentObject private var proAccessManager: ProAccessManager
    @State private var showingPaywall = false

    init(
        selectedHomeID: UUID?,
        importCommitter: InventoryImportConfirmAction? = nil
    ) {
        self.selectedHomeID = selectedHomeID
        self.importCommitter = importCommitter
    }

    var body: some View {
        NavigationStack {
            List {
                selectedHomeSection
                inventorySection
                subscriptionStatusSection
                subscriptionActionsSection
                upgradeSection
                legalSection
            }
            .navigationTitle("Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("options-done-button")
                }
            }
            .task {
                await proAccessManager.loadOfferings()
                await proAccessManager.refresh()
            }
            .sheet(isPresented: $showingPaywall) {
                ProPaywallSheetView(context: PaywallContext(reason: .manualUpgrade))
                    .environmentObject(proAccessManager)
            }
        }
    }

    private var selectedHomeSection: some View {
        Section("Selected Home") {
            if let home = appStore.home(id: selectedHomeID) {
                LabeledContent("Home", value: home.name)
                    .accessibilityIdentifier("options-selected-home")
            } else {
                Text("Choose a home to import or export inventory JSON.")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("options-no-selected-home")
            }
        }
    }

    private var inventorySection: some View {
        Section("Inventory") {
            NavigationLink {
                InventoryExportView(selectedHomeID: selectedHomeID)
            } label: {
                Label("Export Home JSON", systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("options-inventory-export-button")

            NavigationLink {
                InventoryImportJSONView(
                    selectedHomeID: selectedHomeID,
                    importCommitter: resolvedImportCommitter
                )
            } label: {
                Label("Import JSON", systemImage: "square.and.arrow.down")
            }
            .accessibilityIdentifier("options-inventory-import-button")
        }
    }

    private var subscriptionStatusSection: some View {
        Section("Subscription") {
            HStack {
                Text("Status")
                Spacer()
                Text(proAccessManager.isPro ? "Active" : "No active subscription")
                    .foregroundStyle(proAccessManager.isPro ? .green : .secondary)
            }
            .accessibilityIdentifier("options-subscription-status")

            if let product = proAccessManager.proProductIdentifier {
                HStack {
                    Text("Plan")
                    Spacer()
                    Text(planName(for: product))
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("options-subscription-plan")
            }
        }
    }

    private var subscriptionActionsSection: some View {
        Section {
            Button {
                Task { await proAccessManager.restorePurchases() }
            } label: {
                if proAccessManager.isRestoringPurchases {
                    Label("Restoring...", systemImage: "arrow.clockwise")
                } else {
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                }
            }
            .disabled(proAccessManager.isRestoringPurchases)
            .accessibilityIdentifier("options-restore-purchases-button")

            Button {
                Task { await showManageSubscriptions() }
            } label: {
                Label("Manage Subscription", systemImage: "creditcard")
            }
            .accessibilityIdentifier("options-manage-subscription-button")

            if let message = proAccessManager.restoreMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("options-restore-message")
            }
        }
    }

    @ViewBuilder
    private var upgradeSection: some View {
        if !proAccessManager.isPro {
            Section("Subscription") {
                Button {
                    showingPaywall = true
                } label: {
                    Label("View Subscription Options", systemImage: "sparkles")
                }
                .accessibilityIdentifier("options-upgrade-button")
            }
        }
    }

    private var legalSection: some View {
        Section("Legal") {
            Button {
                if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                    openURL(url)
                }
            } label: {
                Label("Terms of Use", systemImage: "doc.text")
            }

            Button {
                if let url = URL(string: "https://alfred.barronroth.com/cubby/privacy") {
                    openURL(url)
                }
            } label: {
                Label("Privacy Policy", systemImage: "hand.raised")
            }
        }
    }

    private var resolvedImportCommitter: InventoryImportConfirmAction {
        importCommitter ?? { plan in
            try appStore.commitInventoryImportPlan(plan)
        }
    }

    private func planName(for productId: String) -> String {
        switch productId {
        case ProAccessManager.annualProductId:
            "Annual"
        case ProAccessManager.monthlyProductId:
            "Monthly"
        default:
            productId
        }
    }

    @MainActor
    private func showManageSubscriptions() async {
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            do {
                try await StoreKit.AppStore.showManageSubscriptions(in: windowScene)
                return
            } catch { }
        }
        #endif

        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            openURL(url)
        }
    }
}

private struct InventoryExportView: View {
    let selectedHomeID: UUID?

    @EnvironmentObject private var appStore: AppStore
    @State private var exportText = ""
    @State private var errorMessage: String?
    @State private var didCopy = false
    @State private var exportFileURL: URL?

    private let model = InventoryImportExportOptionsModel()

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    ContentUnavailableView(
                        "Export Unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                    .accessibilityIdentifier("inventory-export-error")
                }
            } else {
                Section("Export JSON") {
                    TextEditor(text: .constant(exportText))
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 280)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("inventory-export-json-text")
                }

                Section {
                    Button {
                        copyExportText()
                    } label: {
                        Label(didCopy ? "Copied Export JSON" : "Copy Export JSON", systemImage: "doc.on.doc")
                    }
                    .disabled(exportText.isEmpty)
                    .accessibilityIdentifier("inventory-export-copy-button")

                    if !exportText.isEmpty {
                        ShareLink(item: exportFileURL ?? fallbackExportFileURL) {
                            Label("Share Export JSON", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityIdentifier("inventory-export-share-button")
                    }
                }
            }
        }
        .navigationTitle("Export JSON")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedHomeID) {
            refreshExport()
        }
    }

    private func refreshExport() {
        do {
            exportText = try model.exportJSONString(
                selectedHomeID: selectedHomeID,
                homes: appStore.homes,
                locations: appStore.locations,
                items: appStore.items
            )
            exportFileURL = try writeExportFile(contents: exportText)
            errorMessage = nil
            didCopy = false
        } catch {
            exportText = ""
            exportFileURL = nil
            errorMessage = error.localizedDescription
        }
    }

    private func copyExportText() {
        #if os(iOS)
        UIPasteboard.general.string = exportText
        #endif
        didCopy = true
    }

    private var fallbackExportFileURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Cubby-Export.json")
    }

    private func writeExportFile(contents: String) throws -> URL {
        let homeName = appStore.home(id: selectedHomeID)?.name ?? "Home"
        let fileName = "Cubby-\(Self.safeFileName(homeName))-Export.json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        guard let data = contents.data(using: .utf8) else {
            throw InventoryImportExportOptionsError.exportFailed("Unable to encode export JSON.")
        }
        try data.write(to: url, options: [.atomic])
        return url
    }

    private static func safeFileName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let compacted = String(sanitized)
            .split(separator: "-")
            .joined(separator: "-")
        return compacted.isEmpty ? "Home" : compacted
    }
}

private struct InventoryImportJSONView: View {
    let selectedHomeID: UUID?
    let importCommitter: InventoryImportConfirmAction

    @EnvironmentObject private var appStore: AppStore
    @State private var jsonText = ""
    @State private var reviewRoute: InventoryImportReviewRoute?
    @State private var showingFileImporter = false
    @State private var fileImportErrorMessage: String?

    private let model = InventoryImportExportOptionsModel()

    var body: some View {
        Form {
            Section("Import JSON") {
                TextEditor(text: $jsonText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 260)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("inventory-import-json-editor")

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        PasteButton(payloadType: String.self) { strings in
                            if let pasted = strings.first {
                                jsonText = pasted
                                fileImportErrorMessage = nil
                            }
                        }
                        .accessibilityIdentifier("inventory-import-paste-button")

                        Button {
                            showingFileImporter = true
                        } label: {
                            Label("Open JSON File", systemImage: "doc.badge.plus")
                        }
                        .accessibilityIdentifier("inventory-import-open-file-button")

                        Spacer()
                    }

                    Button {
                        reviewImport()
                    } label: {
                        Label("Review Import", systemImage: "checklist")
                    }
                    .disabled(jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("inventory-import-review-button")
                }

                if let fileImportErrorMessage {
                    Text(fileImportErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("inventory-import-file-error")
                }
            }

            Section {
                Text("Import targets the selected home and previews every change before anything is applied.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Import JSON")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $reviewRoute) { route in
            InventoryImportReviewView(
                summary: route.summary,
                importCommitter: importCommitter
            )
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.json, .plainText]
        ) { result in
            loadImportFile(result)
        }
    }

    private func reviewImport() {
        let summary = model.reviewImport(
            jsonString: jsonText,
            selectedHomeID: selectedHomeID,
            homes: appStore.homes,
            locations: appStore.locations,
            items: appStore.items
        )
        reviewRoute = InventoryImportReviewRoute(summary: summary)
    }

    private func loadImportFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            jsonText = try String(contentsOf: url, encoding: .utf8)
            fileImportErrorMessage = nil
        } catch {
            fileImportErrorMessage = error.localizedDescription
        }
    }
}

private struct InventoryImportReviewRoute: Identifiable, Hashable {
    let id = UUID()
    let summary: InventoryImportReviewSummary

    static func == (lhs: InventoryImportReviewRoute, rhs: InventoryImportReviewRoute) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct InventoryImportReviewView: View {
    let summary: InventoryImportReviewSummary
    let importCommitter: InventoryImportConfirmAction

    @Environment(\.dismiss) private var dismiss
    @State private var isCommitting = false
    @State private var commitAlert: InventoryImportCommitAlert?

    var body: some View {
        List {
            InventoryImportReviewIssueSection(issues: summary.blockingIssues)

            InventoryImportReviewBucketSection(
                title: "New locations",
                accessibilityID: "inventory-import-review-new-locations",
                emptyText: "No new locations",
                rows: summary.newLocations
            )

            InventoryImportReviewBucketSection(
                title: "New items",
                accessibilityID: "inventory-import-review-new-items",
                emptyText: "No new items",
                rows: summary.newItems
            )

            InventoryImportReviewBucketSection(
                title: "Updated items",
                accessibilityID: "inventory-import-review-updated-items",
                emptyText: "No updated items",
                rows: summary.updatedItems
            )

            InventoryImportReviewBucketSection(
                title: "Unchanged",
                accessibilityID: "inventory-import-review-unchanged",
                emptyText: "No unchanged items",
                rows: summary.unchangedItems
            )

            Section {
                Button {
                    confirmImport()
                } label: {
                    if isCommitting {
                        Label("Importing", systemImage: "hourglass")
                    } else {
                        Label("Confirm Import", systemImage: "checkmark.circle")
                    }
                }
                .disabled(!summary.canConfirm || isCommitting)
                .accessibilityIdentifier("inventory-import-confirm-button")
            }
        }
        .navigationTitle(reviewTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            commitAlert?.title ?? "",
            isPresented: Binding(
                get: { commitAlert != nil },
                set: { isPresented in
                    if !isPresented {
                        commitAlert = nil
                    }
                }
            ),
            presenting: commitAlert
        ) { alert in
            Button(alert.buttonTitle) {
                commitAlert = nil
                if alert.dismissesReview {
                    dismiss()
                }
            }
        } message: { alert in
            Text(alert.message)
        }
    }

    private var reviewTitle: String {
        summary.homeName.isEmpty ? "Review Import" : "Review \(summary.homeName)"
    }

    private func confirmImport() {
        guard let plan = summary.plan, plan.canCommit else { return }
        isCommitting = true
        do {
            let result = try importCommitter(plan)
            commitAlert = .success(result)
        } catch {
            commitAlert = .failure(error.localizedDescription)
        }
        isCommitting = false
    }
}

private struct InventoryImportCommitAlert: Identifiable, Equatable {
    let id: String
    let title: String
    let message: String
    let buttonTitle: String
    let dismissesReview: Bool

    static func success(_ result: InventoryImportCommitResult) -> InventoryImportCommitAlert {
        InventoryImportCommitAlert(
            id: "success",
            title: "Import Complete",
            message: successMessage(for: result),
            buttonTitle: "Done",
            dismissesReview: true
        )
    }

    static func failure(_ message: String) -> InventoryImportCommitAlert {
        InventoryImportCommitAlert(
            id: "failure-\(message)",
            title: "Import Failed",
            message: message,
            buttonTitle: "OK",
            dismissesReview: false
        )
    }

    private static func successMessage(for result: InventoryImportCommitResult) -> String {
        var parts: [String] = []
        appendCount(result.createdLocationIDs.count, singular: "location", action: "Created", to: &parts)
        appendCount(result.createdItemIDs.count, singular: "item", action: "Created", to: &parts)
        appendCount(result.updatedItemIDs.count, singular: "item", action: "Updated", to: &parts)

        guard !parts.isEmpty else {
            return "No changes were needed."
        }
        return parts.joined(separator: "\n")
    }

    private static func appendCount(
        _ count: Int,
        singular: String,
        action: String,
        to parts: inout [String]
    ) {
        guard count > 0 else { return }
        let noun = count == 1 ? singular : "\(singular)s"
        parts.append("\(action) \(count) \(noun).")
    }
}

private struct InventoryImportReviewIssueSection: View {
    let issues: [InventoryImportReviewIssue]

    var body: some View {
        Section {
            if issues.isEmpty {
                Label("No blocking issues", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("inventory-import-review-no-issues")
            } else {
                ForEach(issues) { issue in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(issue.title)
                            .font(.body.weight(.medium))
                        if let detail = issue.detail {
                            Text(detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("inventory-import-review-issue-\(issue.id)")
                }
            }
        } header: {
            Text("Needs fixing")
                .accessibilityIdentifier("inventory-import-review-needs-fixing")
        }
    }
}

private struct InventoryImportReviewBucketSection: View {
    let title: String
    let accessibilityID: String
    let emptyText: String
    let rows: [InventoryImportReviewRow]

    var body: some View {
        Section {
            if rows.isEmpty {
                Text(emptyText)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.title)
                            .font(.body.weight(.medium))
                        if let detail = row.detail {
                            Text(detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("inventory-import-review-row-\(row.id)")
                }
            }
        } header: {
            Text("\(title) (\(rows.count))")
                .accessibilityIdentifier(accessibilityID)
        }
    }
}
