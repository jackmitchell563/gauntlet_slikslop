import Foundation

/// Represents a message in the chat
struct ChatMessage: Identifiable {
    /// Unique identifier for the message
    let id: String
    /// Message content
    let text: String
    /// Who sent the message
    let sender: MessageSender
    /// When the message was sent
    let timestamp: Date
}

/// Represents who sent a message
enum MessageSender {
    case user
    case character
} 