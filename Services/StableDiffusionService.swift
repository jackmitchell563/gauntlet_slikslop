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
        case audioStorageError(String)
        case audioMigrationFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .storageError(let message):
                return "Storage error: \(message)"
            case .imageGenerationFailed(let message):
                return "Image generation failed: \(message)"
            case .modelDirectoryCreationFailed:
                return "Failed to create storage directory"
            case .audioStorageError(let message):
                return "Audio storage error: \(message)"
            case .audioMigrationFailed(let message):
                return "Audio migration failed: \(message)"
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
    ///   - character: The character to generate the image for
    /// - Returns: The generated image
    /// - Throws: StableDiffusionError if generation fails
    func generateImage(positivePrompt: String, negativePrompt: String, character: GameCharacter) async throws -> UIImage {
        print("📱 StableDiffusionService - Generating image")
        print("📱 Positive prompt: \(positivePrompt)")
        print("📱 Negative prompt: \(negativePrompt)")
        
        do {
            // Generate image using Replicate
            let image = try await replicate.generateImage(prompt: positivePrompt, character: character)
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
    /// - Parameter character: Optional character to get specific directory for
    /// - Returns: URL of the storage directory
    /// - Throws: StableDiffusionError if directory creation fails
    private func getImageStorageURL(for character: GameCharacter? = nil) throws -> URL {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw StableDiffusionError.modelDirectoryCreationFailed
        }
        
        var imageDirectory = documentsDirectory.appendingPathComponent("GeneratedImages", isDirectory: true)
        
        if let character = character {
            imageDirectory = imageDirectory.appendingPathComponent(character.id, isDirectory: true)
        }
        
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
    ///   - character: The character the image was generated for
    /// - Returns: The local URL where the image is stored
    /// - Throws: StableDiffusionError if save fails
    func saveImageLocally(_ image: UIImage, messageId: String, character: GameCharacter? = nil) throws -> URL {
        let imageDirectory = try getImageStorageURL(for: character)
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
    /// - Parameters:
    ///   - messageId: The ID of the message associated with the image
    ///   - character: Optional character to load from specific directory
    /// - Returns: The loaded image, if it exists
    /// - Throws: StableDiffusionError if load fails
    func loadImageFromStorage(messageId: String, character: GameCharacter? = nil) throws -> UIImage? {
        let imageDirectory = try getImageStorageURL(for: character)
        let imageURL = imageDirectory.appendingPathComponent("\(messageId).jpg")
        
        guard FileManager.default.fileExists(atPath: imageURL.path),
              let imageData = try? Data(contentsOf: imageURL),
              let image = UIImage(data: imageData) else {
            return nil
        }
        
        return image
    }
    
    /// Gets all images for a specific character
    /// - Parameter character: The character to get images for
    /// - Returns: Array of image URLs
    /// - Throws: StableDiffusionError if directory access fails
    func getImagesForCharacter(_ character: GameCharacter) throws -> [URL] {
        let directory = try getImageStorageURL(for: character)
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        return fileURLs.filter { $0.pathExtension == "jpg" }
    }
    
    /// Migrates existing images to character-specific folders
    /// - Parameter messages: Array of chat messages containing image references
    /// - Throws: StableDiffusionError if migration fails
    func migrateExistingImages(messages: [ChatMessage]) throws {
        let oldDirectory = try getImageStorageURL()
        let fileManager = FileManager.default
        
        for message in messages {
            // Skip non-image messages
            guard message.type == .textWithImage || message.type == .image,
                  let character = message.character else {
                continue
            }
            
            let oldImageURL = oldDirectory.appendingPathComponent("\(message.id).jpg")
            let newImageURL = try getImageStorageURL(for: character)
                .appendingPathComponent("\(message.id).jpg")
            
            // Skip if image doesn't exist or is already migrated
            guard fileManager.fileExists(atPath: oldImageURL.path),
                  !fileManager.fileExists(atPath: newImageURL.path) else {
                continue
            }
            
            do {
                try fileManager.moveItem(at: oldImageURL, to: newImageURL)
                print("📱 StableDiffusionService - Migrated image: \(message.id) to character folder: \(character.id)")
            } catch {
                print("❌ StableDiffusionService - Failed to migrate image: \(message.id): \(error)")
                // Continue with other images even if one fails
                continue
            }
        }
    }
    
    // MARK: - Audio Storage
    
    /// Gets the URL for the local audio storage directory
    /// - Parameter character: Optional character to get specific directory for
    /// - Returns: URL of the audio storage directory
    /// - Throws: StableDiffusionError if directory creation fails
    func getAudioStorageURL(for character: GameCharacter? = nil) throws -> URL {
        print("📱 StableDiffusionService - Getting audio storage URL for character: \(character?.name ?? "general")")
        
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ StableDiffusionService - Failed to access documents directory")
            throw StableDiffusionError.modelDirectoryCreationFailed
        }
        
        var audioDirectory = documentsDirectory.appendingPathComponent("GeneratedAudio", isDirectory: true)
        
        if let character = character {
            audioDirectory = audioDirectory.appendingPathComponent(character.id, isDirectory: true)
        }
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: audioDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
                print("📱 StableDiffusionService - Created audio directory: \(audioDirectory.path)")
            } catch {
                print("❌ StableDiffusionService - Failed to create audio directory: \(error)")
                throw StableDiffusionError.modelDirectoryCreationFailed
            }
        }
        
        return audioDirectory
    }
    
    /// Gets all audio files for a specific character
    /// - Parameter character: The character to get audio for
    /// - Returns: Array of audio URLs
    /// - Throws: StableDiffusionError if directory access fails
    func getAudioFilesForCharacter(_ character: GameCharacter) throws -> [URL] {
        print("📱 StableDiffusionService - Getting audio files for character: \(character.name)")
        
        let directory = try getAudioStorageURL(for: character)
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        let audioFiles = fileURLs.filter { $0.pathExtension == "mp3" }
        print("📱 StableDiffusionService - Found \(audioFiles.count) audio files")
        return audioFiles
    }
    
    /// Migrates existing audio files to character-specific folders
    /// - Parameter messages: Array of chat messages containing audio references
    /// - Returns: Number of files migrated
    /// - Throws: StableDiffusionError if migration fails
    func migrateExistingAudio(messages: [ChatMessage]) throws -> Int {
        print("📱 StableDiffusionService - Starting audio migration")
        
        let oldDirectory = try getAudioStorageURL()
        let fileManager = FileManager.default
        var migratedCount = 0
        
        for message in messages {
            // Skip non-character messages
            guard message.sender == .character,
                  let character = message.character else {
                continue
            }
            
            let oldAudioURL = oldDirectory.appendingPathComponent("\(message.id).mp3")
            let newAudioURL = try getAudioStorageURL(for: character)
                .appendingPathComponent("\(message.id).mp3")
            
            // Skip if audio doesn't exist or is already migrated
            guard fileManager.fileExists(atPath: oldAudioURL.path),
                  !fileManager.fileExists(atPath: newAudioURL.path) else {
                continue
            }
            
            do {
                try fileManager.moveItem(at: oldAudioURL, to: newAudioURL)
                print("📱 StableDiffusionService - Migrated audio: \(message.id) to character folder: \(character.id)")
                migratedCount += 1
            } catch {
                print("❌ StableDiffusionService - Failed to migrate audio: \(message.id): \(error)")
                // Continue with other files even if one fails
                continue
            }
        }
        
        print("📱 StableDiffusionService - Successfully migrated \(migratedCount) audio files")
        return migratedCount
    }
    
    /// Deletes an audio file
    /// - Parameters:
    ///   - messageId: The ID of the message associated with the audio
    ///   - character: The character the audio belongs to
    /// - Throws: StableDiffusionError if deletion fails
    func deleteAudioFile(messageId: String, character: GameCharacter) throws {
        print("📱 StableDiffusionService - Deleting audio for message: \(messageId)")
        
        let audioURL = try getAudioStorageURL(for: character)
            .appendingPathComponent("\(messageId).mp3")
        
        if FileManager.default.fileExists(atPath: audioURL.path) {
            do {
                try FileManager.default.removeItem(at: audioURL)
                print("📱 StableDiffusionService - Successfully deleted audio file")
            } catch {
                print("❌ StableDiffusionService - Failed to delete audio file: \(error)")
                throw StableDiffusionError.storageError("Failed to delete audio file: \(error.localizedDescription)")
            }
        }
    }
    
    /// Cleans up orphaned audio files
    /// - Parameter messages: Current valid messages to check against
    /// - Returns: Number of files cleaned up
    /// - Throws: StableDiffusionError if cleanup fails
    func cleanupOrphanedAudio(messages: [ChatMessage]) throws -> Int {
        print("📱 StableDiffusionService - Starting orphaned audio cleanup")
        
        let validMessageIds = Set(messages.map { $0.id })
        var cleanedCount = 0
        
        // Get all character folders
        let baseDirectory = try getAudioStorageURL()
        let characterFolders = try FileManager.default.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.hasDirectoryPath }
        
        // Check each character folder
        for folder in characterFolders {
            let audioFiles = try FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "mp3" }
            
            for audioFile in audioFiles {
                let messageId = audioFile.deletingPathExtension().lastPathComponent
                if !validMessageIds.contains(messageId) {
                    try FileManager.default.removeItem(at: audioFile)
                    cleanedCount += 1
                    print("📱 StableDiffusionService - Cleaned up orphaned audio: \(messageId)")
                }
            }
        }
        
        print("📱 StableDiffusionService - Cleaned up \(cleanedCount) orphaned audio files")
        return cleanedCount
    }
} 