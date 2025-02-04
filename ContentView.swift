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
    
    var body: some View {
        ZStack {
            // Main Content
            TabView(selection: $selectedTab) {
                // Home Tab (Feed)
                ZStack(alignment: .top) {
                    FeedView()
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
                Color.white
                    .overlay(
                        Text("Create")
                            .foregroundColor(.black)
                    )
                    .tag(BottomNavigationBar.Tab.create)
                
                // Profile Tab
                Color.white
                    .overlay(
                        Text("Profile")
                            .foregroundColor(.black)
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
    }
}

#Preview {
    ContentView()
}
