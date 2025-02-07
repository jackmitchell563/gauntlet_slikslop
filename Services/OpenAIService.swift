import Foundation

/// Service for handling OpenAI API interactions
class OpenAIService {
    // MARK: - Properties
    
    /// Shared instance for singleton access
    static let shared = OpenAIService()
    
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    private let model = "gpt-4o-mini"
    
    // MARK: - Types
    
    enum OpenAIError: LocalizedError {
        case invalidURL
        case invalidResponse
        case apiError(String)
        case missingAPIKey
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid API URL"
            case .invalidResponse:
                return "Invalid response from OpenAI"
            case .apiError(let message):
                return "OpenAI API error: \(message)"
            case .missingAPIKey:
                return "OpenAI API key not found"
            }
        }
    }
    
    struct ChatRequest: Codable {
        let model: String
        let messages: [[String: String]]
        let temperature: Double
        let max_tokens: Int
    }
    
    struct ChatResponse: Codable {
        let choices: [Choice]
        
        struct Choice: Codable {
            let message: Message
            
            struct Message: Codable {
                let content: String
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        self.apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        if apiKey.isEmpty {
            print("⚠️ OpenAIService - Warning: API key not found in environment")
        }
    }
    
    // MARK: - Public Methods
    
    /// Generates a character response based on conversation history
    /// - Parameters:
    ///   - messages: Array of previous chat messages
    ///   - character: The character generating the response
    /// - Returns: Generated response text
    func generateResponse(
        messages: [ChatMessage],
        character: GameCharacter
    ) async throws -> String {
        print("📱 OpenAIService - Generating response for character: \(character.name)")
        
        guard !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }
        
        // Construct system prompt
        let systemPrompt = """
            You are \(character.name), a character from \(character.game).
            Background: \(character.backgroundStory)
            Personality: \(character.personalityProfile)
            Speaking style: \(character.speakingStyle)
            Traits: \(character.traits.joined(separator: ", "))
            
            Respond in character, maintaining consistent personality and speech patterns.
            Keep responses concise and engaging.
            """
        
        // Prepare messages for API
        var apiMessages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]
        
        // Add conversation history
        messages.forEach { message in
            let role = message.sender == .user ? "user" : "assistant"
            apiMessages.append([
                "role": role,
                "content": message.text
            ])
        }
        
        // Create request
        let request = ChatRequest(
            model: model,
            messages: apiMessages,
            temperature: 0.7,
            max_tokens: 150
        )
        
        // Encode request
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            throw OpenAIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        // Make API call
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorResponse = try? JSONDecoder().decode([String: String].self, from: data)
            throw OpenAIError.apiError(errorResponse?["error"] ?? "Unknown error")
        }
        
        // Parse response
        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw OpenAIError.invalidResponse
        }
        
        print("📱 OpenAIService - Generated response successfully")
        return content
    }
} 