//
//  SlikSlopApp.swift
//  SlikSlop
//
//  Created by Jack Mitchell on 2/3/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct SlikSlopApp: App {
    init() {
        // Initialize Firebase synchronously
        FirebaseConfig.shared
        
        // Sign out any existing user
        print("🔐 SlikSlopApp - Signing out any existing user")
        try? AuthService.shared.signOut()
        
        // Configure status bar appearance for the entire app
        UIApplication.shared.windows.first?.overrideUserInterfaceStyle = .dark
        
        // // Development only: Populate characters
        // #if DEBUG
        // Task {
        //     do {
        //         let populator = CharacterDataPopulator()
        //         try await populator.populateCharacters()
        //     } catch {
        //         print("❌ Error populating characters: \(error)")
        //     }
        // }
        // #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

/// Manages the authentication state of the app
class AuthStateManager: ObservableObject {
    @Published var isAuthenticated = false
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        // Start with definitely not authenticated
        isAuthenticated = false
        print("🔐 AuthStateManager - Starting with isAuthenticated = false")
        
        // Then check Firebase auth state
        authStateHandle = AuthService.shared.handleAuthStateChanges { [weak self] user in
            DispatchQueue.main.async {
                withAnimation {
                    self?.isAuthenticated = user != nil
                    print("🔐 AuthStateManager - Auth state changed, isAuthenticated = \(user != nil)")
                    if let userId = user?.uid {
                        print("🔐 AuthStateManager - User ID: \(userId)")
                    }
                }
            }
        }
    }
    
    deinit {
        if let handle = authStateHandle {
            AuthService.shared.removeAuthStateListener(handle)
            print("🔐 AuthStateManager - Removed auth state listener")
        }
    }
}
