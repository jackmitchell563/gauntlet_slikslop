import SwiftUI

struct FeedView: UIViewControllerRepresentable {
    @Binding var selectedTab: BottomNavigationBar.Tab
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let feedVC = FeedViewController()
        let navController = UINavigationController(rootViewController: feedVC)
        navController.setNavigationBarHidden(true, animated: false)
        return navController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // Update visibility based on selected tab
        let isVisible = selectedTab == .home
        if let feedVC = uiViewController.viewControllers.first as? FeedViewController {
            feedVC.handleTabVisibilityChange(isVisible: isVisible)
        }
    }
} 