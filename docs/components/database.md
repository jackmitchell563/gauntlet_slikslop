# Database Service

## Overview

The `DatabaseService.swift` file manages all Firestore interactions including user profiles, video metadata, likes, comments, follows, and feeds. It provides atomic CRUD operations and specialized queries for the application's data needs.

## Core Functions

### createDocument(collection:data:)
- **Purpose**: Generic function to add a new document in a Firestore collection
- **Usage**: Called for creating user profiles, video records, or comments
- **Parameters**:
  - collection: Target Firestore collection
  - data: Document data to store
- **Example**:
```swift
class DatabaseService {
    static let shared = DatabaseService()
    private let db = FirebaseConfig.getFirestoreInstance()
    
    func createDocument(collection: String, data: [String: Any]) async throws -> DocumentReference {
        return try await db.collection(collection).addDocument(data: data)
    }
}
```

### updateDocument(collection:docId:data:)
- **Purpose**: Updates a specified document with new data
- **Usage**: Called for likes, comments, profile updates
- **Parameters**:
  - collection: Target collection
  - docId: Document identifier
  - data: New data to apply
- **Example**:
```swift
class DatabaseService {
    func updateDocument(collection: String, docId: String, data: [String: Any]) async throws {
        try await db.collection(collection).document(docId).updateData(data)
    }
}
```

### getDocument<T: Decodable>(collection:docId:)
- **Purpose**: Retrieves a single document from Firestore
- **Usage**: Called for profile or video detail views
- **Parameters**:
  - collection: Target collection
  - docId: Document identifier
- **Returns**: Generic Decodable type
- **Example**:
```swift
class DatabaseService {
    func getDocument<T: Decodable>(collection: String, docId: String) async throws -> T? {
        let docSnap = try await db.collection(collection).document(docId).getDocument()
        guard let data = docSnap.data() else { return nil }
        return try Firestore.Decoder().decode(T.self, from: data)
    }
}
```

### queryCollection<T: Decodable>(collection:queryBuilder:)
- **Purpose**: Fetches documents based on query parameters
- **Usage**: Called for feeds, trending content, follows
- **Parameters**:
  - collection: Target collection
  - queryBuilder: Closure to build query constraints
- **Returns**: Array of generic Decodable type
- **Example**:
```swift
class DatabaseService {
    func queryCollection<T: Decodable>(
        collection: String,
        queryBuilder: (Query) -> Query
    ) async throws -> [T] {
        let query = queryBuilder(db.collection(collection))
        let snapshot = try await query.getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try Firestore.Decoder().decode(T.self, from: document.data())
        }
    }
}
```

### deleteDocument(collection:docId:)
- **Purpose**: Deletes a document from a collection
- **Usage**: Called for content deletion
- **Parameters**:
  - collection: Target collection
  - docId: Document identifier
- **Example**:
```swift
class DatabaseService {
    func deleteDocument(collection: String, docId: String) async throws {
        try await db.collection(collection).document(docId).delete()
    }
}
```

## Data Models

```swift
// User Profile
struct UserProfile: Codable {
    let id: String
    let email: String?
    let displayName: String?
    let photoURL: String?
    let createdAt: Timestamp
    let preferences: [String]?
}

// Video Metadata
struct VideoMetadata: Codable {
    let id: String
    let creatorId: String
    let url: String
    let thumbnail: String
    let title: String
    let description: String
    let tags: [String]
    let likes: Int
    let views: Int
    let createdAt: Timestamp
}

// Comment
struct Comment: Codable {
    let id: String
    let userId: String
    let videoId: String
    let content: String
    let createdAt: Timestamp
}

// Like
struct Like: Codable {
    let id: String
    let userId: String
    let videoId: String
    let createdAt: Timestamp
}

// Follow
struct Follow: Codable {
    let id: String
    let followerId: String
    let followingId: String
    let createdAt: Timestamp
}
```

## Best Practices

1. **Data Access**
   - Use Swift's Codable for type-safe data handling
   - Implement proper error handling with custom Error types
   - Use background queues for heavy operations
   - Implement proper caching with NSCache

2. **Query Optimization**
   - Use compound queries with indexes
   - Implement pagination with DocumentSnapshot
   - Cache frequently accessed data
   - Monitor query performance

3. **Data Consistency**
   - Use transactions for related updates
   - Implement proper error recovery
   - Validate data before writing
   - Use proper data types

4. **Performance**
   - Use batch operations for multiple updates
   - Implement proper offline persistence
   - Monitor network usage
   - Use proper indexing

## Integration Example

```swift
// Creating a new video entry
class VideoManager {
    private let dbService = DatabaseService.shared
    
    func createVideo(metadata: VideoMetadata) async throws -> String {
        let docRef = try await dbService.createDocument(collection: "videos", data: [
            "creatorId": metadata.creatorId,
            "url": metadata.url,
            "thumbnail": metadata.thumbnail,
            "title": metadata.title,
            "description": metadata.description,
            "tags": metadata.tags,
            "likes": 0,
            "views": 0,
            "createdAt": FieldValue.serverTimestamp()
        ])
        return docRef.documentID
    }
    
    func getTrendingVideos() async throws -> [VideoMetadata] {
        return try await dbService.queryCollection(collection: "videos") { query in
            query
                .whereField("createdAt", isGreaterThan: Date().addingTimeInterval(-7*24*60*60))
                .order(by: "likes", descending: true)
                .limit(to: 20)
        }
    }
}
```

## Common Issues and Solutions

1. **Data Consistency**
   - Problem: Race conditions in updates
   - Solution: Use transactions and batched writes

2. **Query Performance**
   - Problem: Slow complex queries
   - Solution: Implement proper indexes and caching

3. **Data Structure Changes**
   - Problem: Model evolution
   - Solution: Implement versioning with Codable

4. **Real-time Updates**
   - Problem: Memory leaks in listeners
   - Solution: Use proper listener management with Combine 