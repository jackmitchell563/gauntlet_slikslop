import SwiftUI

/// Custom NavigationController that hides status bar
class FeedNavigationController: UINavigationController {
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .fade
    }
}

struct FeedView: UIViewControllerRepresentable {
    @Binding var selectedTab: BottomNavigationBar.Tab
    var selectedVideo: VideoMetadata?
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let feedVC = FeedViewController()
        if let video = selectedVideo {
            feedVC.setInitialVideo(video)
        }
        let navController = FeedNavigationController(rootViewController: feedVC)
        navController.setNavigationBarHidden(true, animated: false)
        return navController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // Update visibility based on selected tab
        let isVisible = selectedTab == .home
        if let feedVC = uiViewController.viewControllers.first as? FeedViewController {
            feedVC.handleTabVisibilityChange(isVisible: isVisible)
            
            // Update initial video if changed
            if let video = selectedVideo {
                feedVC.setInitialVideo(video)
                feedVC.reloadFeed()
            }
        }
    }
} 