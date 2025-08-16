//
//  MainNavigationView.swift
//  Cubby
//
//  Created by Barron Roth on 8/16/25.
//

import SwiftUI
import SwiftData

struct MainNavigationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var homes: [Home]
    @State private var currentHome: Home?
    @State private var showingAddItem = false
    @State private var showingSearch = false
    
    var body: some View {
        Group {
            if let home = currentHome ?? homes.first {
                HomeView(currentHome: home)
                    .overlay(alignment: .bottomTrailing) {
                        AddItemFloatingButton(showingAddItem: $showingAddItem)
                            .padding()
                    }
                    .overlay(alignment: .top) {
                        SearchPillButton(showingSearch: $showingSearch)
                            .padding(.top, 8)
                    }
                    .sheet(isPresented: $showingAddItem) {
                        AddItemView(currentHome: home)
                    }
                    .sheet(isPresented: $showingSearch) {
                        SearchView()
                    }
            } else {
                NoHomesView()
            }
        }
        .onAppear {
            if currentHome == nil {
                currentHome = homes.first
            }
        }
    }
}

struct AddItemFloatingButton: View {
    @Binding var showingAddItem: Bool
    
    var body: some View {
        Button(action: { showingAddItem = true }) {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(radius: 4)
        }
    }
}

struct SearchPillButton: View {
    @Binding var showingSearch: Bool
    
    var body: some View {
        Button(action: { showingSearch = true }) {
            HStack {
                Image(systemName: "magnifyingglass")
                Text("Search items...")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(25)
        }
        .padding(.horizontal)
    }
}

struct NoHomesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "house.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Homes Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Something went wrong. Please restart the app.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}