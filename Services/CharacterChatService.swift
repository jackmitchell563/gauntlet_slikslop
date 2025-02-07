import Foundation
import FirebaseFirestore

/// Service for managing character chat interactions
class CharacterChatService {
    // MARK: - Properties
    
    /// Shared instance for singleton access
    static let shared = CharacterChatService()
    
    private let openAI = OpenAIService.shared
    private let db = Firestore.firestore()
    
    // Message history cache
    private var messageCache: [String: [ChatMessage]] = [:]
    
    // MARK: - Types
    
    enum ChatError: LocalizedError {
        case invalidCharacter
        case messageGenerationFailed
        case persistenceFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidCharacter:
                return "Invalid character data"
            case .messageGenerationFailed:
                return "Failed to generate character response"
            case .persistenceFailed:
                return "Failed to save chat message"
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Sends a message to a character and gets their response
    /// - Parameters:
    ///   - text: The message text to send
    ///   - character: The character to send the message to
    /// - Returns: The character's response message
    func sendMessage(
        text: String,
        to character: GameCharacter
    ) async throws -> ChatMessage {
        print("📱 CharacterChatService - Sending message to character: \(character.name)")
        
        // Get the next sequence number
        let chatId = getChatId(for: character)
        let nextSequence = (messageCache[chatId]?.last?.sequence ?? 0) + 1
        
        // Create user message
        let userMessage = ChatMessage(
            id: UUID().uuidString,
            text: text,
            sender: .user,
            timestamp: Date(),
            sequence: nextSequence
        )
        
        // Get chat history
        var messages = messageCache[chatId] ?? []
        messages.append(userMessage)
        
        // Generate character response
        let responseText = try await openAI.generateResponse(
            messages: messages,
            character: character
        )
        
        // Create response message with next sequence
        let responseMessage = ChatMessage(
            id: UUID().uuidString,
            text: responseText,
            sender: .character,
            timestamp: Date(),
            sequence: nextSequence + 1
        )
        
        // Update cache
        messages.append(responseMessage)
        messageCache[chatId] = messages
        
        // Save messages
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await self.saveChatMessage(userMessage, characterId: character.id)
            }
            group.addTask {
                try await self.saveChatMessage(responseMessage, characterId: character.id)
            }
            try await group.waitForAll()
        }
        
        print("📱 CharacterChatService - Message exchange completed successfully")
        return responseMessage
    }
    
    /// Loads chat history for a character
    /// - Parameters:
    ///   - character: The character to load history for
    ///   - limit: Maximum number of messages to load
    /// - Returns: Array of chat messages
    func loadChatHistory(
        for character: GameCharacter,
        limit: Int = 50
    ) async throws -> [ChatMessage] {
        print("📱 CharacterChatService - Loading chat history for character: \(character.name)")
        
        let chatId = getChatId(for: character)
        
        // Check cache first
        if let cached = messageCache[chatId] {
            print("📱 CharacterChatService - Returning cached messages")
            return cached
        }
        
        // Load from Firestore
        let userId = AuthService.shared.currentUserId ?? ""
        let snapshot = try await db.collection("chats")
            .document(chatId)
            .collection("messages")
            .order(by: "sequence", descending: false)  // Order by sequence instead of timestamp
            .limit(to: limit)
            .getDocuments()
        
        let messages = snapshot.documents.compactMap { document -> ChatMessage? in
            guard let id = document.data()["id"] as? String,
                  let text = document.data()["text"] as? String,
                  let senderRaw = document.data()["sender"] as? String,
                  let timestamp = document.data()["timestamp"] as? Timestamp,
                  let sequence = document.data()["sequence"] as? Int else {
                return nil
            }
            
            let sender: MessageSender = senderRaw == "user" ? .user : .character
            
            return ChatMessage(
                id: id,
                text: text,
                sender: sender,
                timestamp: timestamp.dateValue(),
                sequence: sequence
            )
        }
        
        // Update cache
        messageCache[chatId] = messages
        
        print("📱 CharacterChatService - Loaded \(messages.count) messages")
        return messages
    }
    
    // MARK: - Private Methods
    
    private func getChatId(for character: GameCharacter) -> String {
        let userId = AuthService.shared.currentUserId ?? ""
        return "\(userId)_\(character.id)"
    }
    
    private func saveChatMessage(_ message: ChatMessage, characterId: String) async throws {
        print("📱 CharacterChatService - Saving message: \(message.id)")
        
        let userId = AuthService.shared.currentUserId ?? ""
        let chatId = "\(userId)_\(characterId)"
        
        try await db.collection("chats")
            .document(chatId)
            .collection("messages")
            .document(message.id)
            .setData([
                "id": message.id,
                "text": message.text,
                "sender": message.sender == .user ? "user" : "character",
                "timestamp": FieldValue.serverTimestamp(),
                "sequence": message.sequence,
                "status": "sent"
            ])
    }
    
    /// Clears the message cache
    func clearCache() {
        print("📱 CharacterChatService - Clearing message cache")
        messageCache.removeAll()
    }
} 