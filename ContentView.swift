//
//  ContentView.swift
//  SlikSlop
//
//  Created by Jack Mitchell on 2/3/25.
//

import SwiftUI
import FirebaseFirestore

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
                            .padding(.top, (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.top ?? 0)
                            
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
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = windowScene.windows.first,
                               let feedVC = window.rootViewController?.children.first as? UINavigationController,
                               let collectionView = feedVC.viewControllers.first?.view.subviews.first(where: { $0 is UICollectionView }) as? UICollectionView {
                                collectionView.isScrollEnabled = false
                            }
                        }
                    }
                    .onEnded { gesture in
                        // Re-enable scrolling
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first,
                           let feedVC = window.rootViewController?.children.first as? UINavigationController,
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
struct CreateView: View {
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var url: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    private let feedService = FeedService.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 24) {
                    // Input Fields
                    VStack(spacing: 16) {
                        InputField(
                            title: "Video Title",
                            text: $title,
                            placeholder: "Enter video title"
                        )
                        
                        InputField(
                            title: "Description",
                            text: $description,
                            placeholder: "Enter video description",
                            isMultiline: true
                        )
                        
                        InputField(
                            title: "Video URL",
                            text: $url,
                            placeholder: "Enter video URL"
                        )
                    }
                    .padding(.horizontal)
                    
                    // Create Button
                    Button(action: createVideo) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        } else {
                            Text("Create")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(25)
                    .padding(.horizontal)
                    .disabled(isLoading || !isValidInput)
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding(.top, 32)
            }
            .navigationBarHidden(true)
        }
    }
    
    private var isValidInput: Bool {
        !title.isEmpty && 
        !description.isEmpty && 
        !url.isEmpty &&
        URL(string: url) != nil
    }
    
    private func createVideo() {
        guard let url = URL(string: url) else {
            errorMessage = "Invalid URL"
            return
        }
        
        guard let creatorId = AuthService.shared.currentUserId else {
            errorMessage = "You must be logged in to create videos"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Create video with our input data
                let video = try await feedService.createVideo(
                    title: title,
                    description: description,
                    url: url.absoluteString,
                    creatorId: creatorId
                )
                
                await MainActor.run {
                    isLoading = false
                    // Reset form
                    title = ""
                    description = ""
                    self.url = ""
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Input Field
private struct InputField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var isMultiline: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundColor(.white)
                .font(.system(size: 14, weight: .medium))
            
            if isMultiline {
                TextEditor(text: $text)
                    .frame(height: 100)
                    .padding(12)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                    .foregroundColor(.white)
            } else {
                TextField(placeholder, text: $text)
                    .padding(12)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                    .foregroundColor(.white)
            }
        }
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
