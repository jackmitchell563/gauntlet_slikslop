import Foundation
import FirebaseFirestore

/// Service for managing character chat interactions
class CharacterChatService {
    // MARK: - Properties
    
    /// Shared instance for singleton access
    static let shared = CharacterChatService()
    
    private let openAI = OpenAIService.shared
    private let fishAudio = FishAudioService.shared
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
        case audioGenerationFailed(String)
        
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
            case .audioGenerationFailed(let reason):
                return "Failed to generate audio: \(reason)"
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
        let (responseText, japaneseContent, relationshipChange) = try await openAI.generateResponse(
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
        
        // Determine if we should generate image
        let shouldGenerateImage = context.qualifiesForImageGeneration
        
        // Create response message
        var responseMessage = ChatMessage(
            id: UUID().uuidString,
            text: responseText,
            japaneseContent: japaneseContent,
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
        
        // Generate audio in background
        Task {
            do {
                try await generateAndSaveAudio(for: responseMessage)
                
                // Notify that audio is ready
                NotificationCenter.default.post(
                    name: NSNotification.Name("MessageAudioReady"),
                    object: nil,
                    userInfo: ["messageId": responseMessage.id]
                )
            } catch {
                print("❌ CharacterChatService - Failed to generate audio: \(error)")
            }
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
                    
                    // Notify that a new image has been added to the gallery
                    NotificationCenter.default.post(
                        name: NSNotification.Name("GalleryImageAdded"),
                        object: nil,
                        userInfo: ["character": character]
                    )
                    
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
    ///   - beforeSequence: Optional sequence number before which messages should be loaded
    /// - Returns: Array of chat messages
    func loadChatHistory(
        for character: GameCharacter,
        limit: Int = 50,
        beforeSequence: Int? = nil
    ) async throws -> [ChatMessage] {
        print("📱 CharacterChatService - Loading chat history for character: \(character.name)")
        
        let chatId = getChatId(for: character)
        
        // Only use cache for initial load
        if beforeSequence == nil, let cached = messageCache[chatId] {
            print("📱 CharacterChatService - Returning cached messages")
            return cached
        }
        
        // Load from Firestore
        let userId = AuthService.shared.currentUserId ?? ""
        var query = db.collection("chats")
            .document(chatId)
            .collection("messages")
            .order(by: "sequence", descending: true)  // Get newest messages first
            .limit(to: limit)
        
        // If we have a sequence number, load messages before it
        if let beforeSequence = beforeSequence {
            query = query.whereField("sequence", isLessThan: beforeSequence)
        }
        
        let snapshot = try await query.getDocuments()
        
        let messages = try await withThrowingTaskGroup(of: ChatMessage?.self) { group in
            for document in snapshot.documents {
                group.addTask {
                    guard let id = document.data()["id"] as? String,
                          let text = document.data()["text"] as? String,
                          let senderRaw = document.data()["sender"] as? String,
                          let timestamp = document.data()["timestamp"] as? Timestamp,
                          let sequence = document.data()["sequence"] as? Int else {
                        return nil
                    }
                    
                    let sender: MessageSender = senderRaw == "user" ? .user : .character
                    
                    // Check for audio file existence if it's a character message
                    var audioAvailable = false
                    if sender == .character {
                        do {
                            let audioURL = try StableDiffusionService.shared.getAudioStorageURL(for: character)
                                .appendingPathComponent("\(id).mp3")
                            audioAvailable = FileManager.default.fileExists(atPath: audioURL.path)
                        } catch {
                            print("❌ CharacterChatService - Error checking audio file: \(error)")
                        }
                    }
                    
                    return ChatMessage(
                        id: id,
                        text: text,
                        sender: sender,
                        timestamp: timestamp.dateValue(),
                        sequence: sequence,
                        character: sender == .character ? character : nil,
                        audioAvailable: audioAvailable
                    )
                }
            }
            
            var loadedMessages: [ChatMessage] = []
            for try await message in group {
                if let message = message {
                    loadedMessages.append(message)
                }
            }
            return loadedMessages
        }
        
        // Sort messages in ascending order for display
        let sortedMessages = messages.sorted { $0.sequence < $1.sequence }
        
        // Only update cache for initial load
        if beforeSequence == nil {
            messageCache[chatId] = sortedMessages
        }
        
        print("📱 CharacterChatService - Loaded \(sortedMessages.count) messages")
        return sortedMessages
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
    
    // MARK: - Audio Generation
    
    /// Generates and saves audio for a message
    /// - Parameter message: The message to generate audio for
    /// - Throws: ChatError if generation fails
    private func generateAndSaveAudio(for message: ChatMessage) async throws {
        print("📱 CharacterChatService - Generating audio for message: \(message.id)")
        
        guard message.sender == .character,
              let character = message.character,
              let japaneseContent = message.japaneseContent else {
            print("❌ CharacterChatService - Invalid message for audio generation")
            throw ChatError.audioGenerationFailed("Invalid message for audio generation")
        }
        
        do {
            // Generate voice clip
            _ = try await fishAudio.generateVoiceClip(
                text: japaneseContent,
                messageId: message.id,
                character: character
            )
            
            print("📱 CharacterChatService - Successfully generated audio for message: \(message.id)")
            
        } catch let error as FishAudioService.AudioError {
            print("❌ CharacterChatService - Audio generation failed: \(error)")
            throw ChatError.audioGenerationFailed(error.localizedDescription)
        } catch {
            print("❌ CharacterChatService - Unexpected error during audio generation: \(error)")
            throw ChatError.audioGenerationFailed(error.localizedDescription)
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
            "japaneseContent": message.japaneseContent ?? "",
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