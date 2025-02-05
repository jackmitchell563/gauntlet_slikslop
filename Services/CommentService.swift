import Foundation
import FirebaseFirestore

/// Service class responsible for managing video comments
class CommentService {
    /// Shared instance for singleton access
    static let shared = CommentService()
    
    /// Firestore database instance
    private let db = Firestore.firestore()
    
    /// Collection references
    private let commentsCollection = "comments"
    private let videosCollection = "videos"
    
    private init() {}
    
    /// Creates a new comment on a video
    /// - Parameters:
    ///   - videoId: The ID of the video being commented on
    ///   - userId: The ID of the user making the comment
    ///   - content: The text content of the comment
    /// - Returns: The created Comment object
    func createComment(videoId: String, userId: String, content: String) async throws -> Comment {
        print("📱 CommentService - Creating comment for video: \(videoId) by user: \(userId)")
        
        let commentData: [String: Any] = [
            "userId": userId,
            "videoId": videoId,
            "content": content,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        // Create a document reference first
        let newCommentRef = db.collection(commentsCollection).document()
        
        // Use a transaction to ensure atomic updates
        try await db.runTransaction({ [self] (transaction, errorPointer) -> Void in
            // Update video's comment count
            let videoRef = db.collection(self.videosCollection).document(videoId)
            transaction.updateData(["comments": FieldValue.increment(Int64(1))], forDocument: videoRef)
            
            // Set the comment data
            transaction.setData(commentData, forDocument: newCommentRef)
        })
        
        // Fetch the created comment
        let snapshot = try await newCommentRef.getDocument()
        let comment = try Comment.from(snapshot)
        print("📱 CommentService - Comment created successfully with ID: \(comment.id)")
        
        return comment
    }
    
    /// Deletes a comment from a video
    /// - Parameters:
    ///   - commentId: The ID of the comment to delete
    ///   - videoId: The ID of the video the comment belongs to
    ///   - userId: The ID of the user attempting to delete the comment
    func deleteComment(commentId: String, videoId: String, userId: String) async throws {
        print("📱 CommentService - Attempting to delete comment: \(commentId)")
        
        // Verify the comment exists and belongs to the user
        let commentRef = db.collection(commentsCollection).document(commentId)
        let commentDoc = try await commentRef.getDocument()
        
        guard let commentData = commentDoc.data(),
              commentData["userId"] as? String == userId else {
            throw NSError(domain: "CommentService", code: 403, userInfo: [
                NSLocalizedDescriptionKey: "Unauthorized to delete this comment"
            ])
        }
        
        // Use a transaction to ensure atomic updates
        try await db.runTransaction({ [self] (transaction, errorPointer) -> Void in
            // Delete the comment document
            transaction.deleteDocument(commentRef)
            
            // Update video's comment count
            let videoRef = db.collection(self.videosCollection).document(videoId)
            transaction.updateData(["comments": FieldValue.increment(Int64(-1))], forDocument: videoRef)
        })
        
        print("📱 CommentService - Comment deleted successfully")
    }
    
    /// Updates the content of a comment
    /// - Parameters:
    ///   - commentId: The ID of the comment to update
    ///   - userId: The ID of the user attempting to update the comment
    ///   - newContent: The new content for the comment
    func updateComment(commentId: String, userId: String, newContent: String) async throws {
        print("📱 CommentService - Attempting to update comment: \(commentId)")
        
        let commentRef = db.collection(commentsCollection).document(commentId)
        let commentDoc = try await commentRef.getDocument()
        
        guard let commentData = commentDoc.data(),
              commentData["userId"] as? String == userId else {
            throw NSError(domain: "CommentService", code: 403, userInfo: [
                NSLocalizedDescriptionKey: "Unauthorized to update this comment"
            ])
        }
        
        try await commentRef.updateData([
            "content": newContent,
            "editedAt": FieldValue.serverTimestamp()
        ])
        
        print("📱 CommentService - Comment updated successfully")
    }
    
    /// Fetches comments for a video
    /// - Parameters:
    ///   - videoId: The ID of the video to fetch comments for
    ///   - limit: Maximum number of comments to fetch
    ///   - lastCommentTimestamp: Optional timestamp for pagination
    /// - Returns: Array of Comment objects
    func fetchComments(videoId: String, limit: Int = 20, lastCommentTimestamp: Timestamp? = nil) async throws -> [Comment] {
        print("📱 CommentService - Fetching comments for video: \(videoId)")
        
        var query = db.collection(commentsCollection)
            .whereField("videoId", isEqualTo: videoId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
        
        if let timestamp = lastCommentTimestamp {
            query = query.start(after: [timestamp])
        }
        
        let snapshot = try await query.getDocuments()
        let comments = try snapshot.documents.map { try Comment.from($0) }
        
        print("📱 CommentService - Fetched \(comments.count) comments")
        return comments
    }
    
    /// Fetches a single comment by ID
    /// - Parameter commentId: The ID of the comment to fetch
    /// - Returns: The Comment object
    func getComment(commentId: String) async throws -> Comment {
        print("📱 CommentService - Fetching comment: \(commentId)")
        
        let snapshot = try await db.collection(commentsCollection).document(commentId).getDocument()
        let comment = try Comment.from(snapshot)
        
        print("📱 CommentService - Comment fetched successfully")
        return comment
    }
} 