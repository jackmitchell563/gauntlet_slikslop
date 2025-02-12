import UIKit

/// Service for managing character gallery images and operations
class CharacterGalleryService {
    // MARK: - Properties
    
    /// Shared instance for singleton access
    static let shared = CharacterGalleryService()
    
    /// Service for handling image generation and storage
    private let stableDiffusion = StableDiffusionService.shared
    
    /// In-memory cache for loaded images
    private var imageCache: [String: UIImage] = [:]
    private let cacheQueue = DispatchQueue(label: "com.slikslop.gallerycache")
    
    // MARK: - Types
    
    /// Represents an image in the gallery
    struct GalleryImage {
        let url: URL
        let image: UIImage
        let timestamp: Date
        
        init(url: URL, image: UIImage) {
            self.url = url
            self.image = image
            // Extract timestamp from filename if possible, otherwise use current date
            if let filename = url.lastPathComponent.components(separatedBy: ".").first,
               let timestamp = Double(filename) {
                self.timestamp = Date(timeIntervalSince1970: timestamp)
            } else {
                self.timestamp = Date()
            }
        }
    }
    
    /// Errors that can occur during gallery operations
    enum GalleryError: LocalizedError {
        case imageLoadFailed
        case invalidImage
        case storageError(String)
        
        var errorDescription: String? {
            switch self {
            case .imageLoadFailed:
                return "Failed to load image"
            case .invalidImage:
                return "Invalid image data"
            case .storageError(let message):
                return "Storage error: \(message)"
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Gets all images for a character
    /// - Parameter character: The character to get images for
    /// - Returns: Array of gallery images, sorted by timestamp (newest first)
    func getImages(for character: GameCharacter) async throws -> [GalleryImage] {
        print("📱 CharacterGalleryService - Getting images for character: \(character.name)")
        
        let urls = try stableDiffusion.getImagesForCharacter(character)
        return try await urls.asyncMap { url in
            if let cachedImage = getCachedImage(for: url) {
                return GalleryImage(url: url, image: cachedImage)
            }
            
            guard let image = await loadImage(from: url) else {
                throw GalleryError.imageLoadFailed
            }
            
            cacheImage(image, for: url)
            return GalleryImage(url: url, image: image)
        }.sorted { $0.timestamp > $1.timestamp }
    }
    
    /// Gets the number of images for a character
    /// - Parameter character: The character to count images for
    /// - Returns: Number of images in the gallery
    func getImageCount(for character: GameCharacter) throws -> Int {
        print("📱 CharacterGalleryService - Getting image count for character: \(character.name)")
        let urls = try stableDiffusion.getImagesForCharacter(character)
        return urls.count
    }
    
    /// Loads an image from a URL
    /// - Parameter url: The URL of the image to load
    /// - Returns: The loaded image, if successful
    func loadImage(from url: URL) async -> UIImage? {
        print("📱 CharacterGalleryService - Loading image from: \(url.lastPathComponent)")
        
        // Check cache first
        if let cachedImage = getCachedImage(for: url) {
            return cachedImage
        }
        
        // Load from disk
        guard let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        
        // Cache the loaded image
        cacheImage(image, for: url)
        return image
    }
    
    /// Clears the image cache
    func clearCache() {
        print("📱 CharacterGalleryService - Clearing image cache")
        cacheQueue.async {
            self.imageCache.removeAll()
        }
    }
    
    /// Deletes an image from the gallery
    /// - Parameters:
    ///   - url: The URL of the image to delete
    ///   - character: The character the image belongs to
    /// - Throws: GalleryError if deletion fails
    func deleteImage(at url: URL, for character: GameCharacter) throws {
        print("📱 CharacterGalleryService - Deleting image: \(url.lastPathComponent)")
        
        do {
            // Remove from disk
            try FileManager.default.removeItem(at: url)
            
            // Remove from cache
            cacheQueue.async {
                self.imageCache.removeValue(forKey: url.path)
            }
            
            print("📱 CharacterGalleryService - Successfully deleted image")
        } catch {
            print("❌ CharacterGalleryService - Failed to delete image: \(error)")
            throw GalleryError.storageError("Failed to delete image: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    /// Gets a cached image for a URL
    /// - Parameter url: The URL of the image
    /// - Returns: The cached image, if it exists
    private func getCachedImage(for url: URL) -> UIImage? {
        cacheQueue.sync {
            return imageCache[url.path]
        }
    }
    
    /// Caches an image for a URL
    /// - Parameters:
    ///   - image: The image to cache
    ///   - url: The URL of the image
    private func cacheImage(_ image: UIImage, for url: URL) {
        cacheQueue.async {
            self.imageCache[url.path] = image
        }
    }
}

// MARK: - Array Extensions

extension Array {
    /// Maps array elements asynchronously
    func asyncMap<T>(_ transform: (Element) async throws -> T) async throws -> [T] {
        var results = [T]()
        for element in self {
            try await results.append(transform(element))
        }
        return results
    }
} 