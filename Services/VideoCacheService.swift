import Foundation
import AVFoundation

/// Service responsible for managing video caching operations
final class VideoCacheService {
    // MARK: - Singleton
    
    static let shared = VideoCacheService()
    
    // MARK: - Configuration
    
    struct Configuration {
        let maxCacheSize: Int64
        let cachePath: String
        let supportedQualities: [VideoQuality]
        let prefetchLimit: Int
        let cleanupThreshold: Double
        
        static func defaultConfiguration() -> Configuration {
            return Configuration(
                maxCacheSize: 1024 * 1024 * 1024, // 1GB
                cachePath: NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0] + "/VideoCache",
                supportedQualities: [.low, .medium, .high],
                prefetchLimit: 3,
                cleanupThreshold: 0.9
            )
        }
    }
    
    // MARK: - Properties
    
    private let cache: VideoCacheProviding
    private let config: Configuration
    private var prefetchOperations: [String: Task<Void, Error>] = [:]
    private let cacheManager: VideoCacheManager
    
    // MARK: - Initialization
    
    private init() {
        self.config = Configuration.defaultConfiguration()
        let cacheURL = URL(fileURLWithPath: config.cachePath)
        do {
            self.cache = try DiskVideoCache(directory: cacheURL)
            self.cacheManager = VideoCacheManager(
                cache: cache,
                maxSize: Int(config.maxCacheSize),  // Convert Int64 to Int for backward compatibility
                cleanupThreshold: config.cleanupThreshold
            )
            setupNetworkHandling()
        } catch {
            fatalError("Failed to initialize video cache: \(error)")
        }
    }
    
    // MARK: - Network Handling
    
    private func setupNetworkHandling() {
        NetworkMonitor.shared.addHandler { [weak self] in
            self?.handleNetworkConditionChange()
        }
    }
    
    private func handleNetworkConditionChange() {
        // Cancel prefetch operations on poor network conditions
        let condition = NetworkMonitor.shared.currentCondition
        if case .poor = condition, !prefetchOperations.isEmpty {
            print("📱 VideoCacheService - Cancelling prefetch operations due to poor network")
            cancelAllPrefetchOperations()
        }
    }
    
    // MARK: - Quality Selection
    
    /// Determines optimal video quality based on network conditions
    func determineOptimalQuality(for networkCondition: NetworkCondition) -> VideoQuality {
        switch networkCondition {
        case .wifi(let speed) where speed > 10_000_000:  // 10 Mbps
            return .high
        case .wifi:
            return .medium
        case .cellular(let speed) where speed > 5_000_000:  // 5 Mbps
            return .medium
        case .cellular:
            return .low
        case .poor, .none:
            return .low
        }
    }
    
    // MARK: - Prefetching
    
    /// Prefetches videos for smooth playback
    /// - Parameter metadata: Array of video metadata to prefetch
    func prefetchVideos(for metadata: [VideoMetadata]) async {
        print("📱 VideoCacheService - Starting prefetch for \(metadata.count) videos")
        
        let networkCondition = NetworkMonitor.shared.currentCondition
        let quality = determineOptimalQuality(for: networkCondition)
        
        // Skip prefetching on poor network conditions
        guard networkCondition != .poor && networkCondition != .none else {
            print("📱 VideoCacheService - Skipping prefetch due to poor network conditions")
            return
        }
        
        // Limit concurrent prefetch operations
        let limitedMetadata = Array(metadata.prefix(config.prefetchLimit))
        
        for metadata in limitedMetadata {
            let key = VideoCacheKey(videoId: metadata.id, quality: quality)
            
            // Skip if already cached or being prefetched
            do {
                if let _ = try await cache.retrieve(for: key.stringValue) {
                    // Video is already cached, skip it
                    continue
                }
                
                // Skip if already being prefetched
                if prefetchOperations[key.stringValue] != nil {
                    continue
                }
                
                prefetchOperations[key.stringValue] = Task {
                    do {
                        print("📱 VideoCacheService - Prefetching video: \(metadata.id)")
                        let (data, _) = try await URLSession.shared.data(from: URL(string: metadata.url)!)
                        try await storeVideo(data, for: key)
                        print("✅ VideoCacheService - Successfully prefetched video: \(metadata.id)")
                    } catch {
                        print("❌ VideoCacheService - Failed to prefetch video: \(metadata.id), error: \(error)")
                    }
                    prefetchOperations.removeValue(forKey: key.stringValue)
                }
            } catch {
                print("❌ VideoCacheService - Error checking cache for video: \(metadata.id), error: \(error)")
                continue
            }
        }
    }
    
    /// Cancels all ongoing prefetch operations
    private func cancelAllPrefetchOperations() {
        prefetchOperations.values.forEach { $0.cancel() }
        prefetchOperations.removeAll()
    }
    
    // MARK: - Cache Operations
    
    /// Store video data in cache
    /// - Parameters:
    ///   - data: The video data to cache
    ///   - key: The cache key for the video
    func storeVideo(_ data: Data, for key: VideoCacheKey) async throws {
        let startTime = Date()
        try await cache.store(data, for: key.stringValue)
        cacheManager.recordBytesDownloaded(Int64(data.count))
        cacheManager.recordLoadTime(Date().timeIntervalSince(startTime))
        
        // Trigger cache cleanup if needed
        try await cacheManager.manageCache()
    }
    
    /// Retrieve video data from cache
    /// - Parameter key: The cache key for the video
    /// - Returns: The cached video data if available
    func retrieveVideo(for key: VideoCacheKey) async throws -> Data? {
        let startTime = Date()
        if let data = try await cache.retrieve(for: key.stringValue) {
            cacheManager.recordCacheHit()
            cacheManager.recordLoadTime(Date().timeIntervalSince(startTime))
            return data
        }
        cacheManager.recordCacheMiss()
        return nil
    }
    
    /// Download and cache video from URL
    /// - Parameters:
    ///   - url: The URL to download the video from
    ///   - key: The cache key for the video
    /// - Returns: An AVPlayerItem configured with the downloaded video
    func downloadAndCacheVideo(from url: URL, for key: VideoCacheKey) async throws -> AVPlayerItem {
        let startTime = Date()
        
        // First check if we already have it cached
        if let cachedData = try await retrieveVideo(for: key) {
            print("📹 VideoCacheService - Using cached video for key: \(key.stringValue)")
            let playerItem = try await createPlayerItem(from: cachedData, originalURL: url)
            cacheManager.recordLoadTime(Date().timeIntervalSince(startTime))
            return playerItem
        }
        
        // If not cached, download and cache
        print("📹 VideoCacheService - Downloading video from URL: \(url)")
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "VideoCacheService",
                         code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
        }
        
        // Create player item first to validate the data is playable
        let playerItem = try await createPlayerItem(from: data, originalURL: url)
        
        // If we got here, the data is valid, so store it in cache
        print("📹 VideoCacheService - Storing video in cache for key: \(key.stringValue)")
        try await storeVideo(data, for: key)
        
        // Record metrics
        cacheManager.recordBytesDownloaded(Int64(data.count))
        cacheManager.recordLoadTime(Date().timeIntervalSince(startTime))
        
        return playerItem
    }
    
    /// Creates an AVPlayerItem from data while preserving the original URL
    /// - Parameters:
    ///   - data: The video data
    ///   - originalURL: The original URL of the video
    /// - Returns: Configured AVPlayerItem
    private func createPlayerItem(from data: Data, originalURL: URL) async throws -> AVPlayerItem {
        print("📹 VideoCacheService - Creating player item")
        
        // Create a temporary file with the correct extension from the original URL
        let fileExtension = originalURL.pathExtension.isEmpty ? "mp4" : originalURL.pathExtension
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        
        // Write the data to the temporary file
        try data.write(to: tempURL)
        
        // Create asset with original URL for better identification
        let asset = AVURLAsset(url: tempURL)
        
        // Wait for the asset to become playable
        print("📹 VideoCacheService - Validating asset playability")
        try await asset.load(.isPlayable)
        guard asset.isPlayable else {
            print("❌ VideoCacheService - Asset is not playable")
            throw NSError(domain: "VideoCacheService",
                         code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Asset is not playable"])
        }
        
        print("✅ VideoCacheService - Asset is playable")
        return AVPlayerItem(asset: asset)
    }
    
    /// Clear all cached videos
    func clearCache() async throws {
        try await cache.clear()
    }
    
    /// Get the total size of cached videos
    var totalCacheSize: Int64 {
        get async {
            return await cache.totalCacheSize
        }
    }
    
    /// Get current cache metrics
    var metrics: CacheMetrics {
        get async {
            return await cacheManager.currentMetrics
        }
    }
    
    deinit {
        NetworkMonitor.shared.removeAllHandlers()
        cancelAllPrefetchOperations()
    }
} 