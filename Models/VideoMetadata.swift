import Foundation
import FirebaseFirestore

/// Represents metadata for a video in the app
struct VideoMetadata: Identifiable, Codable {
    /// Unique identifier for the video
    let id: String
    /// ID of the user who created the video
    let creatorId: String
    /// URL of the video file
    let url: String
    /// URL of the video thumbnail
    let thumbnail: String
    /// Title of the video
    let title: String
    /// Description of the video
    let description: String
    /// Tags associated with the video
    let tags: [String]
    /// Number of likes the video has received
    let likes: Int
    /// Number of views the video has received
    let views: Int
    /// Timestamp when the video was created
    let createdAt: Timestamp
    
    /// Creates a VideoMetadata instance from a Firestore document
    /// - Parameter document: Firestore document containing video data
    /// - Returns: VideoMetadata instance
    static func from(_ document: DocumentSnapshot) throws -> VideoMetadata {
        let data = document.data() ?? [:]
        
        guard let creatorId = data["creatorId"] as? String,
              let url = data["url"] as? String,
              let thumbnail = data["thumbnail"] as? String,
              let title = data["title"] as? String,
              let description = data["description"] as? String,
              let tags = data["tags"] as? [String],
              let likes = data["likes"] as? Int,
              let views = data["views"] as? Int,
              let createdAt = data["createdAt"] as? Timestamp else {
            throw NSError(domain: "VideoMetadata", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid document data"])
        }
        
        return VideoMetadata(
            id: document.documentID,
            creatorId: creatorId,
            url: url,
            thumbnail: thumbnail,
            title: title,
            description: description,
            tags: tags,
            likes: likes,
            views: views,
            createdAt: createdAt
        )
    }
    
    /// Converts the video metadata to a dictionary for Firestore
    /// - Returns: Dictionary representation of the video metadata
    func toDictionary() -> [String: Any] {
        return [
            "creatorId": creatorId,
            "url": url,
            "thumbnail": thumbnail,
            "title": title,
            "description": description,
            "tags": tags,
            "likes": likes,
            "views": views,
            "createdAt": createdAt
        ]
    }
    
    // Computed property for formatted date
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: createdAt.dateValue())
    }
} 