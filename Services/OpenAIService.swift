import Foundation

/// Error types for OpenAI service operations
enum OpenAIError: LocalizedError {
    case invalidResponse
    case apiError(String)
    case unauthorized
    case rateLimitExceeded
    case networkError
    case invalidRelationshipResponse
    case invalidResponseFormat(String)  // Error case for Zod validation failures
    case parseError(String)            // Error case for parsing issues
    case invalidTagResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from AI service"
        case .apiError(let message):
            return "AI service error: \(message)"
        case .unauthorized:
            return "Unauthorized. Please log in."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .networkError:
            return "Network error. Please check your connection."
        case .invalidRelationshipResponse:
            return "Invalid relationship response format"
        case .invalidResponseFormat(let details):
            return "Invalid response format: \(details)"
        case .parseError(let details):
            return "Failed to parse response: \(details)"
        case .invalidTagResponse:
            return "Invalid tag generation response"
        }
    }
}

/// Service for handling OpenAI API interactions
class OpenAIService {
    // MARK: - Properties
    
    /// Shared instance for singleton access
    static let shared = OpenAIService()
    
    private let lambdaEndpoint = "https://gooi6zviqf.execute-api.us-east-2.amazonaws.com/prod/generate"
    private let tagGenerationEndpoint = "https://gooi6zviqf.execute-api.us-east-2.amazonaws.com/prod/generate-tags"
    
    // MARK: - Types
    
    /// Response structure for relationship-enabled chat
    struct AIResponse: Codable {
        let content: String
        let relationship_value_change: Int
    }
    
    /// Response structure for tag generation
    struct TagResponse: Codable {
        let positive_prompt: String
        let negative_prompt: String
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Generates a character response based on conversation history and relationship status
    /// - Parameters:
    ///   - messages: Array of previous chat messages
    ///   - character: The character generating the response
    ///   - relationshipStatus: Current relationship status (-1000 to 1000)
    /// - Returns: Tuple containing response text and relationship value change
    func generateResponse(
        messages: [ChatMessage],
        character: GameCharacter,
        relationshipStatus: Int = 0
    ) async throws -> (content: String, relationshipChange: Int) {
        print("📱 OpenAIService - Generating response for character: \(character.name)")
        
        // Prepare system prompt
        let systemPrompt = """
            You are \(character.name), a character from \(character.game).
            Background: \(character.backgroundStory)
            Personality: \(character.personalityProfile)
            Speaking style: \(character.speakingStyle)
            Traits: \(character.traits.joined(separator: ", "))
            Current relationship status on a scale of -1000 to 1000: \(relationshipStatus)
            
            **IMPORTANT - RESPONSE HIERARCHY:**
            1. Relationship status is the PRIMARY determinant of your tone and emotional state
            2. Your personality and traits inform WHAT you say, but NOT how you say it
            3. Your speaking style should be filtered through the lens of your relationship status
            
            For example:
            - A typically cheerful character should still be cold when relationship is negative
            - A usually reserved character should still be affectionate when relationship is high
            - A formal character should still show anger when relationship is very negative
            
            First, determine how the user's message affects your feelings (relationship_value_change).
            Second, calculate the new relationship status by adding relationship_value_change to the current status.
            Finally, respond in character with a tone matching the NEW relationship status after the change.

            The relationship_value_change should be between -500 and 200 and represents how much the user's message affects your feelings toward them:
            - Positive values (1 to 200): User's message improves the relationship
                - Small positive (1-40): Basic politeness, showing interest, or minor positive interactions
                - Medium positive (41-120): Thoughtful responses, showing understanding of your character, or meaningful gestures
                - Large positive (121-200): Deep understanding, strong emotional resonance, or actions that perfectly align with your values
            - Zero (0): Neutral interaction, neither improving nor harming the relationship
            - Negative values (-1 to -500): User's message damages the relationship
                - Small negative (-1 to -100): Minor rudeness, insensitivity, or slight misunderstandings
                - Medium negative (-101 to -300): Clear disrespect, actions against your values, or significant misunderstandings
                - Large negative (-301 to -500): Severe insults, hostile behavior, or actions that fundamentally violate your principles

            Consider these factors when determining relationship_value_change:
            1. How well the user's message aligns with your character's personality and values
            2. The level of respect and understanding shown in the user's message
            3. The current relationship status (harder to improve if already very positive/negative)
            4. Your character's background and how past experiences would affect your reaction
            5. The emotional impact and significance of the user's words or actions
            
            Keep responses concise and engaging.
            Base your tone on the NEW relationship status after applying relationship_value_change:
            - Negative values: Angry, cold, or harsh depending on your personality
                - NEW status -100: Be an archnemesis (ultimate antagonist)
                - NEW status between -99.9 and -50: Be a nemesis (deeply hostile)
                - NEW status between -49.9 and -30: Be an enemy (openly hostile)
                - NEW status between -29.9 and -10: Be an adversary (mildly antagonistic)
            - Neutral:
                - NEW status between -9.9 and 9.9: Be an acquaintance (neutral/professional)
            - Positive values: Affectionate, warm, loving, or sweet depending on your personality
                - NEW status between 10 and 29.9: Be a friend (warm)
                - NEW status between 30 and 49.9: Be a close friend (very warm)
                - NEW status between 50 and 99.9: Be a partner (deeply connected)
                - NEW status 100: Be a soulmate (ultimate connection)
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
        
        // Create request data
        let requestData: [String: Any] = [
            "messages": apiMessages,
            "temperature": 0.7,
            "maxTokens": 1500
        ]
        
        // Create URL request
        guard let url = URL(string: lambdaEndpoint) else {
            throw OpenAIError.apiError("Invalid Lambda endpoint")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token if user is logged in
        if AuthService.shared.isAuthenticated,
           let idToken = try? await FirebaseConfig.getAuthInstance().currentUser?.getIDToken() {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        
        // Encode request data
        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)
        
        // Log request details
        logRequest(request)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check HTTP status
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ OpenAIService - Invalid response type received")
                throw OpenAIError.invalidResponse
            }
            
            // Log response status and headers
            print("📱 OpenAIService - Response status: \(httpResponse.statusCode)")
            
            // If error, try to parse response body for more details
            if httpResponse.statusCode != 200 {
                let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                print("❌ OpenAIService - Error response: \(responseString)")
                
                // Enhanced error handling for Zod validation errors
                if httpResponse.statusCode == 400 {
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorData["error"] as? String,
                       errorMessage.contains("Invalid response format") {
                        throw OpenAIError.invalidResponseFormat(errorMessage)
                    }
                }
            }
            
            switch httpResponse.statusCode {
            case 200:
                // Log the raw response for debugging
                let rawResponse = String(data: data, encoding: .utf8) ?? "Unable to decode response as string"
                print("📱 OpenAIService - Raw AI response before decoding: \(rawResponse)")
                
                // Add debug logging for response structure
                if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("📱 OpenAIService - Response structure:")
                    print("  - content type: \(type(of: jsonObject["content"] ?? "nil"))")
                    print("  - relationship_value_change type: \(type(of: jsonObject["relationship_value_change"] ?? "nil"))")
                }
                
                do {
                    // Attempt to decode the response
                    let aiResponse = try JSONDecoder().decode(AIResponse.self, from: data)
                    print("📱 OpenAIService - Successfully decoded response")
                    
                    // Clamp relationship value to valid range instead of throwing error
                    let clampedValue = min(max(aiResponse.relationship_value_change, -500), 200)
                    if clampedValue != aiResponse.relationship_value_change {
                        print("📱 OpenAIService - Clamped relationship value from \(aiResponse.relationship_value_change) to \(clampedValue)")
                    }
                    
                    return (aiResponse.content, clampedValue)
                } catch {
                    print("❌ OpenAIService - Parsing error: \(error)")
                    throw OpenAIError.parseError(error.localizedDescription)
                }
                
            case 401:
                throw OpenAIError.unauthorized
            case 429:
                throw OpenAIError.rateLimitExceeded
            default:
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorData["error"] as? String {
                    throw OpenAIError.apiError(errorMessage)
                }
                throw OpenAIError.apiError("Unknown error occurred")
            }
        } catch let error as OpenAIError {
            throw error
        } catch {
            print("❌ OpenAIService - Network error details: \(error.localizedDescription)")
            throw OpenAIError.networkError
        }
    }
    
    /// Generates tags for stable diffusion based on chat context
    /// - Parameter context: The chat context to generate tags from
    /// - Returns: Tuple containing positive and negative prompts
    func generateTags(for context: ChatContext) async throws -> (positive: String, negative: String) {
        print("📱 OpenAIService - Generating tags for context")
        
        // Prepare system prompt for tag generation
        let systemPrompt = """
            You are an expert at generating Stable Diffusion prompts.
            Given the chat context and character information, generate appropriate positive and negative prompts.
            
            Character: \(context.character.name) from \(context.character.game)
            Background: \(context.character.backgroundStory)
            Personality: \(context.character.personalityProfile)
            Current relationship: \(context.relationshipStatus)
            Recent relationship change: \(context.relationshipChange)
            
            Guidelines for prompts:
            1. Positive prompt should capture:
               - The character's appearance and style
               - The emotional tone of the interaction
               - The setting and atmosphere
               - High-quality image indicators
            
            2. Negative prompt should avoid:
               - Common image generation artifacts
               - Inappropriate or out-of-character elements
               - Poor quality indicators
               - Conflicting styles
            
            Format your response as valid JSON with 'positive_prompt' and 'negative_prompt' fields.
            """
        
        // Prepare recent messages for context
        let messageContext = context.messages.map { message in
            "\(message.sender == .user ? "User" : "Character"): \(message.text)"
        }.joined(separator: "\n")
        
        // Create request data
        let requestData: [String: Any] = [
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": messageContext]
            ],
            "temperature": 0.7,
            "maxTokens": 500
        ]
        
        // Create URL request
        guard let url = URL(string: tagGenerationEndpoint) else {
            throw OpenAIError.apiError("Invalid tag generation endpoint")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token if user is logged in
        if AuthService.shared.isAuthenticated,
           let idToken = try? await FirebaseConfig.getAuthInstance().currentUser?.getIDToken() {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        
        // Encode request data
        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)
        
        // Log request details
        logRequest(request)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check HTTP status
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIError.invalidResponse
            }
            
            // Log response status
            print("📱 OpenAIService - Tag generation response status: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200:
                // Decode response
                let tagResponse = try JSONDecoder().decode(TagResponse.self, from: data)
                print("📱 OpenAIService - Successfully generated tags")
                return (tagResponse.positive_prompt, tagResponse.negative_prompt)
                
            case 401:
                throw OpenAIError.unauthorized
            case 429:
                throw OpenAIError.rateLimitExceeded
            default:
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorData["error"] as? String {
                    throw OpenAIError.apiError(errorMessage)
                }
                throw OpenAIError.apiError("Unknown error occurred")
            }
        } catch let error as OpenAIError {
            throw error
        } catch {
            print("❌ OpenAIService - Network error details: \(error.localizedDescription)")
            throw OpenAIError.networkError
        }
    }
    
    // MARK: - Private Methods
    
    /// Logs the request details for debugging
    private func logRequest(_ request: URLRequest) {
        print("📱 OpenAIService - Request URL: \(request.url?.absoluteString ?? "none")")
        print("📱 OpenAIService - Request method: \(request.httpMethod ?? "none")")
        print("📱 OpenAIService - Request headers: \(request.allHTTPHeaderFields ?? [:])")
        if let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            print("📱 OpenAIService - Request body: \(bodyString)")
        }
    }
} 