import Foundation

/// Represents different quality levels for video playback
enum VideoQuality: String, Codable, CaseIterable {
    /// Automatically determine quality based on network conditions
    case auto = "auto"
    
    /// 480p or lower
    case low = "low"
    
    /// 720p
    case medium = "medium"
    
    /// Original quality
    case high = "high"
    
    /// Maximum height in pixels for each quality level
    var maxHeight: Int? {
        switch self {
        case .auto:
            return nil
        case .low:
            return 480
        case .medium:
            return 720
        case .high:
            return nil
        }
    }
    
    /// Numeric value representing quality level (higher is better quality)
    var qualityLevel: Int {
        switch self {
        case .auto:
            return 0
        case .low:
            return 1
        case .medium:
            return 2
        case .high:
            return 3
        }
    }
    
    /// Returns true if this quality level is adaptive
    var isAdaptive: Bool {
        return self == .auto
    }
    
    /// Returns the next lower quality level, or nil if already at lowest
    var lowerQuality: VideoQuality? {
        switch self {
        case .high:
            return .medium
        case .medium:
            return .low
        case .low, .auto:
            return nil
        }
    }
    
    /// Returns the next higher quality level, or nil if already at highest
    var higherQuality: VideoQuality? {
        switch self {
        case .low:
            return .medium
        case .medium:
            return .high
        case .high, .auto:
            return nil
        }
    }
} 