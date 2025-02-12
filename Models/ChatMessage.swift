import Foundation
import UIKit  // Added for UIImage support

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
    /// Character associated with this message (for image storage)
    let character: GameCharacter?
    
    // MARK: - Image Support
    
    /// Type of message (text, image, or both)
    let type: MessageType
    /// URL to the generated image, if any
    var imageURL: URL?
    /// Status of image generation, if applicable
    var imageGenerationStatus: ImageGenerationStatus?
    /// Temporary in-memory image that will be cleared when the chat is closed
    var ephemeralImage: UIImage?
    
    init(
        id: String = UUID().uuidString,
        text: String,
        sender: MessageSender,
        timestamp: Date = .now,
        sequence: Int,
        character: GameCharacter? = nil,
        type: MessageType = .text,
        imageURL: URL? = nil,
        imageGenerationStatus: ImageGenerationStatus? = nil,
        ephemeralImage: UIImage? = nil
    ) {
        self.id = id
        self.text = text
        self.sender = sender
        self.timestamp = timestamp
        self.sequence = sequence
        self.character = character
        self.type = type
        self.imageURL = imageURL
        self.imageGenerationStatus = imageGenerationStatus
        self.ephemeralImage = ephemeralImage
    }
}

/// Represents who sent a message
enum MessageSender {
    case user
    case character
}

/// Type of message content
enum MessageType: String, Codable {
    case text
    case image
    case textWithImage
}

/// Status of image generation for messages
enum ImageGenerationStatus: Codable {
    case queued
    case generating
    case completed
    case failed(Error)
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case status
        case error
    }
    
    private enum Status: String, Codable {
        case queued, generating, completed, failed
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let status = try container.decode(Status.self, forKey: .status)
        
        switch status {
        case .queued:
            self = .queued
        case .generating:
            self = .generating
        case .completed:
            self = .completed
        case .failed:
            let error = try container.decode(String.self, forKey: .error)
            self = .failed(NSError(domain: "ImageGeneration", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .queued:
            try container.encode(Status.queued, forKey: .status)
        case .generating:
            try container.encode(Status.generating, forKey: .status)
        case .completed:
            try container.encode(Status.completed, forKey: .status)
        case .failed(let error):
            try container.encode(Status.failed, forKey: .status)
            try container.encode(error.localizedDescription, forKey: .error)
        }
    }
} 