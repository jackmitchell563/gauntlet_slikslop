import SwiftUI

/// A custom error label component for authentication screens
struct AuthErrorLabel: View {
    let error: String?
    
    var body: some View {
        if let error = error {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .transition(.opacity)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        AuthErrorLabel(error: "Invalid email address")
        AuthErrorLabel(error: "Password must be at least 6 characters")
        AuthErrorLabel(error: nil)
    }
} 