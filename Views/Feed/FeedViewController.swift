import UIKit
import SwiftUI
import Combine

/// Main view controller for the video feed
class FeedViewController: UIViewController {
    // MARK: - Properties
    
    private var videos: [VideoMetadata] = []
    private var currentPage = 0
    private let pageSize = 10
    private var isLoading = false
    private var cancellables = Set<AnyCancellable>()
    
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
        loadInitialContent()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
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
    
    private func loadInitialContent() {
        loadingIndicator.startAnimating()
        Task {
            do {
                let initialVideos = try await FeedService.shared.fetchFYPVideos(userId: "current_user") // TODO: Get actual user ID
                await MainActor.run {
                    self.videos = initialVideos
                    self.collectionView.reloadData()
                    self.loadingIndicator.stopAnimating()
                    
                    // Start playing the first video
                    if !initialVideos.isEmpty {
                        self.playVisibleVideos()
                    }
                }
            } catch {
                await MainActor.run {
                    self.loadingIndicator.stopAnimating()
                    // TODO: Show error state
                    print("Error loading videos: \(error)")
                }
            }
        }
    }
    
    private func loadMoreContent() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                let newVideos = try await FeedService.shared.fetchFYPVideos(userId: "current_user", limit: pageSize)
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
    
    private func playVisibleVideos() {
        // First, pause ALL videos in the collection view
        collectionView.visibleCells.forEach { cell in
            if let videoCell = cell as? VideoPlayerCell {
                print("Pausing video at index: \(videoCell.tag)")
                videoCell.pause()
            }
        }
        
        // Then, only play the most visible cell if it meets our visibility threshold
        if let mostVisibleCell = getMostVisibleCell() as? VideoPlayerCell {
            print("Playing video at index: \(mostVisibleCell.tag)")
            mostVisibleCell.play()
        } else {
            print("No cell met the visibility threshold for playback")
        }
    }
    
    private func getMostVisibleCell() -> UICollectionViewCell? {
        let visibleCells = collectionView.visibleCells
        guard !visibleCells.isEmpty else { return nil }
        
        let cellVisibilityPairs = visibleCells.map { cell -> (UICollectionViewCell, CGFloat) in
            let cellRect = cell.convert(cell.bounds, to: collectionView)
            let intersection = cellRect.intersection(collectionView.bounds)
            let visibleArea = intersection.height / cellRect.height
            
            // Debug logging
            print("Cell at index \((cell as? VideoPlayerCell)?.tag ?? -1) visibility: \(visibleArea)")
            
            return (cell, visibleArea)
        }
        
        // Only consider cells that are more than 50% visible
        let threshold: CGFloat = 0.5
        let mostVisiblePair = cellVisibilityPairs
            .filter { $0.1 > threshold }
            .max { $0.1 < $1.1 }
        
        return mostVisiblePair?.0
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
        // When a cell is about to be displayed, check if it should be playing
        playVisibleVideos()
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        // Ensure the cell is paused when it's no longer displayed
        if let videoCell = cell as? VideoPlayerCell {
            print("Forcing pause for cell leaving screen at index: \(videoCell.tag)")
            videoCell.pause()
        }
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
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Update video playback during scrolling
        playVisibleVideos()
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // Ensure correct video is playing after scroll ends
        playVisibleVideos()
        
        // Load more content if needed
        let threshold = scrollView.contentSize.height - scrollView.bounds.height * 2
        if scrollView.contentOffset.y >= threshold {
            loadMoreContent()
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            playVisibleVideos()
        }
    }
}

// MARK: - SwiftUI Integration

struct FeedView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> FeedViewController {
        return FeedViewController()
    }
    
    func updateUIViewController(_ uiViewController: FeedViewController, context: Context) {
        // Update the view controller if needed
    }
} 
