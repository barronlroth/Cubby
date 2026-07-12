import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject private var appStore: AppStore

    @State private var homeName = ""
    @State private var isCreatingHome = false
    @FocusState private var isHomeNameFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Image("OnboardingLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .clipShape(.rect(cornerRadius: 24))
                            .shadow(radius: 10)
                            .accessibilityHidden(true)

                        Text("Welcome to Cubby")
                            .font(CubbyDesign.Typography.display)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Let's set up your first home")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 20) {
                        TextField("Home Name", text: $homeName)
                            .textFieldStyle(.roundedBorder)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .submitLabel(.done)
                            .focused($isHomeNameFocused)
                            .onSubmit {
                                createHome()
                            }

                        Button(action: createHome) {
                            Label("Get Started", systemImage: "arrow.right.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(homeName.isEmpty ? Color.gray : Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(.rect(cornerRadius: 12))
                        }
                        .disabled(homeName.isEmpty || isCreatingHome)
                    }
                    .frame(maxWidth: 480)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, CubbyDesign.Spacing.xLarge)
                .padding(.vertical, CubbyDesign.Spacing.xxLarge)
            }
            .defaultScrollAnchor(.center)
            .scrollDismissesKeyboard(.interactively)
            .background(CubbyDesign.Palette.canvas)
        }
    }

    private func createHome() {
        guard !homeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isHomeNameFocused = false
        isCreatingHome = true

        do {
            _ = try appStore.createHome(
                name: homeName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            hasCompletedOnboarding = true
        } catch {
            DebugLogger.error("Failed to create home during onboarding: \(error)")
            isCreatingHome = false
        }
    }

}
