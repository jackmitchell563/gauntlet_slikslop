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
        
        // Start preloading banners immediately
        Task {
            await Self.preloadBannersForAllGames()
        }
        
        // // Development only: Populate characters
        #if DEBUG
        Task {
            do {
                let populator = CharacterDataPopulator()
                try await populator.populateCharacters()
            } catch {
                print("❌ Error populating characters: \(error)")
            }
        }
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
    
    /// Preloads banner images for all games at app startup
    private static func preloadBannersForAllGames() async {
        print("📱 SlikSlopApp - Starting banner and profile image preload for all games")
        do {
            // Fetch characters for all games
            let characters = try await CharacterService.shared.fetchCharacters(game: nil)
            
            // Create task group to load both banner and profile images concurrently
            try await withThrowingTaskGroup(of: Void.self) { group in
                // Add banner preload task
                group.addTask {
                    _ = await CharacterAssetService.shared.preloadBannerImages(for: characters)
                }
                
                // Add profile image preload task
                group.addTask {
                    _ = await CharacterAssetService.shared.preloadProfileImages(for: characters)
                }
                
                try await group.waitForAll()
            }
            
            print("📱 SlikSlopApp - Completed banner and profile image preload for all games")
        } catch {
            print("❌ SlikSlopApp - Error preloading images: \(error)")
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
