import Foundation
import FirebaseFirestore

/// Represents metadata for a video in the app
struct InteractionStats: Codable {
    var likes: Int
    var comments: Int
    var shares: Int
}

struct VideoMetadata: Identifiable {
    /// Unique identifier for the video
    let id: String
    /// ID of the user who created the video
    let creatorId: String
    /// URL of the video file
    let url: String
    /// URL of the video thumbnail
    let thumbnail: String
    /// URL of the creator's profile photo
    let creatorPhotoURL: String?
    /// Title of the video
    let title: String
    /// Description of the video
    let description: String
    /// Tags associated with the video
    let tags: [String]
    /// Interaction stats for the video
    var stats: InteractionStats
    /// Timestamp when the video was created
    let createdAt: Timestamp
    
    /// Creates a VideoMetadata instance from a Firestore document
    /// - Parameter document: Firestore document containing video data
    /// - Returns: VideoMetadata instance
    static func from(_ document: DocumentSnapshot) throws -> VideoMetadata {
        guard let data = document.data() else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Document data was empty"])
        }
        
        return VideoMetadata(
            id: document.documentID,
            creatorId: data["creatorId"] as? String ?? "",
            url: data["url"] as? String ?? "",
            thumbnail: data["thumbnail"] as? String ?? "",
            creatorPhotoURL: data["creatorPhotoURL"] as? String,
            title: data["title"] as? String ?? "",
            description: data["description"] as? String ?? "",
            tags: data["tags"] as? [String] ?? [],
            stats: InteractionStats(
                likes: data["likes"] as? Int ?? 0,
                comments: data["comments"] as? Int ?? 0,
                shares: data["shares"] as? Int ?? 0
            ),
            createdAt: data["createdAt"] as? Timestamp ?? Timestamp(date: Date())
        )
    }
    
    /// Converts the video metadata to a dictionary for Firestore
    /// - Returns: Dictionary representation of the video metadata
    func asDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "creatorId": creatorId,
            "url": url,
            "thumbnail": thumbnail,
            "title": title,
            "description": description,
            "tags": tags,
            "likes": stats.likes,
            "comments": stats.comments,
            "shares": stats.shares,
            "createdAt": createdAt
        ]
        
        if let photoURL = creatorPhotoURL {
            dict["creatorPhotoURL"] = photoURL
        }
        
        return dict
    }
    
    // Computed property for formatted date
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt.dateValue())
    }
} 