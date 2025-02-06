import Foundation
import FirebaseFirestore

/// Represents a character from a gacha game that users can interact with
struct GameCharacter: Identifiable, Codable {
    /// Unique identifier for the character
    let id: String
    /// Character's name
    let name: String
    /// Game the character is from
    let game: GachaGame
    /// Character's personality profile for LLM interactions
    let personalityProfile: String
    /// URL of the character's banner image
    let bannerImageURL: String
    /// Tags for character recognition
    let recognitionTags: [String]
    
    // LLM-specific properties
    /// Character's personality traits
    let traits: [String]
    /// Character's speaking style description
    let speakingStyle: String
    /// Character's background story
    let backgroundStory: String
    /// Character's relationships with other characters
    let relationships: [CharacterRelationship]
    /// When the character was added to the database
    let createdAt: Timestamp
    
    /// Creates a GameCharacter instance from a Firestore document
    /// - Parameter document: Firestore document containing character data
    /// - Returns: GameCharacter instance
    static func from(_ document: DocumentSnapshot) throws -> GameCharacter {
        guard let data = document.data() else {
            print("❌ GameCharacter - Document data is empty")
            throw DatabaseError.invalidData("Character data not found")
        }
        
        // Safely extract relationships with error handling
        let relationships: [CharacterRelationship] = {
            guard let relationshipsData = data["relationships"] as? [[String: Any]] else {
                print("⚠️ GameCharacter - No valid relationships data found")
                return []
            }
            
            return relationshipsData.compactMap { relationshipData in
                do {
                    return try CharacterRelationship.from(relationshipData)
                } catch {
                    print("⚠️ GameCharacter - Failed to parse relationship: \(error)")
                    return nil
                }
            }
        }()
        
        // Extract and validate other fields
        guard let name = data["name"] as? String,
              !name.isEmpty else {
            print("❌ GameCharacter - Missing or invalid name")
            throw DatabaseError.invalidData("Invalid character name")
        }
        
        let gameString = data["game"] as? String ?? ""
        let game = GachaGame(rawValue: gameString) ?? .genshinImpact
        
        return GameCharacter(
            id: document.documentID,
            name: name,
            game: game,
            personalityProfile: data["personalityProfile"] as? String ?? "",
            bannerImageURL: data["bannerImageURL"] as? String ?? "",
            recognitionTags: data["recognitionTags"] as? [String] ?? [],
            traits: data["traits"] as? [String] ?? [],
            speakingStyle: data["speakingStyle"] as? String ?? "",
            backgroundStory: data["backgroundStory"] as? String ?? "",
            relationships: relationships,
            createdAt: data["createdAt"] as? Timestamp ?? Timestamp(date: Date())
        )
    }
    
    /// Converts the character to a dictionary for Firestore storage
    /// - Returns: Dictionary representation of the character
    func asDictionary() -> [String: Any] {
        return [
            "name": name,
            "game": game.rawValue,
            "personalityProfile": personalityProfile,
            "bannerImageURL": bannerImageURL,
            "recognitionTags": recognitionTags,
            "traits": traits,
            "speakingStyle": speakingStyle,
            "backgroundStory": backgroundStory,
            "relationships": relationships.map { $0.asDictionary() },
            "createdAt": createdAt
        ]
    }
}

/// Represents a relationship between characters
struct CharacterRelationship: Codable {
    /// ID of the related character
    let characterId: String
    /// Type of relationship
    let type: RelationshipType
    /// Description of the relationship
    let description: String
    
    /// Creates a CharacterRelationship from a dictionary
    /// - Parameter data: Dictionary containing relationship data
    /// - Returns: CharacterRelationship instance
    static func from(_ data: Any) throws -> CharacterRelationship {
        // Ensure we have a dictionary
        guard let dict = data as? [String: Any] else {
            print("❌ CharacterRelationship - Invalid data type: \(String(describing: Swift.type(of: data)))")
            throw DatabaseError.invalidData("Relationship data is not a dictionary")
        }
        
        // Safely extract and validate required fields
        guard let characterId = dict["characterId"] as? String else {
            print("❌ CharacterRelationship - Missing or invalid characterId")
            throw DatabaseError.invalidData("Missing or invalid characterId")
        }
        
        guard let typeString = dict["type"] as? String,
              let relationshipType = RelationshipType(rawValue: typeString) else {
            print("❌ CharacterRelationship - Invalid relationship type")
            throw DatabaseError.invalidData("Invalid relationship type")
        }
        
        let description = dict["description"] as? String ?? ""
        
        return CharacterRelationship(
            characterId: characterId,
            type: relationshipType,
            description: description
        )
    }
    
    /// Converts the relationship to a dictionary
    /// - Returns: Dictionary representation of the relationship
    func asDictionary() -> [String: Any] {
        return [
            "characterId": characterId,
            "type": type.rawValue,
            "description": description
        ]
    }
}

/// Types of relationships between characters
enum RelationshipType: String, Codable {
    case friend = "friend"
    case rival = "rival"
    case family = "family"
    case mentor = "mentor"
    case student = "student"
    case enemy = "enemy"
    case ally = "ally"
    case other = "other"
}

/// Supported gacha games
enum GachaGame: String, Codable, CaseIterable {
    case genshinImpact = "Genshin Impact"
    case honkaiStarRail = "Honkai: Star Rail"
    case zenlessZoneZero = "Zenless Zone Zero"
} 