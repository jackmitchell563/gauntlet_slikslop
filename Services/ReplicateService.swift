import Foundation
import UIKit

/// Service for handling Replicate API image generation
class ReplicateService {
    // MARK: - Properties
    
    /// Shared instance for singleton access
    static let shared = ReplicateService()
    
    /// API endpoint for predictions
    private let apiEndpoint = "https://api.replicate.com/v1/predictions"
    
    /// Model version ID for Stable Diffusion with LoRA support
    private let modelVersion = "2fabd9b0e3d54ece7ecf2a1d0ba21b9f150ad8c2d534d671e21d4741f1ced932"
    
    /// CivitAI LoRA URL
    private var loraURL: String {
        let baseURL = "https://civitai.com/api/download/models/38884?type=Model&format=SafeTensor"
        if let token = ProcessInfo.processInfo.environment["CIVITAI_API_TOKEN"] {
            return "\(baseURL)&token=\(token)"
        }
        return baseURL
    }
    
    /// API token from environment variables
    private var apiToken: String? { ProcessInfo.processInfo.environment["REPLICATE_API_TOKEN"] }
    
    /// URLSession for API requests
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60  // 1 minute for individual requests
        config.timeoutIntervalForResource = 600  // 10 minutes max for entire operation
        return URLSession(configuration: config)
    }()
    
    // MARK: - Types
    
    /// Errors specific to Replicate API operations
    enum ReplicateError: LocalizedError {
        case missingAPIToken
        case invalidRequest
        case invalidResponse
        case predictionFailed(String)
        case downloadFailed
        case timeout
        case rateLimitExceeded
        case serverError(Int)
        case noOutputGenerated
        
        var errorDescription: String? {
            switch self {
            case .missingAPIToken:
                return "Missing Replicate API token"
            case .invalidRequest:
                return "Invalid API request"
            case .invalidResponse:
                return "Invalid response from Replicate API"
            case .predictionFailed(let reason):
                return "Image generation failed: \(reason)"
            case .downloadFailed:
                return "Failed to download generated image"
            case .timeout:
                return "Operation timed out"
            case .rateLimitExceeded:
                return "Rate limit exceeded"
            case .serverError(let code):
                return "Server error: \(code)"
            case .noOutputGenerated:
                return "No output was generated"
            }
        }
    }
    
    /// Response structure for prediction creation
    private struct PredictionResponse: Codable {
        let id: String
        let status: String
        let output: [String]?
        let error: String?
        
        /// Debug description for logging
        var debugDescription: String {
            """
            PredictionResponse:
              id: \(id)
              status: \(status)
              output: \(output?.description ?? "nil")
              error: \(error ?? "nil")
            """
        }
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Generates an image using the Replicate API
    /// - Parameters:
    ///   - prompt: The prompt describing the image to generate
    ///   - character: The character to generate the image for
    /// - Returns: The generated image
    /// - Throws: ReplicateError if generation fails
    func generateImage(prompt: String, character: GameCharacter) async throws -> UIImage {
        print("📱 ReplicateService - Starting image generation with prompt: \(prompt)")
        
        // Verify API token
        guard let token = apiToken else {
            print("❌ ReplicateService - Missing API token")
            throw ReplicateError.missingAPIToken
        }
        
        do {
            // Start prediction
            let predictionData = try await makeAPIRequest(prompt: prompt, character: character, token: token)
            
            // Parse initial response
            let prediction = try JSONDecoder().decode(PredictionResponse.self, from: predictionData)
            print("📱 ReplicateService - Prediction started with ID: \(prediction.id)")
            
            // Poll for result
            let imageURL = try await pollPrediction(id: prediction.id, token: token)
            print("📱 ReplicateService - Image ready at URL: \(imageURL)")
            
            // Download image
            return try await downloadImage(from: imageURL)
            
        } catch let error as ReplicateError {
            throw error
        } catch {
            print("❌ ReplicateService - Unexpected error: \(error)")
            print("Error details: \(error)")
            throw ReplicateError.invalidResponse
        }
    }
    
    // MARK: - Private Methods
    
    /// Makes the initial API request to start image generation
    /// - Parameters:
    ///   - prompt: The image generation prompt
    ///   - character: The character to generate the image for
    ///   - token: The API token
    /// - Returns: Response data from the API
    /// - Throws: ReplicateError if the request fails
    private func makeAPIRequest(prompt: String, character: GameCharacter, token: String) async throws -> Data {
        var request = URLRequest(url: URL(string: apiEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create a simple character-based prompt
        let characterPrompt = """
            \(character.name) from \(character.game), \
            \(character.personalityProfile), \
            (((masterpiece, best quality, extreme detail))), \
            1girl, solo, mature female, <lora:genshinfull1:1>, \
            perfect fingers, perfect lighting, \
            \(prompt)
            """
        
        // Create request body with all required parameters
        var input: [String: Any] = [
            "width": 512,
            "height": 512,
            "prompt": characterPrompt,
            "scheduler": "K_EULER",
            "num_outputs": 1,
            "guidance_scale": 7,
            "negative_prompt": "FastNegativeV2, EasyNegative, BadDream, paintings, sketches, bad hands, fingers, (worst quality:2), (low quality:2), 2girls, bad artist, text, error",
            "num_inference_steps": 24
        ]
        
        // Only add character field if it's in the predefined list
        let characterId = character.name.lowercased().replacingOccurrences(of: " ", with: "") + "def"
        let validCharacters = Set([
            "kukishinobudef", "luminedef", "doridef", "fischldef", "keqingdef", "lisadef", 
            "raidenshogundef", "yaemikodef", "kujousaradef", "beidoudef", "dionadef", 
            "ganyudef", "kamisatoayakadef", "shenhedef", "euladef", "rosariadef", 
            "qiqidef", "layladef", "niloudef", "kokomidef", "yelandef", "monadef", 
            "barbaradef", "candacedef", "colleidef", "yaoyaodef", "nahidadef", 
            "faruzandef", "jeanfavonian", "sucrosedef", "sayudef", "xianglingdef", 
            "dehyadef", "yoimiyadef", "kleedef", "hutaodef", "xinyandef", "amber5star", 
            "yanfeidef", "noelledef", "yunjindef", "ningguangdef"
        ])
        
        if validCharacters.contains(characterId) {
            input["character"] = characterId
        }
        
        let body: [String: Any] = [
            "version": modelVersion,
            "input": input
        ]
        
        // Log request body for debugging
        print("📱 ReplicateService - Request body: \(body)")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        // Log raw response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("📱 ReplicateService - Raw API response: \(responseString)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReplicateError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw ReplicateError.missingAPIToken
        case 429:
            throw ReplicateError.rateLimitExceeded
        case 500...599:
            throw ReplicateError.serverError(httpResponse.statusCode)
        default:
            throw ReplicateError.invalidRequest
        }
    }
    
    /// Polls the prediction status until completion
    /// - Parameters:
    ///   - id: The prediction ID
    ///   - token: The API token
    /// - Returns: URL of the generated image
    /// - Throws: ReplicateError if polling fails
    private func pollPrediction(id: String, token: String) async throws -> URL {
        let statusURL = "https://api.replicate.com/v1/predictions/\(id)"
        var request = URLRequest(url: URL(string: statusURL)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Poll with exponential backoff
        var attempts = 0
        let maxAttempts = 30  // 30 attempts = ~2 minutes max
        
        while attempts < maxAttempts {
            let (data, response) = try await session.data(for: request)
            
            // Log raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📱 ReplicateService - Raw polling response: \(responseString)")
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ReplicateError.invalidResponse
            }
            
            if httpResponse.statusCode == 200,
               let prediction = try? JSONDecoder().decode(PredictionResponse.self, from: data) {
                print("📱 ReplicateService - Polling response: \(prediction.debugDescription)")
                
                switch prediction.status {
                case "succeeded":
                    guard let outputs = prediction.output,
                          !outputs.isEmpty,
                          let firstOutput = outputs.first,
                          let imageURL = URL(string: firstOutput) else {
                        throw ReplicateError.noOutputGenerated
                    }
                    return imageURL
                    
                case "failed":
                    throw ReplicateError.predictionFailed(prediction.error ?? "Unknown error")
                    
                case "starting", "processing":
                    attempts += 1
                    let delay = Double(min(attempts * 2, 10))  // Max 10 second delay
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                    
                default:
                    throw ReplicateError.invalidResponse
                }
            }
            
            // Handle non-200 responses
            switch httpResponse.statusCode {
            case 429:
                throw ReplicateError.rateLimitExceeded
            case 500...599:
                throw ReplicateError.serverError(httpResponse.statusCode)
            default:
                throw ReplicateError.invalidResponse
            }
        }
        
        throw ReplicateError.timeout
    }
    
    /// Downloads an image from a URL
    /// - Parameter url: The URL of the image to download
    /// - Returns: The downloaded image
    /// - Throws: ReplicateError if download fails
    private func downloadImage(from url: URL) async throws -> UIImage {
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let image = UIImage(data: data) else {
            throw ReplicateError.downloadFailed
        }
        
        return image
    }
} 