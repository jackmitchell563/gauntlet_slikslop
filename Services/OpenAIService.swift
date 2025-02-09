import Foundation

/// Service for handling OpenAI API interactions
class OpenAIService {
    // MARK: - Properties
    
    /// Shared instance for singleton access
    static let shared = OpenAIService()
    
    private let lambdaEndpoint = "https://gooi6zviqf.execute-api.us-east-2.amazonaws.com/prod/generate"
    
    // MARK: - Types
    
    enum OpenAIError: LocalizedError {
        case invalidResponse
        case apiError(String)
        case unauthorized
        case rateLimitExceeded
        case networkError
        case invalidRelationshipResponse
        
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
            }
        }
    }
    
    /// Response structure for relationship-enabled chat
    struct AIResponse: Codable {
        let content: String
        let relationship_value_change: Int
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
            
            IMPORTANT - RESPONSE HIERARCHY:
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
                - NEW status between -1000 and -500: Be very angry and hostile
                - NEW status between -500 and -301: Be cold and distant
                - NEW status between -300 and -101: Be curt and annoyed
            - Zero: Neutral
                - NEW status between -100 and 100: Be neutral and professional
            - Positive values: Affectionate, warm, loving, or sweet depending on your personality
                - NEW status between 101 and 300: Be warm and affectionate
                - NEW status between 301 and 500: Be very warm and affectionate
                - NEW status between 500 and 1000: Be very warm and loving

            Example thought process:
            1. Current relationshipStatus is 80
            2. User's message shows basic politeness (+25 relationship_value_change)
            3. New status would be 105
            4. Therefore, respond with a warm and affectionate tone (101-300 range)
            
            Return your response in JSON-formatted string format:
            **IMPORTANT:** Your response must be a single string that contains valid JSON with a "content" and "relationship_value_change" key. For example:
            "{\"content\": \"your message here\", \"relationship_value_change\": 0}"
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
            }
            
            switch httpResponse.statusCode {
            case 200:
                // Log the raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📱 OpenAIService - Raw response from Lambda: \(responseString)")
                }
                
                // Directly decode the response as AIResponse
                if let aiResponse = try? JSONDecoder().decode(AIResponse.self, from: data) {
                    print("📱 OpenAIService - Successfully decoded response")
                    return (aiResponse.content, aiResponse.relationship_value_change)
                }
                
                print("❌ OpenAIService - Failed to decode response")
                throw OpenAIError.invalidResponse
                
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