import SwiftUI

/// SwiftUI wrapper for LoginViewController
struct LoginView: UIViewControllerRepresentable {
    var onComplete: ((Bool) -> Void)?
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let loginVC = LoginViewController(completion: onComplete)
        let navController = UINavigationController(rootViewController: loginVC)
        navController.setNavigationBarHidden(true, animated: false)
        return navController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No updates needed
    }
} 