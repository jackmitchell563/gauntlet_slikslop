import Foundation

/// Represents a unique key for cached video content with associated metadata
struct VideoCacheKey: Hashable, Codable {
    /// The unique identifier of the video
    let videoId: String
    
    /// The quality level of the cached video
    let quality: VideoQuality
    
    /// Date of last access to this cached content
    var lastAccessDate: Date
    
    /// Size of the cached content in bytes
    var size: Int
    
    /// String representation of the cache key
    var stringValue: String {
        return "\(videoId)_\(quality.rawValue)"
    }
    
    // MARK: - Initialization
    
    init(videoId: String, quality: VideoQuality, lastAccessDate: Date = Date(), size: Int = 0) {
        self.videoId = videoId
        self.quality = quality
        self.lastAccessDate = lastAccessDate
        self.size = size
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(stringValue)
    }
    
    static func == (lhs: VideoCacheKey, rhs: VideoCacheKey) -> Bool {
        return lhs.stringValue == rhs.stringValue
    }
} 