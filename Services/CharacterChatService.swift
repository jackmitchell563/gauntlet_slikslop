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
    // Relationship status cache
    private var relationshipCache: [String: Int] = [:]
    
    // MARK: - Types
    
    enum ChatError: LocalizedError {
        case invalidCharacter
        case messageGenerationFailed
        case persistenceFailed
        case relationshipError
        case imageGenerationFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidCharacter:
                return "Invalid character data"
            case .messageGenerationFailed:
                return "Failed to generate character response"
            case .persistenceFailed:
                return "Failed to save chat message"
            case .relationshipError:
                return "Failed to manage relationship status"
            case .imageGenerationFailed:
                return "Failed to generate image"
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Gets the chat ID for a given character
    /// - Parameter character: The character to get the chat ID for
    /// - Returns: A unique chat ID combining the current user's ID and character ID
    func getChatId(for character: GameCharacter) -> String {
        let userId = AuthService.shared.currentUserId ?? ""
        return "\(userId)_\(character.id)"
    }
    
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
        
        let userId = AuthService.shared.currentUserId ?? ""
        let chatId = getChatId(for: character)
        
        // Get current relationship status
        let relationshipStatus = try await getRelationshipStatus(
            userId: userId,
            characterId: character.id
        )
        
        // Get the next sequence number
        let nextSequence = (messageCache[chatId]?.last?.sequence ?? 0) + 1
        
        // Create user message
        let userMessage = ChatMessage(
            id: UUID().uuidString,
            text: text,
            sender: .user,
            timestamp: Date(),
            sequence: nextSequence,
            character: character
        )
        
        // Get chat history
        var messages = messageCache[chatId] ?? []
        messages.append(userMessage)
        
        // Generate character response with relationship status
        let (responseText, relationshipChange) = try await openAI.generateResponse(
            messages: messages,
            character: character,
            relationshipStatus: relationshipStatus
        )
        
        // Update relationship status
        try await updateRelationshipStatus(
            userId: userId,
            characterId: character.id,
            change: relationshipChange
        )
        
        // Create chat context
        let context = try await createChatContext(
            messages: messages,
            character: character,
            relationshipChange: relationshipChange
        )
        
        // Determine if we should generate an image
        let shouldGenerateImage = context.qualifiesForImageGeneration
        
        // Create response message
        var responseMessage = ChatMessage(
            id: UUID().uuidString,
            text: responseText,
            sender: .character,
            timestamp: Date(),
            sequence: nextSequence + 1,
            character: character,
            type: shouldGenerateImage ? .textWithImage : .text,
            imageGenerationStatus: shouldGenerateImage ? .queued : nil,
            ephemeralImage: nil
        )
        
        // Update cache and save messages
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
        
        // Generate image if needed
        if shouldGenerateImage {
            Task {
                do {
                    // Update status to generating
                    responseMessage.imageGenerationStatus = .generating
                    try await saveChatMessage(responseMessage, characterId: character.id)
                    
                    // Generate image
                    let image = try await StableDiffusionService.shared.generateImage(
                        positivePrompt: responseText,
                        negativePrompt: "",
                        character: character
                    )
                    
                    // Store image in memory and on disk
                    responseMessage.ephemeralImage = image
                    try StableDiffusionService.shared.saveImageLocally(image, messageId: responseMessage.id, character: character)
                    responseMessage.imageGenerationStatus = .completed
                    try await saveChatMessage(responseMessage, characterId: character.id)
                    
                    // Update cache
                    if var cachedMessages = messageCache[chatId],
                       let index = cachedMessages.firstIndex(where: { $0.id == responseMessage.id }) {
                        cachedMessages[index] = responseMessage
                        messageCache[chatId] = cachedMessages
                    }
                    
                } catch {
                    print("❌ CharacterChatService - Error generating image: \(error)")
                    
                    // Update status to failed
                    responseMessage.imageGenerationStatus = .failed(error)
                    try? await saveChatMessage(responseMessage, characterId: character.id)
                    
                    // Update cache
                    if var cachedMessages = messageCache[chatId],
                       let index = cachedMessages.firstIndex(where: { $0.id == responseMessage.id }) {
                        cachedMessages[index] = responseMessage
                        messageCache[chatId] = cachedMessages
                    }
                }
            }
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
    
    /// Gets the current relationship status between a user and character
    /// - Parameters:
    ///   - userId: The user's ID
    ///   - characterId: The character's ID
    /// - Returns: Current relationship status (-1000 to 1000)
    func getRelationshipStatus(userId: String, characterId: String) async throws -> Int {
        print("📱 CharacterChatService - Getting relationship status for user: \(userId) with character: \(characterId)")
        
        let chatId = "\(userId)_\(characterId)"
        
        // Check cache first
        if let cached = relationshipCache[chatId] {
            print("📱 CharacterChatService - Returning cached relationship status")
            return cached
        }
        
        // Get from Firestore
        let docRef = db.collection("chats").document(chatId)
        let doc = try await docRef.getDocument()
        
        if let status = doc.data()?["relationship_status"] as? Int {
            // Update cache
            relationshipCache[chatId] = status
            return status
        }
        
        // If no status exists, initialize it
        try await initializeChat(userId: userId, characterId: characterId)
        return 0
    }
    
    /// Updates the relationship status between a user and character
    /// - Parameters:
    ///   - userId: The user's ID
    ///   - characterId: The character's ID
    ///   - change: The change in relationship value (-250 to 50)
    func updateRelationshipStatus(userId: String, characterId: String, change: Int) async throws {
        print("📱 CharacterChatService - Updating relationship status for user: \(userId) with character: \(characterId)")
        
        let chatId = "\(userId)_\(characterId)"
        
        // Get current status
        let currentStatus = try await getRelationshipStatus(userId: userId, characterId: characterId)
        
        // Calculate new status with bounds
        let newStatus = max(-1000, min(1000, currentStatus + change))
        
        // Update Firestore
        try await db.collection("chats").document(chatId).setData([
            "relationship_status": newStatus
        ], merge: true)
        
        // Update cache
        relationshipCache[chatId] = newStatus
        
        print("📱 CharacterChatService - Relationship status updated to: \(newStatus)")
    }
    
    // MARK: - Migration
    
    /// Migrates existing images to character-specific folders
    /// - Returns: Number of images migrated
    /// - Throws: ChatError if migration fails
    func migrateExistingImages() async throws -> Int {
        print("📱 CharacterChatService - Starting image migration")
        
        var allMessages: [ChatMessage] = []
        let characters = try await CharacterService.shared.fetchCharacters()
        
        // Collect all messages with images
        for character in characters {
            let messages = try await loadChatHistory(for: character)
            allMessages.append(contentsOf: messages)
        }
        
        // Migrate images using StableDiffusionService
        do {
            try StableDiffusionService.shared.migrateExistingImages(messages: allMessages)
            let migratedCount = allMessages.filter { $0.type == .textWithImage || $0.type == .image }.count
            print("📱 CharacterChatService - Successfully migrated \(migratedCount) images")
            return migratedCount
        } catch {
            print("❌ CharacterChatService - Error during image migration: \(error)")
            throw ChatError.persistenceFailed
        }
    }
    
    // MARK: - Private Methods
    
    /// Saves a chat message to Firestore
    private func saveChatMessage(_ message: ChatMessage, characterId: String) async throws {
        print("📱 CharacterChatService - Saving message: \(message.id)")
        
        let userId = AuthService.shared.currentUserId ?? ""
        let chatId = "\(userId)_\(characterId)"
        
        var messageData: [String: Any] = [
            "id": message.id,
            "text": message.text,
            "sender": message.sender == .user ? "user" : "character",
            "timestamp": FieldValue.serverTimestamp(),
            "sequence": message.sequence,
            "status": "sent",
            "type": message.type.rawValue
        ]
        
        // Add image generation status if present
        if let status = message.imageGenerationStatus {
            switch status {
            case .queued:
                messageData["imageGenerationStatus"] = "queued"
            case .generating:
                messageData["imageGenerationStatus"] = "generating"
            case .completed:
                messageData["imageGenerationStatus"] = "completed"
            case .failed(let error):
                messageData["imageGenerationStatus"] = "failed"
                messageData["imageGenerationError"] = error.localizedDescription
            }
        }
        
        try await db.collection("chats")
            .document(chatId)
            .collection("messages")
            .document(message.id)
            .setData(messageData)
    }
    
    /// Clears all caches
    func clearCache() {
        print("📱 CharacterChatService - Clearing all caches")
        messageCache.removeAll()
        relationshipCache.removeAll()
    }
    
    /// Initializes a new chat with default relationship status
    private func initializeChat(userId: String, characterId: String) async throws {
        print("📱 CharacterChatService - Initializing chat for user: \(userId) with character: \(characterId)")
        
        let chatId = "\(userId)_\(characterId)"
        try await db.collection("chats").document(chatId).setData([
            "relationship_status": 0
        ], merge: true)
        
        // Update cache
        relationshipCache[chatId] = 0
        
        print("📱 CharacterChatService - Chat initialized successfully")
    }
    
    /// Creates a chat context from the current state
    /// - Parameters:
    ///   - messages: Recent chat messages
    ///   - character: The character being chatted with
    ///   - relationshipChange: Most recent relationship change
    /// - Returns: A ChatContext object
    private func createChatContext(
        messages: [ChatMessage],
        character: GameCharacter,
        relationshipChange: Int
    ) async throws -> ChatContext {
        let relationshipStatus = try await getRelationshipStatus(
            userId: AuthService.shared.currentUserId ?? "",
            characterId: character.id
        )
        
        return ChatContext(
            messages: messages,
            character: character,
            relationshipStatus: relationshipStatus,
            relationshipChange: relationshipChange
        )
    }
} 