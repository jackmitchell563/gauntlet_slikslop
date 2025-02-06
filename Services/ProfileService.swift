import Foundation
import FirebaseFirestore

/// Service class for handling profile-related operations
class ProfileService {
    // MARK: - Properties
    
    static let shared = ProfileService()
    private let db = FirebaseConfig.getFirestoreInstance()
    private let usersCollection = "users"
    private let followsCollection = "follows"
    private let videosCollection = "videos"
    
    private init() {}
    
    // MARK: - Profile Operations
    
    /// Fetches a user's profile data
    /// - Parameter userId: The ID of the user to fetch
    /// - Returns: UserProfile object
    func getUserProfile(userId: String) async throws -> UserProfile {
        let document = try await db.collection(usersCollection).document(userId).getDocument()
        return try UserProfile.from(document)
    }
    
    /// Updates a user's profile information
    /// - Parameters:
    ///   - userId: The ID of the user to update
    ///   - updates: Dictionary of fields to update
    func updateProfile(userId: String, updates: [String: Any]) async throws {
        try await db.collection(usersCollection).document(userId).updateData(updates)
    }
    
    /// Toggles the follow state between two users
    /// - Parameters:
    ///   - targetUserId: The ID of the user to follow/unfollow
    ///   - currentUserId: The ID of the user performing the action
    func toggleFollow(targetUserId: String, currentUserId: String) async throws {
        let followId = "\(currentUserId)_\(targetUserId)"
        let followDoc = db.collection(followsCollection).document(followId)
        
        let batch = db.batch()
        
        // Check if already following
        let followSnapshot = try await followDoc.getDocument()
        
        if followSnapshot.exists {
            // Unfollow
            batch.deleteDocument(followDoc)
            
            // Update counts
            batch.updateData([
                "followerCount": FieldValue.increment(Int64(-1))
            ], forDocument: db.collection(usersCollection).document(targetUserId))
            
            batch.updateData([
                "followingCount": FieldValue.increment(Int64(-1))
            ], forDocument: db.collection(usersCollection).document(currentUserId))
        } else {
            // Follow
            let followData: [String: Any] = [
                "followerId": currentUserId,
                "followingId": targetUserId,
                "createdAt": FieldValue.serverTimestamp()
            ]
            
            batch.setData(followData, forDocument: followDoc)
            
            // Update counts
            batch.updateData([
                "followerCount": FieldValue.increment(Int64(1))
            ], forDocument: db.collection(usersCollection).document(targetUserId))
            
            batch.updateData([
                "followingCount": FieldValue.increment(Int64(1))
            ], forDocument: db.collection(usersCollection).document(currentUserId))
        }
        
        try await batch.commit()
    }
    
    /// Fetches videos created by a user
    /// - Parameters:
    ///   - userId: The ID of the user whose videos to fetch
    ///   - limit: Maximum number of videos to fetch
    /// - Returns: Array of VideoMetadata objects
    func fetchUserVideos(userId: String, limit: Int = 15) async throws -> [VideoMetadata] {
        let snapshot = try await db.collection(videosCollection)
            .whereField("creatorId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return try snapshot.documents.map { try VideoMetadata.from($0) }
    }
    
    /// Checks if a user is following another user
    /// - Parameters:
    ///   - targetUserId: The ID of the user to check
    ///   - currentUserId: The ID of the current user
    /// - Returns: Boolean indicating follow status
    func isFollowing(targetUserId: String, currentUserId: String) async throws -> Bool {
        let followId = "\(currentUserId)_\(targetUserId)"
        let document = try await db.collection(followsCollection).document(followId).getDocument()
        return document.exists
    }
    
    /// Gets the number of followers for a user
    /// - Parameter userId: The ID of the user to get follower count for
    /// - Returns: Number of followers
    func getFollowerCount(userId: String) async throws -> Int {
        let snapshot = try await db.collection(followsCollection)
            .whereField("followingId", isEqualTo: userId)
            .count
            .getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }
    
    /// Gets the number of users a user is following
    /// - Parameter userId: The ID of the user to get following count for
    /// - Returns: Number of users being followed
    func getFollowingCount(userId: String) async throws -> Int {
        let snapshot = try await db.collection(followsCollection)
            .whereField("followerId", isEqualTo: userId)
            .count
            .getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }
    
    /// Gets both follower and following counts for a user in a single call
    /// - Parameter userId: The ID of the user to get counts for
    /// - Returns: Tuple containing (followerCount, followingCount)
    func getFollowCounts(userId: String) async throws -> (followers: Int, following: Int) {
        async let followers = getFollowerCount(userId: userId)
        async let following = getFollowingCount(userId: userId)
        return try await (followers, following)
    }
} 