import SwiftUI
import FirebaseFirestore

// Break out the video cell view into its own component
private struct TestVideoCell: View {
    let video: VideoMetadata
    let onLike: () -> Void
    let onView: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(video.title)
                .font(.headline)
            Text(video.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            HStack {
                Button(action: onLike) {
                    HStack {
                        Image(systemName: "heart.fill")
                        Text("\(video.stats.likes)")
                    }
                }
                .buttonStyle(.bordered)
                
                Button(action: onView) {
                    HStack {
                        Image(systemName: "eye.fill")
                        Text("\(video.stats.comments)")
                    }
                }
                .buttonStyle(.bordered)
            }
            Text("Created: \(video.formattedDate)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// Main view
struct TestFirebaseView: View {
    @State private var testVideo: VideoMetadata?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var videos: [VideoMetadata] = []
    
    private let feedService = FeedService.shared
    
    var body: some View {
        NavigationView {
            List {
                // Test Actions Section
                Section("Test Actions") {
                    actionButtons
                }
                
                // Error Section
                if let error = errorMessage {
                    Section("Error") {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                // Loading Section
                if isLoading {
                    Section {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Videos Section
                Section("Videos") {
                    ForEach(videos) { video in
                        TestVideoCell(
                            video: video,
                            onLike: { incrementLikes(for: video) },
                            onView: { incrementViews(for: video) }
                        )
                    }
                }
            }
            .navigationTitle("Firebase Test")
            .refreshable {
                await refreshData()
            }
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .preferredColorScheme(.light)
        }
    }
    
    // MARK: - View Components
    
    private var actionButtons: some View {
        Group {
            Button(action: createTestVideo) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Test Video")
                }
            }
            
            Button(action: fetchVideos) {
                HStack {
                    Image(systemName: "arrow.clockwise.circle.fill")
                    Text("Fetch Videos")
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func createTestVideo() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let video = try await feedService.createTestVideo()
                await MainActor.run {
                    self.testVideo = video
                    self.videos.insert(video, at: 0)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func fetchVideos() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedVideos = try await feedService.fetchFYPVideos(userId: "test_user")
                await MainActor.run {
                    self.videos = fetchedVideos
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func incrementLikes(for video: VideoMetadata) {
        Task {
            do {
                try await feedService.updateLikeCount(videoId: video.id, increment: true)
                await refreshData()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func incrementViews(for video: VideoMetadata) {
        Task {
            do {
                try await feedService.incrementViewCount(videoId: video.id)
                await refreshData()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func refreshData() async {
        do {
            let fetchedVideos = try await feedService.fetchFYPVideos(userId: "test_user")
            await MainActor.run {
                self.videos = fetchedVideos
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
} 