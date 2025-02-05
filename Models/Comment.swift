import Foundation
import FirebaseFirestore

/// Model representing a comment on a video
struct Comment: Codable {
    /// Unique identifier for the comment
    let id: String
    
    /// ID of the user who made the comment
    let userId: String
    
    /// ID of the video the comment is on
    let videoId: String
    
    /// Text content of the comment
    let content: String
    
    /// When the comment was created
    let createdAt: Timestamp
    
    /// When the comment was last edited (if it was edited)
    let editedAt: Timestamp?
    
    /// Creates a dictionary representation of the comment
    /// - Returns: Dictionary containing comment data
    func asDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "userId": userId,
            "videoId": videoId,
            "content": content,
            "createdAt": createdAt
        ]
        
        if let editedAt = editedAt {
            dict["editedAt"] = editedAt
        }
        
        return dict
    }
}

// MARK: - Firestore Conversion

extension Comment {
    /// Creates a Comment from a Firestore document
    /// - Parameter document: Firestore document
    /// - Returns: Comment instance
    static func from(_ document: DocumentSnapshot) throws -> Comment {
        guard let data = document.data() else {
            throw NSError(domain: "Comment", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Comment data not found"
            ])
        }
        
        return Comment(
            id: document.documentID,
            userId: data["userId"] as? String ?? "",
            videoId: data["videoId"] as? String ?? "",
            content: data["content"] as? String ?? "",
            createdAt: data["createdAt"] as? Timestamp ?? Timestamp(date: Date()),
            editedAt: data["editedAt"] as? Timestamp
        )
    }
} 