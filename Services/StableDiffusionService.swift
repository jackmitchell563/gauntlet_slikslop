import Foundation
import UIKit

/// Service for handling image generation and storage
class StableDiffusionService {
    // MARK: - Properties
    
    /// Shared instance for singleton access
    static let shared = StableDiffusionService()
    
    /// Service for handling Replicate API calls
    private let replicate = ReplicateService.shared
    
    // MARK: - Types
    
    /// Errors that can occur during image generation and storage
    enum StableDiffusionError: LocalizedError {
        case storageError(String)
        case imageGenerationFailed(String)
        case modelDirectoryCreationFailed
        
        var errorDescription: String? {
            switch self {
            case .storageError(let message):
                return "Storage error: \(message)"
            case .imageGenerationFailed(let message):
                return "Image generation failed: \(message)"
            case .modelDirectoryCreationFailed:
                return "Failed to create storage directory"
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// No-op function to maintain compatibility with existing code
    /// Since we're using Replicate API, no local models need to be loaded
    /// - Throws: Never throws, but marked as throwing for compatibility
    func loadModels() async throws {
        print("📱 StableDiffusionService - loadModels called (no-op with Replicate API)")
        // No-op implementation since we don't need to load local models anymore
    }
    
    /// No-op function to maintain compatibility with existing code
    /// Since we're using Replicate API, no local models need to be downloaded
    /// - Parameter progress: Progress callback (immediately called with 1.0)
    /// - Throws: Never throws, but marked as throwing for compatibility
    func downloadModelFilesIfNeeded(progress: ((Double) -> Void)? = nil) async throws {
        print("📱 StableDiffusionService - downloadModelFilesIfNeeded called (no-op with Replicate API)")
        progress?(1.0) // Indicate immediate completion
    }
    
    /// No-op function to maintain compatibility with existing code
    /// Since we're using Replicate API, always returns true
    /// - Returns: Always returns true since no local models are needed
    func areModelFilesAvailable() -> Bool {
        print("📱 StableDiffusionService - areModelFilesAvailable called (no-op with Replicate API)")
        return true // Always return true since we don't need local models
    }
    
    /// Generates an image using Replicate API
    /// - Parameters:
    ///   - positivePrompt: What to include in the image
    ///   - negativePrompt: What to exclude from the image
    /// - Returns: The generated image
    /// - Throws: StableDiffusionError if generation fails
    func generateImage(positivePrompt: String, negativePrompt: String) async throws -> UIImage {
        print("📱 StableDiffusionService - Generating image")
        print("📱 Positive prompt: \(positivePrompt)")
        print("📱 Negative prompt: \(negativePrompt)")
        
        do {
            // Generate image using Replicate
            let image = try await replicate.generateImage(prompt: "[(white background:1.5)::5], isometric OR hexagon , 1 girl, mid shot, full body, " + positivePrompt)
            print("📱 StableDiffusionService - Image generated successfully")
            return image
            
        } catch let error as ReplicateService.ReplicateError {
            print("❌ StableDiffusionService - Error generating image: \(error)")
            throw StableDiffusionError.imageGenerationFailed(error.localizedDescription)
        } catch {
            print("❌ StableDiffusionService - Unexpected error: \(error)")
            throw StableDiffusionError.imageGenerationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Image Storage
    
    /// Gets the URL for the local image storage directory
    /// - Returns: URL of the storage directory
    /// - Throws: StableDiffusionError if directory creation fails
    private func getImageStorageURL() throws -> URL {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw StableDiffusionError.modelDirectoryCreationFailed
        }
        
        let imageDirectory = documentsDirectory.appendingPathComponent("GeneratedImages", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: imageDirectory.path) {
            try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        }
        
        return imageDirectory
    }
    
    /// Saves an image to local storage
    /// - Parameters:
    ///   - image: The image to save
    ///   - messageId: The ID of the associated message
    /// - Returns: The local URL where the image is stored
    /// - Throws: StableDiffusionError if save fails
    func saveImageLocally(_ image: UIImage, messageId: String) throws -> URL {
        let imageDirectory = try getImageStorageURL()
        let imageURL = imageDirectory.appendingPathComponent("\(messageId).jpg")
        
        // Convert image to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw StableDiffusionError.storageError("Failed to convert image to JPEG")
        }
        
        // Save to disk
        try imageData.write(to: imageURL)
        print("📱 StableDiffusionService - Saved image to: \(imageURL.path)")
        
        return imageURL
    }
    
    /// Loads an image from local storage
    /// - Parameter messageId: The ID of the message associated with the image
    /// - Returns: The loaded image, if it exists
    /// - Throws: StableDiffusionError if load fails
    func loadImageFromStorage(messageId: String) throws -> UIImage? {
        let imageDirectory = try getImageStorageURL()
        let imageURL = imageDirectory.appendingPathComponent("\(messageId).jpg")
        
        guard FileManager.default.fileExists(atPath: imageURL.path),
              let imageData = try? Data(contentsOf: imageURL),
              let image = UIImage(data: imageData) else {
            return nil
        }
        
        return image
    }
} 