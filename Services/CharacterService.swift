import Foundation
import FirebaseFirestore

/// Service class for managing game characters
class CharacterService {
    // MARK: - Properties
    
    /// Shared instance for singleton access
    static let shared = CharacterService()
    
    /// Firestore database instance
    private let db = Firestore.firestore()
    
    /// Collection references
    private let charactersCollection = "characters"
    
    /// In-memory cache for characters
    private var charactersCache: [String: GameCharacter] = [:]
    
    private init() {}
    
    // MARK: - Character Management
    
    /// Fetches characters from the database
    /// - Parameter game: Optional game to filter by
    /// - Returns: Array of GameCharacter objects
    func fetchCharacters(game: GachaGame? = nil) async throws -> [GameCharacter] {
        print("📱 CharacterService - Fetching characters" + (game != nil ? " for \(game!.rawValue)" : ""))
        
        // Start with the base collection reference
        let collectionRef = db.collection(charactersCollection)
        
        // Create and execute the query
        let snapshot: QuerySnapshot
        if let game = game {
            // If game is specified, add the filter
            snapshot = try await collectionRef.whereField("game", isEqualTo: game.rawValue).getDocuments()
        } else {
            // If no game specified, get all documents
            snapshot = try await collectionRef.getDocuments()
        }
        
        let characters = try snapshot.documents.map { document -> GameCharacter in
            let character = try GameCharacter.from(document)
            charactersCache[character.id] = character
            return character
        }
        
        print("📱 CharacterService - Fetched \(characters.count) characters")
        return characters
    }
    
    /// Gets a character by ID
    /// - Parameter id: The ID of the character to fetch
    /// - Returns: GameCharacter object
    func getCharacter(id: String) async throws -> GameCharacter {
        print("📱 CharacterService - Getting character: \(id)")
        
        // Check cache first
        if let cached = charactersCache[id] {
            print("📱 CharacterService - Returning cached character")
            return cached
        }
        
        let document = try await db.collection(charactersCollection).document(id).getDocument()
        let character = try GameCharacter.from(document)
        
        // Update cache
        charactersCache[character.id] = character
        
        print("📱 CharacterService - Character fetched successfully")
        return character
    }
    
    /// Searches for characters by name or tags
    /// - Parameter query: Search query string
    /// - Returns: Array of matching GameCharacter objects
    func searchCharacters(query: String) async throws -> [GameCharacter] {
        print("📱 CharacterService - Searching characters with query: \(query)")
        
        let snapshot = try await db.collection(charactersCollection)
            .whereField("recognitionTags", arrayContains: query.lowercased())
            .getDocuments()
        
        let characters = try snapshot.documents.map { try GameCharacter.from($0) }
        print("📱 CharacterService - Found \(characters.count) matching characters")
        return characters
    }
    
    /// Gets characters related to a specific character
    /// - Parameter characterId: ID of the character to get relations for
    /// - Returns: Array of related GameCharacter objects
    func getRelatedCharacters(characterId: String) async throws -> [GameCharacter] {
        print("📱 CharacterService - Getting related characters for: \(characterId)")
        
        let character = try await getCharacter(id: characterId)
        let relatedIds = character.relationships.map { $0.characterId }
        
        let characters = try await withThrowingTaskGroup(of: GameCharacter.self) { group in
            for id in relatedIds {
                group.addTask {
                    return try await self.getCharacter(id: id)
                }
            }
            
            var results: [GameCharacter] = []
            for try await character in group {
                results.append(character)
            }
            return results
        }
        
        print("📱 CharacterService - Found \(characters.count) related characters")
        return characters
    }
    
    /// Gets recently interacted with characters for a user
    /// - Parameter userId: ID of the user
    /// - Returns: Array of recently interacted GameCharacter objects
    func getRecentCharacters(userId: String, limit: Int = 10) async throws -> [GameCharacter] {
        print("📱 CharacterService - Getting recent characters for user: \(userId)")
        
        let snapshot = try await db.collection("user_character_interactions")
            .whereField("userId", isEqualTo: userId)
            .order(by: "lastInteraction", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        let characterIds = snapshot.documents.compactMap { $0.data()["characterId"] as? String }
        
        let characters = try await withThrowingTaskGroup(of: GameCharacter.self) { group in
            for id in characterIds {
                group.addTask {
                    return try await self.getCharacter(id: id)
                }
            }
            
            var results: [GameCharacter] = []
            for try await character in group {
                results.append(character)
            }
            return results
        }
        
        print("📱 CharacterService - Found \(characters.count) recent characters")
        return characters
    }
    
    /// Records a character interaction for a user
    /// - Parameters:
    ///   - characterId: ID of the character interacted with
    ///   - userId: ID of the user who interacted
    func recordInteraction(characterId: String, userId: String) async throws {
        print("📱 CharacterService - Recording interaction for character: \(characterId) by user: \(userId)")
        
        let interactionId = "\(userId)_\(characterId)"
        try await db.collection("user_character_interactions").document(interactionId).setData([
            "userId": userId,
            "characterId": characterId,
            "lastInteraction": FieldValue.serverTimestamp()
        ], merge: true)
        
        print("📱 CharacterService - Interaction recorded successfully")
    }
    
    /// Clears the character cache
    func clearCache() {
        print("📱 CharacterService - Clearing character cache")
        charactersCache.removeAll()
    }
} 