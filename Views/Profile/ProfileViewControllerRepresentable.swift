import SwiftUI

/// A SwiftUI wrapper for ProfileViewController to enable UIKit integration
struct ProfileViewControllerRepresentable: UIViewControllerRepresentable {
    let userId: String
    
    func makeUIViewController(context: Context) -> ProfileViewController {
        return ProfileViewController(userId: userId)
    }
    
    func updateUIViewController(_ uiViewController: ProfileViewController, context: Context) {
        // Updates can be handled here if needed
    }
} 