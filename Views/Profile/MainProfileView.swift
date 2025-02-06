import SwiftUI

/// Main profile view that handles authentication state and displays the appropriate content
struct MainProfileView: View {
    @StateObject private var authState = AuthStateManager()
    
    var body: some View {
        Group {
            if authState.isAuthenticated, let currentUser = AuthService.shared.currentUserId {
                ProfileViewControllerRepresentable(userId: currentUser)
                    .ignoresSafeArea()
            } else {
                // Show sign-in prompt with the same styling as the rest of the app
                VStack {
                    Text("Sign in to view your profile")
                        .font(.headline)
                        .padding(.bottom, 8)
                    
                    Button(action: {
                        Task {
                            do {
                                let result = try await AuthService.shared.signInWithGoogle()
                                try await AuthService.shared.createUserProfile(user: result.user)
                            } catch {
                                print("Error signing in: \(error)")
                            }
                        }
                    }) {
                        Text("Sign In")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(Color.pink)
                            .cornerRadius(25)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            }
        }
    }
} 