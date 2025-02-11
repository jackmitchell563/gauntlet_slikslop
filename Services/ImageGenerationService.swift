import Foundation
import UIKit

/// Service for coordinating image generation between OpenAI and StableDiffusion
class ImageGenerationService {
    // MARK: - Properties
    
    /// Shared instance for singleton access
    static let shared = ImageGenerationService()
    
    private let openAI = OpenAIService.shared
    private let stableDiffusion = StableDiffusionService.shared
    
    // MARK: - Types
    
    enum ImageGenerationError: LocalizedError {
        case tagGenerationFailed(String)
        case imageGenerationFailed(String)
        case invalidContext
        
        var errorDescription: String? {
            switch self {
            case .tagGenerationFailed(let reason):
                return "Failed to generate tags: \(reason)"
            case .imageGenerationFailed(let reason):
                return "Failed to generate image: \(reason)"
            case .invalidContext:
                return "Invalid chat context for image generation"
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Generates an image based on chat context
    /// - Parameter context: The chat context to generate an image for
    /// - Returns: The generated image
    /// - Throws: ImageGenerationError if generation fails
    func generateImageForChat(context: ChatContext) async throws -> UIImage {
        print("📱 ImageGenerationService - Starting image generation for chat")
        
        // Verify context qualifies for image generation
        guard context.qualifiesForImageGeneration else {
            throw ImageGenerationError.invalidContext
        }
        
        do {
            // Generate tags from context
            let (positivePrompt, negativePrompt) = try await openAI.generateTags(for: context)
            print("📱 ImageGenerationService - Generated tags successfully")
            
            // Ensure models are loaded
            try await stableDiffusion.loadModels()
            
            // Generate image
            let image = try await stableDiffusion.generateImage(
                positivePrompt: positivePrompt,
                negativePrompt: negativePrompt
            )
            
            print("📱 ImageGenerationService - Generated image successfully")
            return image
            
        } catch {
            print("❌ ImageGenerationService - Error generating image: \(error)")
            
            // Map the error to our own error type
            switch error {
            case is StableDiffusionService.StableDiffusionError:
                throw ImageGenerationError.imageGenerationFailed(error.localizedDescription)
            default:
                throw ImageGenerationError.tagGenerationFailed(error.localizedDescription)
            }
        }
    }
    
    /// Generates tags for image generation based on chat context
    /// - Parameter context: The chat context to generate tags from
    /// - Returns: Tuple containing positive and negative prompts
    /// - Throws: ImageGenerationError if tag generation fails
    func generateTagsForContext(context: ChatContext) async throws -> (positive: String, negative: String) {
        print("📱 ImageGenerationService - Generating tags for context")
        
        do {
            let (positive, negative) = try await openAI.generateTags(for: context)
            print("📱 ImageGenerationService - Generated tags successfully")
            return (positive, negative)
        } catch {
            throw ImageGenerationError.tagGenerationFailed(error.localizedDescription)
        }
    }
} 