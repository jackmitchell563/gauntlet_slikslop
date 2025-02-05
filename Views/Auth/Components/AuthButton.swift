import SwiftUI

/// A custom button component for authentication screens with consistent styling and loading state
struct AuthButton: View {
    let title: String
    let isLoading: Bool
    let action: () async -> Void
    
    init(
        title: String,
        isLoading: Bool = false,
        action: @escaping () async -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button {
            Task {
                await action()
            }
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .padding(.trailing, 8)
                }
                
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(10)
            .opacity(isLoading ? 0.7 : 1.0)
        }
        .disabled(isLoading)
        .padding(.horizontal)
    }
}

/// A secondary style button for authentication screens
struct AuthSecondaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.medium)
                .foregroundColor(.accentColor)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        AuthButton(
            title: "Sign In",
            isLoading: false
        ) {
            // Action
        }
        
        AuthButton(
            title: "Loading...",
            isLoading: true
        ) {
            // Action
        }
        
        AuthSecondaryButton(title: "Forgot Password?") {
            // Action
        }
    }
    .padding()
} 