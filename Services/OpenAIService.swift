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
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {}
    
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
        
        // Prepare system prompt
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
        
        // Create request data
        let requestData: [String: Any] = [
            "messages": apiMessages,
            "temperature": 0.7,
            "maxTokens": 150
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
                // Try parsing as JSON first
                if let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let content = jsonResponse["content"] as? String {
                    print("📱 OpenAIService - Generated response successfully (JSON)")
                    return content
                }
                
                // If JSON parsing fails, try using the response as raw text
                if let content = String(data: data, encoding: .utf8) {
                    print("📱 OpenAIService - Generated response successfully (raw text)")
                    return content
                }
                
                // If both parsing attempts fail, log the response and throw error
                print("❌ OpenAIService - Invalid response format")
                print("📱 OpenAIService - Response data: \(String(data: data, encoding: .utf8) ?? "none")")
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