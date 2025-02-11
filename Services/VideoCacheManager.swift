import Foundation

/// Manages cache size and cleanup operations for the video cache
final class VideoCacheManager {
    // MARK: - Properties
    
    private let cache: VideoCacheProviding
    private let maxSize: Int64
    private let cleanupThreshold: Double
    private let targetSizeAfterCleanup: Double
    private var metrics: CacheMetrics
    
    // MARK: - Initialization
    
    init(cache: VideoCacheProviding, maxSize: Int, cleanupThreshold: Double = 0.9, targetSizeAfterCleanup: Double = 0.7) {
        self.cache = cache
        self.maxSize = Int64(maxSize)
        self.cleanupThreshold = cleanupThreshold
        self.targetSizeAfterCleanup = targetSizeAfterCleanup
        self.metrics = CacheMetrics()
    }
    
    // MARK: - Cache Management
    
    /// Manages cache size, performing cleanup if necessary
    func manageCache() async throws {
        let currentSize = Int64(await cache.totalCacheSize)
        metrics.totalBytesStored = currentSize
        
        if Double(currentSize) / Double(maxSize) > cleanupThreshold {
            print("📦 VideoCacheManager - Cache size (\(currentSize) bytes) exceeded threshold, initiating cleanup")
            try await performCacheCleanup()
        }
    }
    
    /// Performs cache cleanup using LRU (Least Recently Used) eviction
    private func performCacheCleanup() async throws {
        let currentSize = Int64(await cache.totalCacheSize)
        let targetSize = Int64(Double(maxSize) * targetSizeAfterCleanup)
        let bytesToFree = currentSize - targetSize
        
        guard bytesToFree > 0 else { return }
        
        print("📦 VideoCacheManager - Attempting to free \(bytesToFree) bytes")
        
        // Get sorted entries from DiskVideoCache
        let sortedEntries = await getSortedCacheEntries()
        var freedSpace: Int64 = 0
        var evictedCount = 0
        
        for entry in sortedEntries {
            if freedSpace >= bytesToFree { break }
            
            do {
                try await cache.remove(for: entry.key)
                freedSpace += Int64(entry.value.size)
                evictedCount += 1
                print("📦 VideoCacheManager - Removed cache entry: \(entry.key)")
            } catch {
                print("❌ VideoCacheManager - Failed to remove cache entry: \(entry.key), error: \(error)")
            }
        }
        
        // Update metrics
        metrics.evictionCount += evictedCount
        print("📦 VideoCacheManager - Cleanup completed: Freed \(freedSpace) bytes, evicted \(evictedCount) items")
    }
    
    /// Gets cache entries sorted by last access date
    private func getSortedCacheEntries() async -> [(key: String, value: VideoCacheKey)] {
        // This would need to be implemented in DiskVideoCache to expose its entries
        // For now, we'll return an empty array
        return []
    }
    
    // MARK: - Metrics
    
    /// Get current cache metrics
    var currentMetrics: CacheMetrics {
        get async {
            metrics.totalBytesStored = Int64(await cache.totalCacheSize)
            return metrics
        }
    }
    
    /// Record a cache hit
    func recordCacheHit() {
        metrics.hits += 1
    }
    
    /// Record a cache miss
    func recordCacheMiss() {
        metrics.misses += 1
    }
    
    /// Record network bytes downloaded
    func recordBytesDownloaded(_ bytes: Int64) {
        metrics.networkBytesDownloaded += bytes
    }
    
    /// Record video load time
    func recordLoadTime(_ time: TimeInterval) {
        let currentCount = metrics.hits + metrics.misses
        metrics.averageLoadTime = ((metrics.averageLoadTime * Double(currentCount)) + time) / Double(currentCount + 1)
    }
}

// MARK: - Cache Metrics

/// Metrics for monitoring cache performance
struct CacheMetrics {
    var hits: Int = 0
    var misses: Int = 0
    var totalBytesStored: Int64 = 0
    var evictionCount: Int = 0
    var averageLoadTime: TimeInterval = 0
    var networkBytesDownloaded: Int64 = 0
    
    var hitRate: Double {
        let total = hits + misses
        guard total > 0 else { return 0 }
        return Double(hits) / Double(total)
    }
} 