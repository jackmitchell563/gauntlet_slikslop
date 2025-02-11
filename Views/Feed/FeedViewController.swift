import UIKit
import SwiftUI
import Combine
import FirebaseAuth

/// Main view controller for the video feed
class FeedViewController: UIViewController {
    // MARK: - Properties
    
    private var videos: [VideoMetadata] = []
    private var currentPage = 0
    private let pageSize = 10
    private var isLoading = false
    private var cancellables = Set<AnyCancellable>()
    private var isVisible = true
    private var isScrolling = false
    private var initialVideo: VideoMetadata?
    private var isPresenting = false
    
    // MARK: - UI Components
    
    private lazy var collectionView: UICollectionView = {
        let layout = VideoFeedLayout()
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.isPagingEnabled = true
        cv.delegate = self
        cv.dataSource = self
        cv.prefetchDataSource = self
        cv.register(VideoPlayerCell.self, forCellWithReuseIdentifier: VideoPlayerCell.identifier)
        cv.showsVerticalScrollIndicator = false
        cv.backgroundColor = .black
        cv.bounces = false
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // Ensure status bar updates
        setNeedsStatusBarAppearanceUpdate()
        
        Task {
            do {
                if let userId = AuthService.shared.currentUserId {
                    print("🔐 FeedViewController - Initializing like service for user: \(userId)")
                    try await LikeService.shared.initialize(userId: userId)
                    await loadInitialContent()
                } else {
                    print("❌ FeedViewController - No authenticated user")
                }
            } catch {
                print("❌ FeedViewController - Error during initialization: \(error)")
            }
        }
    }
    
    private func loadInitialContent() async {
        await MainActor.run {
            loadingIndicator.startAnimating()
        }
        
        do {
            guard let userId = AuthService.shared.currentUserId else {
                print("❌ FeedViewController - No authenticated user for content loading")
                return
            }
            
            var initialVideos: [VideoMetadata]
            if let initialVideo = initialVideo {
                // If we have an initial video, put it at the top
                let feedVideos = try await FeedService.shared.fetchFYPVideos(userId: userId)
                // Filter out the initial video if it exists in the feed to avoid duplication
                let filteredVideos = feedVideos.filter { $0.id != initialVideo.id }
                initialVideos = [initialVideo] + filteredVideos
            } else {
                initialVideos = try await FeedService.shared.fetchFYPVideos(userId: userId)
            }
            
            await MainActor.run {
                self.videos = initialVideos
                self.collectionView.reloadData()
                self.loadingIndicator.stopAnimating()
                
                // Ensure we're at the top
                self.collectionView.setContentOffset(.zero, animated: false)
                
                // Force layout update
                self.collectionView.layoutIfNeeded()
                
                // Start playing the first video using the new controller
                if !initialVideos.isEmpty {
                    self.updateVideoPlayback()
                }
            }
        } catch {
            await MainActor.run {
                self.loadingIndicator.stopAnimating()
                print("❌ FeedViewController - Error loading videos: \(error)")
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Only reset scroll position if not presenting a sheet and not during initial load
        if !videos.isEmpty && collectionView.contentOffset.y != 0 && !isPresenting {
            collectionView.setContentOffset(.zero, animated: false)
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .fade
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .black
        view.addSubview(collectionView)
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // MARK: - Data Loading
    
    private func loadMoreContent() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                guard let userId = AuthService.shared.currentUserId else {
                    print("❌ FeedViewController - No authenticated user for loading more content")
                    isLoading = false
                    return
                }
                
                let newVideos = try await FeedService.shared.fetchFYPVideos(userId: userId, limit: pageSize)
                await MainActor.run {
                    let startIndex = self.videos.count
                    self.videos.append(contentsOf: newVideos)
                    
                    let indexPaths = (0..<newVideos.count).map { offset in
                        IndexPath(item: startIndex + offset, section: 0)
                    }
                    
                    self.collectionView.insertItems(at: indexPaths)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("Error loading more videos: \(error)")
                }
            }
        }
    }
    
    // MARK: - Video Playback Management
    
    /// Updates the video playback state based on currently visible cells
    private func updateVideoPlayback() {
        print("📱 FeedViewController - Updating video playback")
        let visibleCells = collectionView.visibleCells.compactMap { $0 as? VideoPlayerCell }
        VideoPlaybackController.shared.updatePlayback(for: visibleCells, scrolling: isScrolling)
    }
    
    // MARK: - Tab Visibility
    
    func handleTabVisibilityChange(isVisible: Bool) {
        print("📱 FeedViewController - Tab visibility changed to: \(isVisible)")
        self.isVisible = isVisible
        VideoPlaybackController.shared.setTabVisibility(isVisible)
        if isVisible {
            updateVideoPlayback()
        }
    }
    
    // MARK: - Public Methods
    
    func setInitialVideo(_ video: VideoMetadata) {
        self.initialVideo = video
    }
    
    func reloadFeed() {
        // Reset scroll position
        collectionView.setContentOffset(.zero, animated: false)
        
        // Reload the feed content
        Task {
            await loadInitialContent()
        }
    }
    
    // Add method to handle sheet presentation
    func willPresentSheet() {
        isPresenting = true
    }
    
    // Add method to handle sheet dismissal
    func didDismissSheet() {
        isPresenting = false
    }
}

// MARK: - UICollectionView DataSource & Delegate

extension FeedViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return videos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: VideoPlayerCell.identifier, for: indexPath) as! VideoPlayerCell
        cell.configure(with: videos[indexPath.item])
        cell.tag = indexPath.item
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        updateVideoPlayback()
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        // No need to explicitly pause cells here as VideoPlaybackController handles this
        print("📱 FeedViewController - Cell at index \(indexPath.item) ended displaying")
    }
}

// MARK: - UICollectionView Prefetching

extension FeedViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        // TODO: Implement video prefetching
        // This would involve pre-loading video data for upcoming cells
    }
}

// MARK: - Scroll View Delegate

extension FeedViewController {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isScrolling = true
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateVideoPlayback()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            isScrolling = false
            updateVideoPlayback()
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        isScrolling = false
        updateVideoPlayback()
        
        // Keep existing content loading logic
        let threshold = scrollView.contentSize.height - scrollView.bounds.height * 2
        if scrollView.contentOffset.y >= threshold {
            loadMoreContent()
        }
    }
} 
