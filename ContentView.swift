//
//  ContentView.swift
//  SlikSlop
//
//  Created by Jack Mitchell on 2/3/25.
//

import SwiftUI

struct ContentView: View {
    @State private var feedType: TopNavigationBar.FeedType = .forYou
    @State private var selectedTab: BottomNavigationBar.Tab = .home
    @State private var showingTestView = false
    
    var body: some View {
        ZStack {
            // Main Content
            TabView(selection: $selectedTab) {
                // Home Tab (Feed)
                ZStack(alignment: .top) {
                    FeedView(selectedTab: $selectedTab)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Top Navigation
                        TopNavigationBar(
                            selectedTab: $feedType,
                            onSearchTapped: {
                                // TODO: Implement search
                                print("Search tapped")
                            }
                        )
                        
                        Spacer()
                    }
                    .ignoresSafeArea(edges: .top)
                }
                .tag(BottomNavigationBar.Tab.home)
                
                // Create Tab
                Color.black
                    .overlay(
                        Button("Show Test Interface") {
                            showingTestView = true
                        }
                        .foregroundColor(.white)
                    )
                    .tag(BottomNavigationBar.Tab.create)
                
                // Profile Tab
                Color.black
                    .overlay(
                        Text("Profile")
                            .foregroundColor(.white)
                    )
                    .tag(BottomNavigationBar.Tab.profile)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // Bottom Navigation
            VStack {
                Spacer()
                BottomNavigationBar(selectedTab: $selectedTab)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingTestView) {
            TestFirebaseView()
        }
    }
}

#Preview {
    ContentView()
}
