import SwiftUI

/// A sheet listing every home. Owned homes rename in place (swipe, context menu
/// or VoiceOver action) and can be deleted; shared-with-you homes can be left.
struct ManageHomesView: View {
    @Binding var selectedHome: AppHome?

    @State private var pendingHomeAction: PendingHomeAction?
    @State private var homeActionErrorMessage: String?
    @State private var isPerformingHomeAction = false
    @State private var renamingHomeID: UUID?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var systemUndoManager
    @EnvironmentObject private var appStore: AppStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(appStore.homes) { home in
                    ManageHomeRow(
                        home: home,
                        isSelected: selectedHome?.id == home.id,
                        isRenaming: Binding(
                            get: { renamingHomeID == home.id },
                            set: { renamingHomeID = $0 ? home.id : (renamingHomeID == home.id ? nil : renamingHomeID) }
                        ),
                        onRename: { name in try rename(home, to: name) },
                        onRemove: { pendingHomeAction = PendingHomeAction(home: home) }
                    )
                    .disabled(isPerformingHomeAction)
                }
            }
            .navigationTitle("Homes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if appStore.homes.isEmpty {
                    ContentUnavailableView("No Homes", systemImage: "house")
                }
            }
            .alert(
                pendingHomeAction?.confirmationTitle ?? "",
                isPresented: Binding(
                    get: { pendingHomeAction != nil },
                    set: { if !$0 { pendingHomeAction = nil } }
                ),
                presenting: pendingHomeAction
            ) { action in
                Button(action.confirmationButtonTitle, role: .destructive) {
                    CubbyDesign.Haptics.play(.warning)
                    Task { await perform(action) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { action in
                Text(action.confirmationMessage)
            }
            .alert(
                "Home Update Failed",
                isPresented: Binding(
                    get: { homeActionErrorMessage != nil },
                    set: { if !$0 { homeActionErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(homeActionErrorMessage ?? "Unable to update homes.")
            }
        }
        .siriPresentationBlocker(
            isPresented: pendingHomeAction != nil || homeActionErrorMessage != nil || isPerformingHomeAction
        )
    }

    private func rename(_ home: AppHome, to name: String) throws {
        let renamed = try InventoryReorganizer.renameHome(
            id: home.id,
            to: name,
            appStore: appStore,
            systemUndoManager: systemUndoManager
        )
        if selectedHome?.id == home.id {
            selectedHome = renamed
        }
        CubbyDesign.Haptics.play(.success)
    }

    @MainActor
    private func perform(_ action: PendingHomeAction) async {
        guard !isPerformingHomeAction else { return }
        isPerformingHomeAction = true
        defer { isPerformingHomeAction = false }

        do {
            switch action.kind {
            case .delete:
                try await appStore.deleteHome(id: action.home.id)
            case .leave:
                try await appStore.leaveSharedHome(id: action.home.id)
            }
            selectedHome = MainNavigationView.selectionAfterRemovingHome(
                action.home.id,
                currentSelection: selectedHome,
                remainingHomes: appStore.homes
            )
            if appStore.homes.isEmpty {
                dismiss()
            }
        } catch {
            homeActionErrorMessage = error.localizedDescription
        }
    }
}

private struct ManageHomeRow: View {
    let home: AppHome
    let isSelected: Bool
    @Binding var isRenaming: Bool
    let onRename: (String) throws -> Void
    let onRemove: () -> Void

    @State private var draftName = ""
    @State private var draftSelection: TextSelection?
    @State private var errorMessage: String?
    @State private var errorCount = 0
    @State private var keepsFocusAfterFailedSubmit = false
    @FocusState private var isFieldFocused: Bool

    private var removeAction: PendingHomeAction { PendingHomeAction(home: home) }

    private var subtitle: String? {
        if !home.isOwnedByCurrentUser {
            return "Shared with you \u{00B7} Only the owner can rename"
        }
        return HomePicker.shareSubtitle(for: home)
    }

    var body: some View {
        HStack(spacing: CubbyDesign.Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                if isRenaming {
                    renameField
                } else {
                    Text(home.name)
                        .font(CubbyDesign.Typography.body)
                }
                if let errorMessage, isRenaming {
                    Text(errorMessage)
                        .font(CubbyDesign.Typography.caption)
                        .foregroundStyle(CubbyDesign.Palette.destructive)
                } else if let subtitle {
                    Text(subtitle)
                        .font(CubbyDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: CubbyDesign.Spacing.small)
            if isSelected, !isRenaming {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(CubbyDesign.Palette.accent)
                    .accessibilityLabel("Current home")
            }
        }
        .frame(minHeight: CubbyDesign.Layout.minimumTapTarget)
        .contentShape(.rect)
        .contextMenu {
            if home.isOwnedByCurrentUser {
                RenameButton()
            }
            Button(role: .destructive, action: onRemove) {
                Label(removeAction.kind == .leave ? "Leave Home" : "Delete Home", systemImage: removeAction.kind == .leave ? "rectangle.portrait.and.arrow.right" : "trash")
            }
        }
        .renameAction(beginRename)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onRemove) {
                Label(removeAction.kind == .leave ? "Leave" : "Delete", systemImage: removeAction.kind == .leave ? "rectangle.portrait.and.arrow.right" : "trash")
            }
            .accessibilityLabel(removeAction.accessibilityLabel)
            if home.isOwnedByCurrentUser {
                Button(action: beginRename) {
                    Label("Rename", systemImage: "pencil")
                }
                .tint(CubbyDesign.Palette.accent)
            }
        }
        .accessibilityActions {
            if home.isOwnedByCurrentUser {
                Button("Rename", action: beginRename)
            }
            Button(removeAction.accessibilityLabel, action: onRemove)
        }
        .sensoryFeedback(.error, trigger: errorCount)
    }

    private var renameField: some View {
        TextField("Home name", text: $draftName, selection: $draftSelection)
            .font(CubbyDesign.Typography.body)
            .submitLabel(.done)
            .autocorrectionDisabled()
            .focused($isFieldFocused)
            .onSubmit(commit)
            .onKeyPress(.escape) {
                cancel()
                return .handled
            }
            .onChange(of: draftName) { _, _ in
                errorMessage = nil
                keepsFocusAfterFailedSubmit = false
            }
            .onAppear {
                DispatchQueue.main.async { isFieldFocused = true }
            }
            .onChange(of: isFieldFocused) { _, isFocused in
                guard !isFocused else { return }
                if keepsFocusAfterFailedSubmit {
                    keepsFocusAfterFailedSubmit = false
                    isFieldFocused = true
                } else {
                    cancel()
                }
            }
            .accessibilityLabel("Rename \(home.name)")
    }

    private func beginRename() {
        guard home.isOwnedByCurrentUser else { return }
        draftName = home.name
        errorMessage = nil
        draftSelection = TextSelection(range: draftName.startIndex..<draftName.endIndex)
        isRenaming = true
    }

    private func commit() {
        do {
            try onRename(draftName)
            isRenaming = false
        } catch {
            errorMessage = error.localizedDescription
            errorCount += 1
            keepsFocusAfterFailedSubmit = true
            isFieldFocused = true
        }
    }

    private func cancel() {
        guard isRenaming else { return }
        errorMessage = nil
        isRenaming = false
    }
}

private struct PendingHomeAction: Identifiable {
    enum Kind {
        case delete
        case leave
    }

    let id = UUID()
    let home: AppHome
    let kind: Kind

    init(home: AppHome) {
        self.home = home
        if home.isShared && !home.isOwnedByCurrentUser {
            kind = .leave
        } else {
            kind = .delete
        }
    }

    var confirmationTitle: String {
        switch kind {
        case .leave:
            "Leave Shared Home?"
        case .delete where home.isShared:
            "Delete Shared Home for Everyone?"
        case .delete:
            "Delete Home?"
        }
    }

    var confirmationMessage: String {
        switch kind {
        case .leave:
            "You'll lose access to \"\(home.name)\" on this device and through iCloud sharing. The owner's home is not deleted."
        case .delete where home.isShared:
            "This permanently deletes \"\(home.name)\" for you and collaborators. This can't be undone."
        case .delete:
            "This permanently deletes \"\(home.name)\" and every location and item in it. This can't be undone."
        }
    }

    var confirmationButtonTitle: String {
        switch kind {
        case .leave:
            "Leave Home"
        case .delete where home.isShared:
            "Delete Shared Home"
        case .delete:
            "Delete Home"
        }
    }

    var accessibilityLabel: String {
        switch kind {
        case .leave:
            "Leave \(home.name)"
        case .delete:
            "Delete \(home.name)"
        }
    }
}
