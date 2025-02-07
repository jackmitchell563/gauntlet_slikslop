import Foundation
import FirebaseFirestore

/// Represents a character from a gacha game that users can interact with
struct GameCharacter: Identifiable {
    /// Unique identifier for the character
    let id: String
    /// Character's name
    let name: String
    /// Game the character is from
    let game: GachaGame
    /// Character's background story
    let backgroundStory: String
    /// URL of the character's banner image
    let bannerImageURL: String
    /// URL of the character's profile image
    let profileImageURL: String
    /// Character's personality profile for LLM interactions
    let personalityProfile: String
    /// Character's speaking style description
    let speakingStyle: String
    /// When the character was added to the database
    let createdAt: Date
    /// Tags for character recognition
    let recognitionTags: [String]
    /// Character's personality traits
    let traits: [String]
    /// Character's relationships with other characters
    let relationships: [CharacterRelationship]
}

/// Represents a relationship between characters
struct CharacterRelationship {
    /// ID of the related character
    let characterId: String
    /// Type of relationship
    let type: String
    /// Description of the relationship
    let description: String
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

extension GameCharacter {
    /// Creates a GameCharacter instance from a Firestore document
    /// - Parameter document: Firestore document containing character data
    /// - Returns: GameCharacter instance
    static func from(_ document: DocumentSnapshot) throws -> GameCharacter {
        guard let data = document.data() else {
            throw FirestoreError.invalidDocument
        }
        
        let gameString = data["game"] as? String ?? ""
        guard let game = GachaGame(rawValue: gameString) else {
            throw FirestoreError.invalidData("Invalid game type: \(gameString)")
        }
        
        return try GameCharacter(
            id: document.documentID,
            name: data["name"] as? String ?? "",
            game: game,
            backgroundStory: data["backgroundStory"] as? String ?? "",
            bannerImageURL: data["bannerImageURL"] as? String ?? "",
            profileImageURL: data["profileImageURL"] as? String ?? "",
            personalityProfile: data["personalityProfile"] as? String ?? "",
            speakingStyle: data["speakingStyle"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            recognitionTags: data["recognitionTags"] as? [String] ?? [],
            traits: data["traits"] as? [String] ?? [],
            relationships: (data["relationships"] as? [[String: Any]] ?? []).map { relationship in
                CharacterRelationship(
                    characterId: relationship["characterId"] as? String ?? "",
                    type: relationship["type"] as? String ?? "",
                    description: relationship["description"] as? String ?? ""
                )
            }
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
            "profileImageURL": profileImageURL,
            "recognitionTags": recognitionTags,
            "traits": traits,
            "speakingStyle": speakingStyle,
            "backgroundStory": backgroundStory,
            "relationships": relationships.map { $0.asDictionary() },
            "createdAt": createdAt
        ]
    }
}

extension CharacterRelationship {
    /// Converts the relationship to a dictionary
    /// - Returns: Dictionary representation of the relationship
    func asDictionary() -> [String: Any] {
        return [
            "characterId": characterId,
            "type": type,
            "description": description
        ]
    }
} 