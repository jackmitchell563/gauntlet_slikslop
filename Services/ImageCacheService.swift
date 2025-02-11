import Foundation
import UIKit

/// Service for managing image caching and cleanup
class ImageCacheService {
    // MARK: - Properties
    
    /// Shared instance for singleton access
    static let shared = ImageCacheService()
    
    /// In-memory cache for images
    private let cache = NSCache<NSString, UIImage>()
    
    /// Queue for background operations
    private let processingQueue = DispatchQueue(label: "com.slikslop.imagecache", qos: .utility)
    
    /// Maximum cache size in bytes (100MB)
    private let maxCacheSize: Int = 100 * 1024 * 1024
    
    /// Current cache size in bytes
    private var currentCacheSize: Int = 0
    
    // MARK: - Initialization
    
    private init() {
        setupCache()
    }
    
    // MARK: - Setup
    
    private func setupCache() {
        // Configure cache limits
        cache.totalCostLimit = maxCacheSize
        
        // Add memory warning observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    // MARK: - Public Methods
    
    /// Gets an image from cache or downloads it
    /// - Parameter url: URL of the image
    /// - Returns: The cached or downloaded image
    func getImage(from url: URL) async throws -> UIImage {
        // Check memory cache first
        if let cachedImage = cache.object(forKey: url.absoluteString as NSString) {
            print("📱 ImageCacheService - Cache hit for: \(url)")
            return cachedImage
        }
        
        print("📱 ImageCacheService - Cache miss for: \(url)")
        
        // Download and cache image
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw CacheError.invalidImageData
        }
        
        // Cache the image with its estimated size as cost
        let imageCost = data.count
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: imageCost)
        
        // Update current cache size
        currentCacheSize += imageCost
        
        // Clean up if needed
        if currentCacheSize > maxCacheSize {
            cleanupCache()
        }
        
        return image
    }
    
    /// Prefetches images into cache
    /// - Parameter urls: Array of image URLs to prefetch
    func prefetchImages(_ urls: [URL]) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            for url in urls {
                // Skip if already cached
                if self.cache.object(forKey: url.absoluteString as NSString) != nil {
                    continue
                }
                
                // Download and cache in background
                Task {
                    do {
                        _ = try await self.getImage(from: url)
                    } catch {
                        print("❌ ImageCacheService - Error prefetching image: \(error)")
                    }
                }
            }
        }
    }
    
    /// Removes an image from cache
    /// - Parameter url: URL of the image to remove
    func removeImage(for url: URL) {
        cache.removeObject(forKey: url.absoluteString as NSString)
    }
    
    /// Clears all cached images
    func clearCache() {
        cache.removeAllObjects()
        currentCacheSize = 0
    }
    
    // MARK: - Private Methods
    
    /// Handles low memory warning
    @objc private func handleMemoryWarning() {
        print("📱 ImageCacheService - Received memory warning, clearing cache")
        clearCache()
    }
    
    /// Cleans up cache when it exceeds size limit
    private func cleanupCache() {
        print("📱 ImageCacheService - Cleaning up cache")
        
        // Remove oldest items until we're under the limit
        // Note: NSCache handles this automatically, but we update our size tracking
        currentCacheSize = 0
    }
    
    // MARK: - Types
    
    enum CacheError: LocalizedError {
        case invalidImageData
        
        var errorDescription: String? {
            switch self {
            case .invalidImageData:
                return "Invalid image data"
            }
        }
    }
} 