# Firebase Configuration

## Overview

The `FirebaseConfig.swift` file initializes and exports Firebase SDK services (Authentication, Firestore, Storage, and Cloud Functions) to be used across the app.

## Core Functions

### initializeFirebase()
- **Purpose**: Initializes Firebase with the correct configuration keys
- **Usage**: Called once at app start
- **Returns**: Void
- **Example**:
```swift
class FirebaseConfig {
    static let shared = FirebaseConfig()
    private init() {} // Singleton
    
    func initializeFirebase() {
        guard let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: filePath) else {
            fatalError("Couldn't load Firebase configuration file")
        }
        FirebaseApp.configure(options: options)
    }
}
```

### getAuthInstance()
- **Purpose**: Returns the Firebase Auth instance
- **Usage**: Called by the authentication service
- **Returns**: Auth instance
- **Example**:
```swift
class FirebaseConfig {
    static func getAuthInstance() -> Auth {
        return Auth.auth()
    }
}
```

### getFirestoreInstance()
- **Purpose**: Returns the Firestore instance
- **Usage**: Called by database-related functions
- **Returns**: Firestore instance
- **Example**:
```swift
class FirebaseConfig {
    static func getFirestoreInstance() -> Firestore {
        return Firestore.firestore()
    }
}
```

### getStorageInstance()
- **Purpose**: Returns the Cloud Storage instance
- **Usage**: Called for media file operations
- **Returns**: Storage instance
- **Example**:
```swift
class FirebaseConfig {
    static func getStorageInstance() -> Storage {
        return Storage.storage()
    }
}
```

### getFunctionsInstance()
- **Purpose**: Returns the Cloud Functions instance
- **Usage**: Called for server-side logic
- **Returns**: Functions instance
- **Example**:
```swift
class FirebaseConfig {
    static func getFunctionsInstance() -> Functions {
        return Functions.functions()
    }
}
```

## Best Practices

1. **Instance Reuse**
   - Use singleton pattern for Firebase configuration
   - Access instances through static methods
   - Maintain thread safety
   - Use dependency injection where appropriate

2. **Configuration Security**
   - Store Firebase configuration in GoogleService-Info.plist
   - Never commit API keys to version control
   - Use appropriate security rules for each service
   - Implement proper keychain access

3. **Error Handling**
   - Use Swift's Result type for error handling
   - Implement proper logging
   - Handle initialization failures gracefully
   - Provide meaningful error messages

4. **Performance**
   - Initialize Firebase on app launch
   - Use background threads for heavy operations
   - Monitor Firebase usage
   - Implement proper caching

## Integration Example

```swift
// In your AppDelegate
import Firebase

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize Firebase
        FirebaseConfig.shared.initializeFirebase()
        return true
    }
}

// In other files
class VideoService {
    private let storage = FirebaseConfig.getStorageInstance()
    private let db = FirebaseConfig.getFirestoreInstance()
    
    func uploadVideo() async throws {
        // Use storage and db instances
    }
}
```

## Common Issues and Solutions

1. **Multiple Initialization**
   - Problem: Firebase being initialized multiple times
   - Solution: Use singleton pattern and proper app lifecycle management

2. **Missing Configuration**
   - Problem: GoogleService-Info.plist not found
   - Solution: Verify file is included in target and copied in build phases

3. **Service Availability**
   - Problem: Services not enabled in Firebase Console
   - Solution: Enable required services and verify bundle ID matches 