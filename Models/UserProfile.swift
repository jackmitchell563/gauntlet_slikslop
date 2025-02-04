import Foundation
import FirebaseFirestore

/// Represents a user profile in the app
struct UserProfile: Identifiable, Codable {
    /// Unique identifier for the user
    let id: String
    /// User's email address (optional for privacy)
    let email: String?
    /// User's display name
    let displayName: String
    /// URL of the user's profile photo
    let photoURL: String?
    /// User's bio/description
    let bio: String
    /// Timestamp when the profile was created
    let createdAt: Timestamp
    /// User's content preferences/interests
    let preferences: [String]?
    /// Number of followers
    let followerCount: Int
    /// Number of users being followed
    let followingCount: Int
    /// Total likes received across all videos
    let totalLikes: Int
    
    /// Creates a UserProfile instance from a Firestore document
    /// - Parameter document: Firestore document containing user data
    /// - Returns: UserProfile instance
    static func from(_ document: DocumentSnapshot) throws -> UserProfile {
        let data = document.data() ?? [:]
        
        guard let displayName = data["displayName"] as? String else {
            throw DatabaseError.invalidData("Missing required field: displayName")
        }
        
        return UserProfile(
            id: document.documentID,
            email: data["email"] as? String,
            displayName: displayName,
            photoURL: data["photoURL"] as? String,
            bio: data["bio"] as? String ?? "",
            createdAt: data["createdAt"] as? Timestamp ?? Timestamp(date: Date()),
            preferences: data["preferences"] as? [String],
            followerCount: data["followerCount"] as? Int ?? 0,
            followingCount: data["followingCount"] as? Int ?? 0,
            totalLikes: data["totalLikes"] as? Int ?? 0
        )
    }
    
    /// Converts the profile to a dictionary for Firestore storage
    /// - Returns: Dictionary representation of the profile
    func asDictionary() -> [String: Any] {
        return [
            "email": email as Any,
            "displayName": displayName,
            "photoURL": photoURL as Any,
            "bio": bio,
            "createdAt": createdAt,
            "preferences": preferences as Any,
            "followerCount": followerCount,
            "followingCount": followingCount,
            "totalLikes": totalLikes
        ]
    }
}

/// Custom error type for database operations
enum DatabaseError: Error {
    case invalidData(String)
} 