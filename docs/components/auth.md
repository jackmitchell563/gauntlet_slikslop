# Authentication Service

## Overview

The `AuthService.swift` file provides secure user authentication and account management using Firebase Auth, with a focus on Google sign-in integration.

## Core Functions

### signInWithGoogle()
- **Purpose**: Initiates Google sign-in flow using Firebase Auth
- **Usage**: Called on login screen
- **Returns**: AuthResult
- **Example**:
```swift
class AuthService {
    static let shared = AuthService()
    private let auth = FirebaseConfig.getAuthInstance()
    
    func signInWithGoogle() async throws -> AuthDataResult {
        let provider = GoogleAuthProvider()
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            throw AuthError.presentationError
        }
        
        let credential = try await provider.getCredential(presenting: rootVC)
        return try await auth.signIn(with: credential)
    }
}
```

### signOutUser()
- **Purpose**: Signs out the current user
- **Usage**: Called from settings or profile
- **Example**:
```swift
class AuthService {
    func signOutUser() throws {
        try auth.signOut()
    }
}
```

### handleAuthStateChanges(callback:)
- **Purpose**: Listens for changes to the user's authentication state
- **Usage**: Called at app launch to update UI based on login status
- **Parameters**: Closure to handle state changes
- **Example**:
```swift
class AuthService {
    func handleAuthStateChanges(callback: @escaping (User?) -> Void) -> AuthStateDidChangeListenerHandle {
        return auth.addStateDidChangeListener { _, user in
            callback(user)
        }
    }
}
```

### createUserProfile(user:additionalData:)
- **Purpose**: Sets up new user profile in Firestore
- **Usage**: Called after successful authentication
- **Parameters**:
  - user: Firebase user object
  - additionalData: Extra profile information
- **Example**:
```swift
class AuthService {
    func createUserProfile(user: User, additionalData: [String: Any]) async throws {
        let db = FirebaseConfig.getFirestoreInstance()
        try await db.collection("users").document(user.uid).setData([
            "email": user.email ?? "",
            "displayName": user.displayName ?? "",
            "photoURL": user.photoURL?.absoluteString ?? "",
            "createdAt": FieldValue.serverTimestamp()
        ].merging(additionalData) { current, _ in current })
    }
}
```

### createAIUserProfile(aiType:focusArea:)
- **Purpose**: Creates AI user account for content generation
- **Usage**: Called during system initialization
- **Parameters**:
  - aiType: Type of AI content creator
  - focusArea: Specific nature/animal focus
- **Example**:
```swift
class AuthService {
    func createAIUserProfile(aiType: String, focusArea: String) async throws {
        let db = FirebaseConfig.getFirestoreInstance()
        let aiUserId = UUID().uuidString
        
        try await db.collection("users").document(aiUserId).setData([
            "type": "ai",
            "aiType": aiType,
            "focusArea": focusArea,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }
}
```

## Best Practices

1. **Security**
   - Use keychain for sensitive data
   - Implement proper error handling
   - Follow Apple's authentication guidelines
   - Use secure token management

2. **User Experience**
   - Handle biometric authentication
   - Provide clear error messages
   - Implement proper loading states
   - Support Sign in with Apple

3. **Error Handling**
   - Use custom error types
   - Implement retry mechanisms
   - Log authentication failures
   - Handle network issues

4. **Profile Management**
   - Use Codable for data models
   - Implement proper validation
   - Handle data migrations
   - Use proper access control

## Integration Example

```swift
// In your login view controller
class LoginViewController: UIViewController {
    private let authService = AuthService.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        authService.handleAuthStateChanges { [weak self] user in
            if let user = user {
                self?.handleSignedInUser(user)
            } else {
                self?.showLoginUI()
            }
        }
    }
    
    @IBAction func googleSignInTapped() {
        Task {
            do {
                let result = try await authService.signInWithGoogle()
                try await authService.createUserProfile(user: result.user, additionalData: [:])
                // Handle successful sign in
            } catch {
                // Handle error
                showAlert(error: error)
            }
        }
    }
}
```

## Common Issues and Solutions

1. **Token Expiration**
   - Problem: Auth tokens expiring unexpectedly
   - Solution: Implement proper token refresh using KeychainAccess

2. **Profile Sync**
   - Problem: User profile not syncing across devices
   - Solution: Use Firestore real-time listeners

3. **Auth State Management**
   - Problem: Inconsistent auth state across app
   - Solution: Use Combine for state management

4. **AI Profile Management**
   - Problem: AI profiles requiring special handling
   - Solution: Implement dedicated AI profile manager class 