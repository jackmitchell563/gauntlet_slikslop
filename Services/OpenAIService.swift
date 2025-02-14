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
    case invalidFunctionCall
    case missingAPIKey
    case invalidArgumentFormat
    
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
        case .invalidFunctionCall:
            return "Invalid function call in response"
        case .missingAPIKey:
            return "Missing API key"
        case .invalidArgumentFormat:
            return "Invalid argument format"
        }
    }
}

/// Service for handling OpenAI API interactions
class OpenAIService {
    // MARK: - Properties
    
    /// Shared instance for singleton access
    static let shared = OpenAIService()
    
    private let lambdaEndpoint = "https://gooi6zviqf.execute-api.us-east-2.amazonaws.com/prod/generate"
    private let tagGenerationEndpoint = "https://gooi6zviqf.execute-api.us-east-2.amazonaws.com/prod/generate"
    private let openAIEndpoint = "https://api.openai.com/v1/chat/completions"
    
    private var apiKey: String? {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
    }
    
    // MARK: - Types
    
    /// Response structure for relationship-enabled chat
    struct AIResponse: Codable {
        let content: String
        let japaneseContent: String
        let relationship_value_change: Int
    }
    
    /// Response structure for tag generation
    struct TagResponse: Codable {
        let positive_prompt: String
        let negative_prompt: String
    }
    
    struct FunctionDefinition: Codable {
        let name: String
        let description: String
        let parameters: Parameters
        
        struct Parameters: Codable {
            let type: String
            let properties: [String: Property]
            let required: [String]
        }
        
        struct Property: Codable {
            let type: String
            let description: String
        }
    }

    struct CharacterResponseFunction {
        static let definition = FunctionDefinition(
            name: "generate_character_response",
            description: "Generate a character's response with relationship changes",
            parameters: .init(
                type: "object",
                properties: [
                    "content": .init(
                        type: "string",
                        description: "The character's response message"
                    ),
                    "japaneseContent": .init(
                        type: "string",
                        description: "Natural Japanese translation of the response"
                    ),
                    "relationship_value_change": .init(
                        type: "integer",
                        description: "How much the user's message affects feelings (-500 to 200)"
                    )
                ],
                required: ["content", "japaneseContent", "relationship_value_change"]
            )
        )
    }

    struct OpenAIRequest: Codable {
        let model: String
        let messages: [Message]
        let functions: [FunctionDefinition]
        let function_call: FunctionCall
        let temperature: Double
        let max_tokens: Int
        
        struct Message: Codable {
            let role: String
            let content: String
        }
        
        struct FunctionCall: Codable {
            let name: String
        }
    }

    struct OpenAIResponse: Codable {
        let choices: [Choice]
        
        struct Choice: Codable {
            let message: Message
            
            struct Message: Codable {
                let function_call: FunctionCall
                
                struct FunctionCall: Codable {
                    let name: String
                    let arguments: String
                }
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Generates a character response based on conversation history and relationship status
    /// - Parameters:
    ///   - messages: Array of previous chat messages
    ///   - character: The character generating the response
    ///   - relationshipStatus: Current relationship status (-1000 to 1000)
    /// - Returns: Tuple containing response text, Japanese translation, and relationship value change
    func generateResponse(
        messages: [ChatMessage],
        character: GameCharacter,
        relationshipStatus: Int = 0
    ) async throws -> (content: String, japaneseContent: String, relationshipChange: Int) {
        print("📱 OpenAIService - Generating response for character: \(character.name)")
        
        guard let apiKey = apiKey else {
            print("❌ OpenAIService - Missing API key")
            throw OpenAIError.missingAPIKey
        }
        
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
            
            **IMPORTANT - TRANSLATION REQUIREMENT:**
            After crafting your response in English, you must provide a natural Japanese translation that:
            1. Maintains the emotional tone and nuance of your English response
            2. Uses appropriate Japanese speech patterns for your character (casual/formal/etc.)
            3. Includes appropriate Japanese particles and expressions
            4. Preserves any character-specific speech patterns
            5. Uses natural Japanese word order and grammar
            
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
        var apiMessages: [OpenAIRequest.Message] = [
            .init(role: "system", content: systemPrompt)
        ]
        
        // Add conversation history
        messages.forEach { message in
            let role = message.sender == .user ? "user" : "assistant"
            apiMessages.append(.init(
                role: role,
                content: message.text
            ))
        }
        
        // Create request
        let request = OpenAIRequest(
            model: "gpt-4o-mini",
            messages: apiMessages,
            functions: [CharacterResponseFunction.definition],
            function_call: .init(name: "generate_character_response"),
            temperature: 0.7,
            max_tokens: 1500
        )
        
        // Create URL request
        var urlRequest = URLRequest(url: URL(string: openAIEndpoint)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        // Log request details
        logRequest(urlRequest)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            // Check HTTP status
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ OpenAIService - Invalid response type received")
                throw OpenAIError.invalidResponse
            }
            
            // Log response status
            print("📱 OpenAIService - Response status: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200:
                let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                guard let functionCall = openAIResponse.choices.first?.message.function_call,
                      functionCall.name == "generate_character_response" else {
                    print("❌ OpenAIService - Invalid function call in response")
                    throw OpenAIError.invalidFunctionCall
                }
                
                let aiResponse = try JSONDecoder().decode(AIResponse.self, 
                                                        from: functionCall.arguments.data(using: .utf8)!)
                
                // Clamp relationship value
                let clampedValue = min(max(aiResponse.relationship_value_change, -500), 200)
                if clampedValue != aiResponse.relationship_value_change {
                    print("📱 OpenAIService - Clamped relationship value from \(aiResponse.relationship_value_change) to \(clampedValue)")
                }
                
                return (aiResponse.content, aiResponse.japaneseContent, clampedValue)
                
            case 401:
                throw OpenAIError.unauthorized
            case 429:
                throw OpenAIError.rateLimitExceeded
            default:
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorData["error"] as? String {
                    throw OpenAIError.apiError(errorMessage)
                }
                throw OpenAIError.apiError("HTTP \(httpResponse.statusCode)")
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
            You are an expert at generating Stable Diffusion prompts, specializing in creating high-quality character images.
            Given the chat context and character information, generate appropriate positive and negative prompts.
            
            Character: \(context.character.name) from \(context.character.game)
            Background: \(context.character.backgroundStory)
            Personality: \(context.character.personalityProfile)
            Current relationship: \(context.relationshipStatus)
            Recent relationship change: \(context.relationshipChange)
            
            IMPORTANT: Return ONLY comma-separated descriptors, NO full sentences. Follow this exact format:
            
            Example positive prompt:
            (masterpiece), (best quality), shenhe (genshin impact), [(white background:1.5)::5], isometric, 1woman, mature female, mid shot, upper body, blue eyes, long silver hair, elegant dress, shoulder cutout, side glance, confident pose, looking at viewer, magic circle, ice particles, glowing effects
            
            Example negative prompt:
            (low quality, worst quality:1.4), (monochrome:1.1), bad-artist, badhandv4, easynegative, (deformed:1.8), (malformed hands:1.4), (poorly drawn hands:1.4), (mutated fingers:1.4), (bad anatomy:1.5), (extra limbs:1.35), (poorly drawn face:1.4), (signature:1.2), (watermark:1.2)
            
            Required elements in order (comma-separated):
            
            Positive prompt:
            1. Quality tags: (masterpiece), (best quality)
            2. Character identifier: charactername (gamename) - REQUIRED, EXACTLY AS PROVIDED
            3. Background: [(white background:1.5)::5] or appropriate setting
            4. Shot composition: isometric/mid shot/upper body
            5. Character details:
               - Demographics: 1woman/1man, mature/young
               - Face/Hair: eye color, hair style/color
               - Clothing: specific outfit details
               - Pose: standing/sitting, viewing angle
            6. Effects (based on context):
               - Magic/elemental effects
               - Particles/glows
               - Environmental effects
            7. Emotional state (based on relationship):
               - Negative: cold glare, frowning, hostile pose
               - Neutral: professional stance, neutral expression
               - Positive: warm smile, friendly gesture, soft expression
            
            Negative prompt (comma-separated):
            1. (low quality, worst quality:1.4)
            2. (monochrome:1.1)
            3. bad-artist, badhandv4, easynegative
            4. (deformed:1.8), (malformed hands:1.4), (poorly drawn hands:1.4), (mutated fingers:1.4), (bad anatomy:1.5)
            5. (extra hand:1.4), (extra limbs:1.35)
            6. (poorly drawn face:1.4), (signature:1.2), (watermark:1.2)
            
            Weight syntax:
            - Basic: (tag:1.4)
            - Emphasis: [(tag:1.5)::5]
            - Stack weights as needed
            
            Format response as JSON with 'positive_prompt' and 'negative_prompt' fields, each containing a single string of comma-separated descriptors.
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
            "maxTokens": 1000,
            "path": "/generate-tags"  // Add path parameter to indicate tag generation
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