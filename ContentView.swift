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
            ZStack {
                // Home Tab (Feed)
                if selectedTab == .home {
                    ZStack(alignment: .top) {
                        FeedView(selectedTab: $selectedTab, selectedVideo: selectedVideo)
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
                }
                
                // Create Tab
                if selectedTab == .create {
                    CreateView()
                        .ignoresSafeArea()
                }
                
                // Profile Tab
                if selectedTab == .profile {
                    ProfileContainerView()
                        .ignoresSafeArea()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        // Check if the gesture is more horizontal than vertical
                        let horizontalAmount = abs(gesture.translation.width)
                        let verticalAmount = abs(gesture.translation.height)
                        
                        // If the gesture is primarily horizontal (within 45 degrees of horizontal)
                        if horizontalAmount > verticalAmount {
                            // Prevent scrolling by setting userInteractionEnabled to false
                            if let feedVC = UIApplication.shared.windows.first?.rootViewController?.children.first as? UINavigationController,
                               let collectionView = feedVC.viewControllers.first?.view.subviews.first(where: { $0 is UICollectionView }) as? UICollectionView {
                                collectionView.isScrollEnabled = false
                            }
                        }
                    }
                    .onEnded { gesture in
                        // Re-enable scrolling
                        if let feedVC = UIApplication.shared.windows.first?.rootViewController?.children.first as? UINavigationController,
                           let collectionView = feedVC.viewControllers.first?.view.subviews.first(where: { $0 is UICollectionView }) as? UICollectionView {
                            collectionView.isScrollEnabled = true
                        }
                        
                        let horizontalAmount = abs(gesture.translation.width)
                        let verticalAmount = abs(gesture.translation.height)
                        let threshold: CGFloat = 50 // Minimum drag distance
                        
                        // Only process horizontal swipes (within 45 degrees of horizontal)
                        if horizontalAmount > threshold && horizontalAmount > verticalAmount {
                            withAnimation {
                                if gesture.translation.width > 0 {
                                    // Swipe right
                                    switch selectedTab {
                                    case .home:
                                        break // Already leftmost
                                    case .create:
                                        selectedTab = .home
                                    case .profile:
                                        selectedTab = .create
                                    }
                                } else {
                                    // Swipe left
                                    switch selectedTab {
                                    case .home:
                                        selectedTab = .create
                                    case .create:
                                        selectedTab = .profile
                                    case .profile:
                                        break // Already rightmost
                                    }
                                }
                            }
                        }
                    }
            )
            
            // Bottom Navigation
            VStack {
                Spacer()
                BottomNavigationBar(selectedTab: $selectedTab)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .automatic)
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

// MARK: - Custom Navigation Controllers

/// Custom NavigationController that hides status bar for Create tab
class CreateNavigationController: UINavigationController {
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .fade
    }
}

/// Custom NavigationController that hides status bar for Profile tab
class ProfileNavigationController: UINavigationController {
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .fade
    }
}

// MARK: - Create View
struct CreateView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        let createVC = UIViewController()
        createVC.view.backgroundColor = .black
        let button = UIButton(type: .system)
        button.setTitle("Show Test Interface", for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        createVC.view.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: createVC.view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: createVC.view.centerYAnchor)
        ])
        
        let navController = CreateNavigationController(rootViewController: createVC)
        navController.setNavigationBarHidden(true, animated: false)
        return navController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No updates needed
    }
}

// MARK: - Profile View
struct ProfileContainerView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        let userId = AuthService.shared.currentUserId ?? ""
        let profileVC = ProfileViewController(userId: userId)
        let navController = ProfileNavigationController(rootViewController: profileVC)
        navController.setNavigationBarHidden(true, animated: false)
        return navController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No updates needed
    }
}

#Preview {
    ContentView()
}
