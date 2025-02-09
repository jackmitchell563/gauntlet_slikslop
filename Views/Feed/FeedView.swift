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
    
    class Coordinator {
        var lastInitialVideo: VideoMetadata?
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
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
            
            // Only reload feed if we have a new initial video AND we're switching to the home tab
            if let video = selectedVideo, 
               isVisible, // Only reload when becoming visible
               context.coordinator.lastInitialVideo?.id != video.id { // Only reload if video changed
                feedVC.setInitialVideo(video)
                feedVC.reloadFeed()
                context.coordinator.lastInitialVideo = video
            }
        }
    }
} 