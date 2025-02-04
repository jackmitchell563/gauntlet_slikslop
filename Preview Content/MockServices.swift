import Foundation

/// Mock timestamp for previews
struct PreviewTimestamp {
    let date: Date
    
    func dateValue() -> Date {
        return date
    }
}

/// Mock video metadata for previews
struct PreviewVideoMetadata: Identifiable {
    let id: String
    let creatorId: String
    let url: String
    let thumbnail: String
    let title: String
    let description: String
    let tags: [String]
    let likes: Int
    let views: Int
    let createdAt: PreviewTimestamp
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: createdAt.dateValue())
    }
}

/// Mock feed service for previews
class PreviewFeedService {
    static let shared = PreviewFeedService()
    
    func fetchFYPVideos(userId: String) async throws -> [PreviewVideoMetadata] {
        return [
            PreviewVideoMetadata(
                id: "1",
                creatorId: "creator1",
                url: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
                thumbnail: "thumbnail1",
                title: "Amazing Nature",
                description: "Beautiful wildlife footage",
                tags: ["nature", "wildlife"],
                likes: 1000,
                views: 5000,
                createdAt: PreviewTimestamp(date: Date())
            ),
            PreviewVideoMetadata(
                id: "2",
                creatorId: "creator2",
                url: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
                thumbnail: "thumbnail2",
                title: "Forest Life",
                description: "Deep in the forest",
                tags: ["forest", "peaceful"],
                likes: 800,
                views: 3000,
                createdAt: PreviewTimestamp(date: Date())
            )
        ]
    }
} 