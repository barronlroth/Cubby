import SwiftUI

/// Each visible presentation owner holds its own blocker, so closing one sheet
/// cannot release another owner's active editor or confirmation.
private struct SiriPresentationBlocker: ViewModifier {
    let isPresented: Bool
    @State private var blockerID = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { update(isBlocked: isPresented) }
            .onChange(of: isPresented) { _, isPresented in
                update(isBlocked: isPresented)
            }
            .onDisappear { update(isBlocked: false) }
    }

    @MainActor
    private func update(isBlocked: Bool) {
        SiriInventoryService.shared.setPresentationBlocker(id: blockerID, isBlocked: isBlocked)
    }
}

extension View {
    func siriPresentationBlocker(isPresented: Bool) -> some View {
        modifier(SiriPresentationBlocker(isPresented: isPresented))
    }
}
