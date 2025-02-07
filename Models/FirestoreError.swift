import Foundation

/// Custom error type for Firestore operations
enum FirestoreError: LocalizedError {
    case invalidDocument
    case invalidData(String)
    case documentNotFound
    case permissionDenied
    case networkError
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidDocument:
            return "Invalid or empty document"
        case .invalidData(let field):
            return "Invalid data for field: \(field)"
        case .documentNotFound:
            return "Document not found"
        case .permissionDenied:
            return "Permission denied"
        case .networkError:
            return "Network error occurred"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
} 