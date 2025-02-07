import SwiftUI

/// Custom NavigationController that forces light status bar
class DarkModeNavigationController: UINavigationController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

/// SwiftUI wrapper for LoginViewController
struct LoginView: UIViewControllerRepresentable {
    var onComplete: ((Bool) -> Void)?
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let loginVC = LoginViewController(completion: onComplete)
        let navController = DarkModeNavigationController(rootViewController: loginVC)
        navController.setNavigationBarHidden(true, animated: false)
        return navController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No updates needed
    }
} 