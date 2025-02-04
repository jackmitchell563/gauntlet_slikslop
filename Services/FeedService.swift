import Foundation
import FirebaseFirestore

/// Service class responsible for fetching and managing feed content
class FeedService {
    /// Shared instance for singleton access
    static let shared = FeedService()
    
    /// Firestore database instance
    private let db = Firestore.firestore()
    
    /// Collection references
    private let videosCollection = "videos"
    private let usersCollection = "users"
    private let followsCollection = "follows"
    
    private init() {}
    
    /// Fetches personalized videos for the FYP feed
    /// - Parameter userId: The ID of the current user
    /// - Returns: Array of video metadata
    func fetchFYPVideos(userId: String, limit: Int = 10) async throws -> [VideoMetadata] {
        // For FYP, we'll fetch recent videos ordered by engagement (likes + views)
        let snapshot = try await db.collection(videosCollection)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return try snapshot.documents.map { try VideoMetadata.from($0) }
    }
    
    /// Fetches videos from followed creators
    /// - Parameter userId: The ID of the current user
    /// - Returns: Array of video metadata
    func fetchFollowingVideos(userId: String, limit: Int = 10) async throws -> [VideoMetadata] {
        // First, get the list of creators the user follows
        let followingSnapshot = try await db.collection(followsCollection)
            .whereField("followerId", isEqualTo: userId)
            .getDocuments()
        
        let followingIds = followingSnapshot.documents.compactMap { doc -> String? in
            doc.data()["followingId"] as? String
        }
        
        guard !followingIds.isEmpty else { return [] }
        
        // Then fetch videos from those creators
        let snapshot = try await db.collection(videosCollection)
            .whereField("creatorId", in: followingIds)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return try snapshot.documents.map { try VideoMetadata.from($0) }
    }
    
    /// Fetches trending videos
    /// - Returns: Array of video metadata
    func fetchTrendingVideos(limit: Int = 10) async throws -> [VideoMetadata] {
        // Get videos from the past week, ordered by likes
        let weekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let weekAgoTimestamp = Timestamp(date: weekAgo)
        
        let snapshot = try await db.collection(videosCollection)
            .whereField("createdAt", isGreaterThan: weekAgoTimestamp)
            .order(by: "createdAt")
            .order(by: "likes", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return try snapshot.documents.map { try VideoMetadata.from($0) }
    }
    
    /// Updates the view count for a video
    /// - Parameter videoId: The ID of the video to update
    func incrementViewCount(videoId: String) async throws {
        try await db.collection(videosCollection).document(videoId)
            .updateData([
                "views": FieldValue.increment(Int64(1))
            ])
    }
    
    /// Updates the like count for a video
    /// - Parameters:
    ///   - videoId: The ID of the video to update
    ///   - increment: Whether to increment (true) or decrement (false) the like count
    func updateLikeCount(videoId: String, increment: Bool) async throws {
        try await db.collection(videosCollection).document(videoId)
            .updateData([
                "likes": FieldValue.increment(Int64(increment ? 1 : -1))
            ])
    }
    
    /// Updates the comment count for a video
    /// - Parameters:
    ///   - videoId: The ID of the video to update
    ///   - increment: Whether to increment (true) or decrement (false) the comment count
    func updateCommentCount(videoId: String, increment: Bool) async throws {
        try await db.collection(videosCollection).document(videoId)
            .updateData([
                "comments": FieldValue.increment(Int64(increment ? 1 : -1))
            ])
    }
    
    /// Updates the share count for a video
    /// - Parameter videoId: The ID of the video that was shared
    func incrementShareCount(videoId: String) async throws {
        try await db.collection(videosCollection).document(videoId)
            .updateData([
                "shares": FieldValue.increment(Int64(1))
            ])
    }
    
    /// Creates a test video document in Firestore
    /// - Returns: The created video's metadata
    func createTestVideo() async throws -> VideoMetadata {
        let testVideo: [String: Any] = [
            "creatorId": "test_creator",
            "url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            "thumbnail": "https://storage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg",
            "title": "Big Buck Bunny",
            "description": "Big Buck Bunny tells the story of a giant rabbit with a heart bigger than himself.",
            "tags": ["animation", "test", "nature"],
            "likes": 0,
            "comments": 0,
            "shares": 0,
            "createdAt": Timestamp(date: Date())
        ]
        
        let docRef = try await db.collection(videosCollection).addDocument(data: testVideo)
        let snapshot = try await docRef.getDocument()
        return try VideoMetadata.from(snapshot)
    }
} 