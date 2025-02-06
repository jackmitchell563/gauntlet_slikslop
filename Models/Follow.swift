import Foundation
import FirebaseFirestore

/// Model representing a follow relationship between users
struct Follow: Codable {
    /// Unique identifier for the follow relationship (followerId_followingId)
    let id: String
    
    /// ID of the user who is following
    let followerId: String
    
    /// ID of the user being followed
    let followingId: String
    
    /// When the follow relationship was created
    let createdAt: Timestamp
    
    /// Creates a dictionary representation of the follow relationship
    /// - Returns: Dictionary containing follow data
    func asDictionary() -> [String: Any] {
        return [
            "followerId": followerId,
            "followingId": followingId,
            "createdAt": createdAt
        ]
    }
}

// MARK: - Firestore Conversion

extension Follow {
    /// Creates a Follow from a Firestore document
    /// - Parameter document: Firestore document
    /// - Returns: Follow instance
    static func from(_ document: DocumentSnapshot) throws -> Follow {
        guard let data = document.data() else {
            throw NSError(domain: "Follow", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Follow data not found"
            ])
        }
        
        return Follow(
            id: document.documentID,
            followerId: data["followerId"] as? String ?? "",
            followingId: data["followingId"] as? String ?? "",
            createdAt: data["createdAt"] as? Timestamp ?? Timestamp(date: Date())
        )
    }
} 