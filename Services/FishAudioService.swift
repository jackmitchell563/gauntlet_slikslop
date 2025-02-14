import Foundation
import AVFoundation

/// Service for handling Fish Audio API interactions and voice clip generation
class FishAudioService {
    // MARK: - Properties
    
    /// Shared instance for singleton access
    static let shared = FishAudioService()
    
    /// API endpoint for text-to-speech
    private let apiEndpoint = "https://api.fish.audio/v1/tts"
    
    /// Notification name for when audio generation is complete
    static let audioGenerationCompleted = NSNotification.Name("AudioGenerationCompleted")
    
    /// Maps character names to their voice reference IDs
    private let characterVoices: [String: String] = [
        "Hu Tao": "d6b08c6a070844baa4ba377f29c5a292",
        "Raiden Shogun": "997db0af55f0411e82e7b0e2df8c6faa",
        "Yae Miko": "87522cb7c4f749e3be28a78bb42c6739",
        // Add more characters here with their reference IDs
        // Example format:
        // "Character Name": "reference_id",
    ]
    
    // MARK: - Private Methods
    
    /// Gets the API key from environment variables
    private var apiKey: String? {
        ProcessInfo.processInfo.environment["FISH_AUDIO_API_KEY"]
    }
    
    // MARK: - Types
    
    /// Errors that can occur during audio operations
    enum AudioError: LocalizedError {
        case missingAPIKey
        case invalidResponse
        case audioGenerationFailed(String)
        case saveFailed
        case serializationFailed
        case voiceNotAvailable
        
        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Missing Fish Audio API token"
            case .invalidResponse:
                return "Invalid response from Fish Audio API"
            case .audioGenerationFailed(let reason):
                return "Audio generation failed: \(reason)"
            case .saveFailed:
                return "Failed to save audio file"
            case .serializationFailed:
                return "Failed to serialize request data"
            case .voiceNotAvailable:
                return "Voice not available for this character"
            }
        }
    }
    
    /// Request structure for text-to-speech API
    struct TTSRequest: Codable {
        let text: String
        let chunkLength: Int
        let format: String
        let mp3Bitrate: Int
        let normalize: Bool
        let latency: String
        let referenceId: String
        
        enum CodingKeys: String, CodingKey {
            case text
            case chunkLength = "chunk_length"
            case format
            case mp3Bitrate = "mp3_bitrate"
            case normalize
            case latency
            case referenceId = "reference_id"
        }
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Generates a voice clip from text using Fish Audio API
    /// - Parameters:
    ///   - text: The Japanese text to convert to speech
    ///   - messageId: The ID of the associated message
    ///   - character: The character to generate voice for
    /// - Returns: URL where the audio file is saved
    /// - Throws: AudioError if generation or saving fails
    func generateVoiceClip(text: String, messageId: String, character: GameCharacter) async throws -> URL {
        print("📱 FishAudioService - Generating voice clip for message: \(messageId)")
        
        // Check if voice is available for this character
        guard let referenceId = characterVoices[character.name] else {
            print("📱 FishAudioService - No voice available for character: \(character.name)")
            throw AudioError.voiceNotAvailable
        }
        
        guard let token = apiKey else {
            print("❌ FishAudioService - Missing API key")
            throw AudioError.missingAPIKey
        }
        
        // Create request with character's voice model ID
        let request = TTSRequest(
            text: text,
            chunkLength: 200,
            format: "mp3",
            mp3Bitrate: 128,
            normalize: true,
            latency: "normal",
            referenceId: referenceId
        )
        
        // Serialize request using JSON
        guard let requestData = try? JSONEncoder().encode(request) else {
            print("❌ FishAudioService - Failed to serialize request")
            throw AudioError.serializationFailed
        }
        
        // Create URL request
        var urlRequest = URLRequest(url: URL(string: apiEndpoint)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = requestData
        
        do {
            // Get save location
            let saveURL = try StableDiffusionService.shared.getAudioStorageURL(for: character)
                .appendingPathComponent("\(messageId).mp3")
            
            // Download and save audio
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("❌ FishAudioService - Invalid response: \(response)")
                throw AudioError.invalidResponse
            }
            
            // Save to disk
            try data.write(to: saveURL)
            print("📱 FishAudioService - Saved voice clip to: \(saveURL.path)")
            
            // Notify that audio is ready
            NotificationCenter.default.post(
                name: FishAudioService.audioGenerationCompleted,
                object: nil,
                userInfo: [
                    "messageId": messageId,
                    "character": character
                ]
            )
            
            return saveURL
            
        } catch let error as AudioError {
            throw error
        } catch {
            print("❌ FishAudioService - Unexpected error: \(error)")
            throw AudioError.audioGenerationFailed(error.localizedDescription)
        }
    }
} 