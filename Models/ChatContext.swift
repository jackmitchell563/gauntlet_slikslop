import Foundation

/// Encapsulates the context needed for image generation in a chat
struct ChatContext {
    /// Recent chat messages for context
    let messages: [ChatMessage]
    /// The character being chatted with
    let character: GameCharacter
    /// Current relationship status (-1000 to 1000)
    let relationshipStatus: Int
    /// Most recent change in relationship value
    let relationshipChange: Int
    
    /// Whether this context qualifies for image generation
    var qualifiesForImageGeneration: Bool { // TODO: Change to >= 100
        relationshipChange >= 0
    }
    
    /// Creates a chat context
    /// - Parameters:
    ///   - messages: Recent chat messages for context
    ///   - character: The character being chatted with
    ///   - relationshipStatus: Current relationship status
    ///   - relationshipChange: Most recent change in relationship value
    init(
        messages: [ChatMessage],
        character: GameCharacter,
        relationshipStatus: Int,
        relationshipChange: Int
    ) {
        // Only keep last 5 messages for context
        self.messages = Array(messages.suffix(5))
        self.character = character
        self.relationshipStatus = relationshipStatus
        self.relationshipChange = relationshipChange
    }
} 