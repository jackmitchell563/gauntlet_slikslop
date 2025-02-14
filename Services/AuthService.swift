import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Service class for handling authentication operations
class AuthService {
    // MARK: - Properties
    
    static let shared = AuthService()
    private let auth = FirebaseConfig.getAuthInstance()
    private let db = FirebaseConfig.getFirestoreInstance()
    
    /// The current user's ID, if logged in
    var currentUserId: String? {
        return auth.currentUser?.uid
    }
    
    /// Whether a user is currently logged in
    var isAuthenticated: Bool {
        return auth.currentUser != nil
    }
    
    private init() {}
    
    // MARK: - Auth State
    
    /// Adds a listener for authentication state changes
    /// - Parameter callback: Closure to handle state changes
    /// - Returns: Handle for the auth state listener
    @discardableResult
    func handleAuthStateChanges(callback: @escaping (User?) -> Void) -> AuthStateDidChangeListenerHandle {
        return auth.addStateDidChangeListener { _, user in
            callback(user)
        }
    }
    
    /// Removes an auth state listener
    /// - Parameter handle: The handle for the listener to remove
    func removeAuthStateListener(_ handle: AuthStateDidChangeListenerHandle) {
        auth.removeStateDidChangeListener(handle)
    }
    
    // MARK: - Sign In/Out
    
    /// Signs in with Google
    /// - Returns: AuthDataResult containing the signed-in user
    func signInWithGoogle() async throws -> AuthDataResult {
        // Note: This is a placeholder. Actual Google Sign-In implementation
        // requires GoogleSignIn SDK setup and configuration
        throw AuthError.notImplemented
    }
    
    /// Signs up a new user with email and password
    /// - Parameters:
    ///   - email: The user's email address
    ///   - password: The user's chosen password
    /// - Returns: AuthDataResult containing the signed-up user
    func signUp(email: String, password: String) async throws -> AuthDataResult {
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            // Create user profile after successful sign up
            try await createUserProfile(user: result.user)
            return result
        } catch let error as NSError {
            switch error.code {
            case AuthErrorCode.invalidEmail.rawValue:
                throw AuthError.invalidEmail
            case AuthErrorCode.emailAlreadyInUse.rawValue:
                throw AuthError.emailInUse
            case AuthErrorCode.weakPassword.rawValue:
                throw AuthError.weakPassword
            default:
                throw error
            }
        }
    }
    
    /// Signs in an existing user with email and password
    /// - Parameters:
    ///   - email: The user's email address
    ///   - password: The user's password
    /// - Returns: AuthDataResult containing the signed-in user
    func signIn(email: String, password: String) async throws -> AuthDataResult {
        do {
            return try await auth.signIn(withEmail: email, password: password)
        } catch let error as NSError {
            switch error.code {
            case AuthErrorCode.invalidEmail.rawValue:
                throw AuthError.invalidEmail
            case AuthErrorCode.wrongPassword.rawValue:
                throw AuthError.wrongPassword
            case AuthErrorCode.userNotFound.rawValue:
                throw AuthError.userNotFound
            default:
                throw error
            }
        }
    }
    
    /// Sends a password reset email to the specified email address
    /// - Parameter email: The email address to send the reset link to
    func resetPassword(email: String) async throws {
        do {
            try await auth.sendPasswordReset(withEmail: email)
        } catch let error as NSError {
            switch error.code {
            case AuthErrorCode.invalidEmail.rawValue:
                throw AuthError.invalidEmail
            case AuthErrorCode.userNotFound.rawValue:
                throw AuthError.userNotFound
            default:
                throw error
            }
        }
    }
    
    /// Signs out the current user
    func signOut() throws {
        try auth.signOut()
    }
    
    // MARK: - Profile Management
    
    /// Creates a new user profile in Firestore after authentication
    /// - Parameters:
    ///   - user: The authenticated Firebase user
    ///   - additionalData: Additional profile information
    func createUserProfile(user: User, additionalData: [String: Any] = [:]) async throws {
        let profile = UserProfile(
            id: user.uid,
            email: user.email,
            displayName: user.displayName ?? "User",
            photoURL: user.photoURL?.absoluteString,
            bio: "",
            createdAt: Timestamp(date: Date()),
            preferences: nil,
            followerCount: 0,
            followingCount: 0,
            totalLikes: 0
        )
        
        try await db.collection("users").document(user.uid).setData(
            profile.asDictionary().merging(additionalData) { current, _ in current }
        )
    }
}

// MARK: - Errors

enum AuthError: Error {
    case notImplemented
    case presentationError
    case invalidCredential
    case userNotFound
    case profileCreationFailed
    case notInitialized
    case weakPassword
    case invalidEmail
    case emailInUse
    case wrongPassword
    
    var localizedDescription: String {
        switch self {
        case .notImplemented:
            return "This feature is not implemented yet"
        case .presentationError:
            return "Could not present the sign-in interface"
        case .invalidCredential:
            return "Invalid credentials provided"
        case .userNotFound:
            return "User not found"
        case .profileCreationFailed:
            return "Failed to create user profile"
        case .notInitialized:
            return "Authentication service not initialized"
        case .weakPassword:
            return "Password must be at least 6 characters long"
        case .invalidEmail:
            return "Please enter a valid email address"
        case .emailInUse:
            return "An account with this email already exists"
        case .wrongPassword:
            return "Incorrect password"
        }
    }
} 