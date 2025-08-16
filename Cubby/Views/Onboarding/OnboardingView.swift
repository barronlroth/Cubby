//
//  OnboardingView.swift
//  Cubby
//
//  Created by Barron Roth on 8/16/25.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext
    
    @State private var homeName = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.accentColor)
                    
                    Text("Welcome to Cubby")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Let's set up your first home")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 24) {
                    TextField("Home name", text: $homeName)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .padding(.horizontal)
                    
                    Button(action: createHome) {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(12)
                    }
                    .disabled(homeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.horizontal)
                }
                
                Spacer()
                Spacer()
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func createHome() {
        let trimmedName = homeName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch ValidationHelpers.validateHomeName(trimmedName) {
        case .success:
            let home = Home(name: trimmedName)
            modelContext.insert(home)
            
            let unsortedLocation = StorageLocation(name: "Unsorted", home: home)
            modelContext.insert(unsortedLocation)
            
            do {
                try modelContext.save()
                hasCompletedOnboarding = true
            } catch {
                errorMessage = "Failed to create home: \(error.localizedDescription)"
                showingError = true
            }
            
        case .failure(let message):
            errorMessage = message
            showingError = true
        }
    }
}