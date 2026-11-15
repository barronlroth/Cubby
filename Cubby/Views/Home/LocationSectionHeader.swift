import SwiftUI

/// Actions a section header offers from its context menu. Mutating actions are
/// nil when the home is read-only, which hides them.
struct LocationSectionHeaderActions {
    var onRename: ((String) throws -> Void)?
    var onMove: (() -> Void)?
    var onAddNested: (() -> Void)?
    var onDelete: (() -> Void)?
    var canDelete = false

    static let readOnly = LocationSectionHeaderActions()
}

struct LocationSectionHeader: View {
    enum DropTargetState: Equatable {
        case none
        case valid
        case invalid
    }

    let locationPath: String
    let itemCount: Int
    var isCollapsed = false
    var allowsCollapse = true
    var actions: LocationSectionHeaderActions = .readOnly
    var dropState: DropTargetState = .none
    var onCollapse: () -> Void = {}
    var onExpand: () -> Void = {}
    var onSelect: () -> Void = {}

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var isRenaming = false
    @State private var draftName = ""
    @State private var draftSelection: TextSelection?
    @State private var renameErrorMessage: String?
    @State private var renameErrorCount = 0
    @State private var keepsFocusAfterFailedSubmit = false
    @FocusState private var isRenameFieldFocused: Bool

    private var segments: [String] {
        // Support both " > " and ">" separators
        if locationPath.contains(" > ") || locationPath.contains(">") {
            return locationPath
                .split(separator: ">")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
        } else {
            return [locationPath]
        }
    }

    private var title: String {
        segments.last ?? locationPath
    }

    private var itemCountText: String {
        itemCount == 1 ? "1 item" : "\(itemCount) items"
    }

    var body: some View {
        HStack(alignment: .center, spacing: CubbyDesign.Spacing.medium) {
            titleBlock
                .layoutPriority(1)

            Spacer(minLength: CubbyDesign.Spacing.small)

            if dropState == .valid {
                Label("Drop in \(title)", systemImage: "arrow.down.to.line")
                    .font(CubbyDesign.Typography.captionEmphasized)
                    .foregroundStyle(.white)
                    .padding(.horizontal, CubbyDesign.Spacing.small)
                    .padding(.vertical, CubbyDesign.Spacing.xSmall)
                    .background(CubbyDesign.Palette.accent, in: Capsule())
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .accessibilityHidden(true)
            } else if isCollapsed, !isRenaming {
                Text(itemCountText)
                    .font(CubbyDesign.Typography.captionEmphasized)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                    .accessibilityIdentifier("location-section-count-\(locationPath)")
            }

            if !isRenaming {
                openButton
            }
        }
        .padding(.leading, CubbyDesign.Spacing.standard)
        .padding(.trailing, CubbyDesign.Spacing.xSmall)
        .padding(.top, CubbyDesign.Spacing.standard)
        .padding(.bottom, CubbyDesign.Spacing.small)
        .background {
            if dropState == .valid {
                RoundedRectangle(cornerRadius: CubbyDesign.Radius.medium)
                    .strokeBorder(CubbyDesign.Palette.accent, lineWidth: CubbyDesign.Stroke.emphasized)
                    .background(
                        CubbyDesign.Palette.accent.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: CubbyDesign.Radius.medium)
                    )
                    .padding(.horizontal, CubbyDesign.Spacing.small)
                    .padding(.top, CubbyDesign.Spacing.small)
            }
        }
        .cubbyAnimation(.quick, value: dropState)
        .contentShape(.rect)
        .contextMenu { contextMenuContent }
        .renameAction(beginRename)
        .sensoryFeedback(.error, trigger: renameErrorCount)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    // MARK: Title

    @ViewBuilder
    private var titleBlock: some View {
        if isRenaming {
            renameField
        } else {
            titleContent
                .contentShape(Rectangle())
                .onTapGesture(perform: handleTitleTap)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("\(title), \(itemCountText)")
                .accessibilityValue(allowsCollapse ? (isCollapsed ? "Collapsed" : "Expanded") : "")
                .accessibilityHint(headerAccessibilityHint)
                .accessibilityAction(named: "Open \(title)", onSelect)
                .modifier(MutatingAccessibilityActions(title: title, actions: actions, onRename: beginRename))
        }
    }

    private var renameField: some View {
        VStack(alignment: .leading, spacing: CubbyDesign.Spacing.xSmall) {
            TextField("Location name", text: $draftName, selection: $draftSelection)
                .font(CubbyDesign.Typography.sectionTitle)
                .textFieldStyle(.plain)
                .submitLabel(.done)
                .autocorrectionDisabled()
                .focused($isRenameFieldFocused)
                .onSubmit(commitRename)
                .onKeyPress(.escape) {
                    cancelRename()
                    return .handled
                }
                .onChange(of: draftName) { _, _ in
                    renameErrorMessage = nil
                    keepsFocusAfterFailedSubmit = false
                }
                .padding(.vertical, CubbyDesign.Spacing.xSmall)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(renameErrorMessage == nil ? CubbyDesign.Palette.accent : CubbyDesign.Palette.destructive)
                        .frame(height: CubbyDesign.Stroke.emphasized)
                }
                .accessibilityLabel("Rename \(title)")
                .accessibilityIdentifier("location-section-rename-field-\(locationPath)")

            if let renameErrorMessage {
                Text(renameErrorMessage)
                    .font(CubbyDesign.Typography.caption)
                    .foregroundStyle(CubbyDesign.Palette.destructive)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            // Focus once the field is in the hierarchy (after the context menu closes).
            DispatchQueue.main.async { isRenameFieldFocused = true }
        }
        .onChange(of: isRenameFieldFocused) { _, isFocused in
            guard !isFocused else { return }
            // Return resigns focus right after onSubmit; a failed submit asks to stay open.
            if keepsFocusAfterFailedSubmit {
                keepsFocusAfterFailedSubmit = false
                isRenameFieldFocused = true
            } else {
                cancelRename()
            }
        }
    }

    private var titleContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(CubbyDesign.Typography.sectionTitle)
                .foregroundStyle(Color.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("location-section-title-\(locationPath)")

            if segments.count > 1 {
                let ancestors = Array(segments.dropLast().reversed())
                if dynamicTypeSize.isAccessibilitySize {
                    // One wrapping line keeps every ancestor readable instead of
                    // truncating each segment to a few characters.
                    Text("\(Image(systemName: "arrow.turn.down.right")) \(ancestors.joined(separator: " → "))")
                        .font(CubbyDesign.Typography.path)
                        .foregroundStyle(Color.primary.opacity(0.4))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.turn.down.right")
                            .renderingMode(.template)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.primary.opacity(0.4))
                        ForEach(Array(ancestors.enumerated()), id: \.0) { index, segment in
                            Text(segment)
                                .font(CubbyDesign.Typography.path)
                                .foregroundStyle(Color.primary.opacity(0.4))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .layoutPriority(1)
                            if index < ancestors.count - 1 {
                                Image(systemName: "arrow.right")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.primary.opacity(0.4))
                            }
                        }
                    }
                }
            }
        }
    }

    private var openButton: some View {
        Button(action: onSelect) {
            CubbyDesign.DisclosureIndicator()
                .frame(
                    minWidth: CubbyDesign.Layout.minimumTapTarget,
                    minHeight: CubbyDesign.Layout.minimumTapTarget
                )
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(title)")
        .accessibilityHint("Shows nested locations and every item in this location.")
        .accessibilityIdentifier("location-section-open-\(locationPath)")
    }

    // MARK: Context menu

    @ViewBuilder
    private var contextMenuContent: some View {
        Button(action: onSelect) {
            Label("Open \u{201C}\(title)\u{201D}", systemImage: "arrow.up.forward.app")
        }

        if actions.onRename != nil {
            RenameButton()
        }

        if let onMove = actions.onMove {
            Button(action: onMove) {
                Label("Move to\u{2026}", systemImage: "folder")
            }
        }

        if let onAddNested = actions.onAddNested {
            Button(action: onAddNested) {
                Label("Add Nested Location", systemImage: "folder.badge.plus")
            }
        }

        if let onDelete = actions.onDelete {
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            .disabled(!actions.canDelete)
        }
    }

    // MARK: Behaviour

    private func handleTitleTap() {
        guard allowsCollapse else {
            onSelect()
            return
        }
        if isCollapsed {
            onExpand()
        } else {
            onCollapse()
        }
    }

    private func beginRename() {
        guard actions.onRename != nil else { return }
        draftName = title
        renameErrorMessage = nil
        isRenaming = true
        // Select the whole name so typing replaces it, as Files does.
        draftSelection = TextSelection(range: draftName.startIndex..<draftName.endIndex)
    }

    private func commitRename() {
        guard let onRename = actions.onRename else {
            cancelRename()
            return
        }
        do {
            try onRename(draftName)
            endRename()
        } catch {
            renameErrorMessage = error.localizedDescription
            renameErrorCount += 1
            keepsFocusAfterFailedSubmit = true
            isRenameFieldFocused = true
        }
    }

    private func cancelRename() {
        guard isRenaming else { return }
        endRename()
    }

    private func endRename() {
        isRenaming = false
        isRenameFieldFocused = false
        keepsFocusAfterFailedSubmit = false
        renameErrorMessage = nil
    }

    private var headerAccessibilityHint: String {
        guard allowsCollapse else { return "Opens this storage location." }
        return isCollapsed
            ? "Shows the items in this storage location."
            : "Hides the items in this storage location."
    }
}

/// Mirrors the context menu for VoiceOver users as named actions.
private struct MutatingAccessibilityActions: ViewModifier {
    let title: String
    let actions: LocationSectionHeaderActions
    let onRename: () -> Void

    func body(content: Content) -> some View {
        content
            .accessibilityActions {
                if actions.onRename != nil {
                    Button("Rename", action: onRename)
                }
                if let onMove = actions.onMove {
                    Button("Move to\u{2026}", action: onMove)
                }
                if let onAddNested = actions.onAddNested {
                    Button("Add Nested Location", action: onAddNested)
                }
                if let onDelete = actions.onDelete, actions.canDelete {
                    Button("Delete", action: onDelete)
                }
            }
    }
}
