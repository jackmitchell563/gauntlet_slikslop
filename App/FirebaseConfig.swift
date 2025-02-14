import Firebase
import FirebaseFirestore
import FirebaseStorage
import FirebaseFunctions
import FirebaseAuth

/// Manages Firebase configuration and provides access to Firebase services
class FirebaseConfig {
    /// Shared instance for singleton access
    static let shared = FirebaseConfig()
    
    private init() {
        print("🔥 FirebaseConfig - Initializing Firebase")
        FirebaseApp.configure()
        print("✅ FirebaseConfig - Firebase configured successfully")
    }
    
    /// Returns the Firestore database instance
    static func getFirestoreInstance() -> Firestore {
        return Firestore.firestore()
    }
    
    /// Returns the Storage instance
    static func getStorageInstance() -> Storage {
        return Storage.storage()
    }
    
    /// Returns the Functions instance
    static func getFunctionsInstance() -> Functions {
        return Functions.functions()
    }
    
    /// Returns the Auth instance
    static func getAuthInstance() -> Auth {
        return Auth.auth()
    }
} 