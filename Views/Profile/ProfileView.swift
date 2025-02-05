import SwiftUI
import FirebaseFirestore

struct ProfileView: View {
    // MARK: - Properties
    
    @State private var selectedTab: ProfileTab = .videos
    @State private var isFollowing = false
    @State private var profile: UserProfile?
    @State private var videos: [VideoMetadata] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var showSignInPrompt = false
    
    let userId: String
    private let profileService = ProfileService.shared
    private let authService = AuthService.shared
    
    var isCurrentUserProfile: Bool {
        authService.currentUserId == userId
    }
    
    enum ProfileTab {
        case videos
        case liked
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let error = error {
                VStack {
                    Text("Error loading profile")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        Task {
                            await loadProfileData()
                        }
                    }
                }
            } else if let profile = profile {
                ScrollView {
                    VStack(spacing: 20) {
                        // Profile Header
                        SwiftUIProfileHeaderView(
                            username: profile.displayName,
                            bio: profile.bio,
                            stats: ProfileStats(
                                followers: profile.followerCount,
                                following: profile.followingCount,
                                likes: profile.totalLikes
                            ),
                            isFollowing: $isFollowing,
                            isCurrentUser: isCurrentUserProfile,
                            onFollowTapped: handleFollowTapped
                        )
                        
                        // Content Tabs
                        HStack(spacing: 0) {
                            ForEach([ProfileTab.videos, ProfileTab.liked], id: \.self) { tab in
                                TabButton(
                                    title: tab == .videos ? "Videos" : "Liked",
                                    isSelected: selectedTab == tab
                                ) {
                                    withAnimation {
                                        selectedTab = tab
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Video Grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 3), spacing: 1) {
                            ForEach(videos) { video in
                                VideoThumbnailView(video: video)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
                .background(Color.white)
                .refreshable {
                    await loadProfileData()
                }
            }
        }
        .task {
            await loadProfileData()
        }
        .alert("Sign In Required", isPresented: $showSignInPrompt) {
            Button("Sign In", role: .none) {
                // Handle sign in
                Task {
                    do {
                        let result = try await authService.signInWithGoogle()
                        try await authService.createUserProfile(user: result.user)
                        await loadProfileData()
                    } catch {
                        self.error = error
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You need to sign in to follow other users.")
        }
    }
    
    // MARK: - Private Methods
    
    private func loadProfileData() async {
        isLoading = true
        error = nil
        
        do {
            async let profileData = profileService.getUserProfile(userId: userId)
            async let videosData = profileService.fetchUserVideos(userId: userId)
            
            let (profile, videos) = try await (profileData, videosData)
            
            self.profile = profile
            self.videos = videos
            
            // Check if the current user is following this profile
            if let currentUserId = authService.currentUserId {
                self.isFollowing = try await profileService.isFollowing(
                    targetUserId: userId,
                    currentUserId: currentUserId
                )
            }
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    private func handleFollowTapped() {
        guard !isCurrentUserProfile else { return }
        
        guard let currentUserId = authService.currentUserId else {
            showSignInPrompt = true
            return
        }
        
        Task {
            do {
                try await profileService.toggleFollow(
                    targetUserId: userId,
                    currentUserId: currentUserId
                )
                await loadProfileData()
            } catch {
                self.error = error
            }
        }
    }
}

// MARK: - Supporting Views

private struct SwiftUIProfileHeaderView: View {
    let username: String
    let bio: String
    let stats: ProfileStats
    @Binding var isFollowing: Bool
    let isCurrentUser: Bool
    let onFollowTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile Picture
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .foregroundColor(.gray)
            
            // Username & Bio
            VStack(spacing: 4) {
                Text(username)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(bio)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Stats Row
            HStack(spacing: 30) {
                StatItem(value: stats.followers, title: "Followers")
                StatItem(value: stats.following, title: "Following")
                StatItem(value: stats.likes, title: "Likes")
            }
            
            // Follow/Edit Button
            if isCurrentUser {
                Button(action: {
                    // Handle edit profile
                }) {
                    Text("Edit Profile")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(width: 150, height: 44)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(22)
                }
            } else {
                Button(action: onFollowTapped) {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.headline)
                        .foregroundColor(isFollowing ? .black : .white)
                        .frame(width: 150, height: 44)
                        .background(isFollowing ? Color.gray.opacity(0.2) : Color.pink)
                        .cornerRadius(22)
                }
            }
        }
        .padding()
    }
}

private struct StatItem: View {
    let value: Int
    let title: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

private struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                    .foregroundColor(.black)
                
                Rectangle()
                    .fill(isSelected ? Color.black : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct VideoThumbnailView: View {
    let video: VideoMetadata
    
    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: URL(string: video.thumbnail)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
                    .overlay(
                        Image(systemName: "play.fill")
                            .foregroundColor(.white)
                            .font(.title3)
                    )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
    }
}

// MARK: - Models

struct ProfileStats {
    let followers: Int
    let following: Int
    let likes: Int
}

#Preview {
    ProfileView(userId: "preview_user_id")
} 