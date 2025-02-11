import Foundation

/// Protocol defining the interface for video caching operations
protocol VideoCacheProviding {
    /// Store video data with associated key
    /// - Parameters:
    ///   - data: The video data to store
    ///   - key: Unique identifier for the video data
    func store(_ data: Data, for key: String) async throws
    
    /// Retrieve video data for key
    /// - Parameter key: Unique identifier for the video data
    /// - Returns: The cached video data if available, nil otherwise
    func retrieve(for key: String) async throws -> Data?
    
    /// Remove video data for key
    /// - Parameter key: Unique identifier for the video data to remove
    func remove(for key: String) async throws
    
    /// Clear all cached data
    func clear() async throws
    
    /// Get total size of cache in bytes
    var totalCacheSize: Int64 { get async }
} 