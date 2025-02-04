import Foundation
import FirebaseFirestore

/// Service class responsible for managing video likes
class LikeService {
    /// Shared instance for singleton access
    static let shared = LikeService()
    
    /// Firestore database instance
    private let db = Firestore.firestore()
    
    /// Collection references
    private let likesCollection = "likes"
    private let videosCollection = "videos"
    
    /// Current user's ID
    private var currentUserId: String?
    
    private init() {}
    
    /// Initializes the service with the current user's ID
    /// - Parameter userId: The ID of the current user
    func initialize(userId: String) async throws {
        print("📱 LikeService - Initializing with user ID: \(userId)")
        self.currentUserId = userId
        
        // Pre-fetch user's liked videos for caching if needed
        _ = try await fetchUserLikedVideos(userId: userId)
    }
    
    /// Toggles like state for a video and updates counts atomically
    /// - Parameters:
    ///   - videoId: The ID of the video to like/unlike
    ///   - userId: The ID of the user performing the action
    /// - Returns: New like state (true if liked, false if unliked)
    func toggleLike(videoId: String, userId: String) async throws -> Bool {
        print("📱 LikeService - Toggling like for video: \(videoId) by user: \(userId)")
        
        // Create a unique ID for the like document
        let likeId = "\(userId)_\(videoId)"
        let likeRef = db.collection(likesCollection).document(likeId)
        let videoRef = db.collection(videosCollection).document(videoId)
        
        let likeDoc = try await likeRef.getDocument()
        let isLiked = likeDoc.exists
        
        // Use a transaction to ensure atomic updates
        try await db.runTransaction({ (transaction, errorPointer) -> Any? in
            if isLiked {
                // Unlike: Delete like document and decrement count
                print("📱 LikeService - Removing like document and decrementing count")
                transaction.deleteDocument(likeRef)
                transaction.updateData(["likes": FieldValue.increment(Int64(-1))], forDocument: videoRef)
            } else {
                // Like: Create like document and increment count
                print("📱 LikeService - Creating like document and incrementing count")
                let likeData: [String: Any] = [
                    "userId": userId,
                    "videoId": videoId,
                    "createdAt": FieldValue.serverTimestamp()
                ]
                transaction.setData(likeData, forDocument: likeRef)
                transaction.updateData(["likes": FieldValue.increment(Int64(1))], forDocument: videoRef)
            }
            return !isLiked
        })
        
        print("📱 LikeService - Like toggled successfully, new state: \(!isLiked)")
        return !isLiked
    }
    
    /// Checks if a user has liked a video
    /// - Parameters:
    ///   - videoId: The ID of the video to check
    ///   - userId: The ID of the user to check for
    /// - Returns: Boolean indicating if the video is liked
    func isVideoLiked(videoId: String, userId: String) async throws -> Bool {
        print("📱 LikeService - Checking like status for video: \(videoId) by user: \(userId)")
        let likeId = "\(userId)_\(videoId)"
        let document = try await db.collection(likesCollection).document(likeId).getDocument()
        return document.exists
    }
    
    /// Fetches all videos liked by a user
    /// - Parameter userId: The ID of the user whose likes to fetch
    /// - Returns: Array of video IDs liked by the user
    func fetchUserLikedVideos(userId: String) async throws -> [String] {
        print("📱 LikeService - Fetching liked videos for user: \(userId)")
        let snapshot = try await db.collection(likesCollection)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        return snapshot.documents.map { $0.get("videoId") as? String ?? "" }
    }
} 