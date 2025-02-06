import Foundation

/// Represents errors that can occur during database operations
enum DatabaseError: LocalizedError {
    case invalidData(String)
    case missingData(String)
    case parseError(String)
    case authError(String)
    case networkError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidData(let detail):
            return "Invalid data: \(detail)"
        case .missingData(let field):
            return "Missing required data: \(field)"
        case .parseError(let detail):
            return "Failed to parse data: \(detail)"
        case .authError(let detail):
            return "Authentication error: \(detail)"
        case .networkError(let detail):
            return "Network error: \(detail)"
        case .unknown(let detail):
            return "Unknown error: \(detail)"
        }
    }
} 