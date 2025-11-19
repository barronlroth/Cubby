import SwiftUI
import SwiftData

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext
    @State private var homeName = ""
    @State private var isCreatingHome = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()
                
                VStack(spacing: 12) {
                    Image("OnboardingLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(radius: 10)
                    
                    Text("Welcome to Cubby")
                        .font(.custom("AwesomeSerif-ExtraTall", size: 40))
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Let's set up your first home")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                
                VStack(spacing: 20) {
                    TextField("Home Name", text: $homeName)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .submitLabel(.done)
                        .onSubmit {
                            createHome()
                        }
                    
                    Button(action: createHome) {
                        Label("Get Started", systemImage: "arrow.right.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(homeName.isEmpty ? Color.gray : Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(homeName.isEmpty || isCreatingHome)
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(appBackground)
        }
    }
    
    private func createHome() {
        guard !homeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isCreatingHome = true
        
        let newHome = Home(name: homeName.trimmingCharacters(in: .whitespacesAndNewlines))
        modelContext.insert(newHome)
        
        let unsortedLocation = StorageLocation(name: "Unsorted", home: newHome)
        modelContext.insert(unsortedLocation)
        
        do {
            try modelContext.save()
            hasCompletedOnboarding = true
        } catch {
            print("Failed to create home: \(error)")
            isCreatingHome = false
        }
    }
    
    @Environment(\.colorScheme) private var colorScheme
    private var appBackground: Color {
        if colorScheme == .light, UIColor(named: "AppBackground") != nil {
            return Color("AppBackground")
        } else {
            return Color(.systemBackground)
        }
    }
}