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
    /// Sequence number determining message order (1-based)
    let sequence: Int
    
    init(id: String = UUID().uuidString, text: String, sender: MessageSender, timestamp: Date = .now, sequence: Int) {
        self.id = id
        self.text = text
        self.sender = sender
        self.timestamp = timestamp
        self.sequence = sequence
    }
}

/// Represents who sent a message
enum MessageSender {
    case user
    case character
} 