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
    @State private var selectedVideo: VideoMetadata?
    @StateObject private var authState = AuthStateManager()
    
    var body: some View {
        Group {
            if authState.isAuthenticated {
                mainContent
            } else {
                LoginView { success in
                    // After successful login, the auth state will update automatically
                    // through the Firebase auth state listener
                }
            }
        }
    }
    
    private var mainContent: some View {
        ZStack {
            // Main Content
            TabView(selection: $selectedTab) {
                // Home Tab (Feed)
                ZStack(alignment: .top) {
                    NavigationView {
                        FeedView(selectedTab: $selectedTab, selectedVideo: selectedVideo)
                            .ignoresSafeArea()
                            .navigationBarHidden(true)
                    }
                    .navigationViewStyle(.stack)
                    
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
                MainProfileView()
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
        .onAppear {
            setupNotifications()
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("SwitchToFeedTab"),
            object: nil,
            queue: .main
        ) { notification in
            if let video = notification.userInfo?["selectedVideo"] as? VideoMetadata {
                selectedVideo = video
                selectedTab = .home
            }
        }
    }
}

#Preview {
    ContentView()
}
