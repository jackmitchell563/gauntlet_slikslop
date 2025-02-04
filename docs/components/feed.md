# Feed System

## Overview

The `FeedService.swift` and `FeedViewController.swift` files manage different content feeds: the AI-driven For You Page (FYP), Following Feed, and Trending Section. They handle fetching, rendering, and personalizing video content using UIKit's efficient video playback and scrolling capabilities. The decision to use UIKit for the feed system is performance-driven, particularly for:
- Optimal video playback performance
- Efficient memory management for infinite scrolling
- Better control over video thumbnail loading and caching
- Superior cell reuse for smooth scrolling performance

While the app uses SwiftUI for simpler views, the feed system requires UIKit's performance capabilities for a smooth user experience.

## Core Functions

### FeedService

### fetchFYPVideos(userId:)
- **Purpose**: Generates personalized feed using AI engine
- **Usage**: Called when FYP tab is active
- **Parameters**:
  - userId: Current user's identifier
- **Returns**: Array of VideoMetadata
- **Example**:
```swift
class FeedService {
    static let shared = FeedService()
    private let aiEngine = AIEngine.shared
    private let dbService = DatabaseService.shared
    
    func fetchFYPVideos(userId: String) async throws -> [VideoMetadata] {
        let behavior = try await aiEngine.analyzeUserBehavior(userId: userId)
        return try await aiEngine.generatePersonalizedFeed(from: behavior)
    }
}
```

### fetchFollowingVideos(userId:)
- **Purpose**: Retrieves videos from followed accounts
- **Usage**: Called when following feed tab is selected
- **Parameters**:
  - userId: Current user's identifier
- **Returns**: Array of VideoMetadata
- **Example**:
```swift
extension FeedService {
    func fetchFollowingVideos(userId: String) async throws -> [VideoMetadata] {
        return try await dbService.queryCollection(collection: "videos") { query in
            query
                .whereField("creatorId", isIn: try await getFollowedUserIds(userId: userId))
                .order(by: "createdAt", descending: true)
                .limit(to: 20)
        }
    }
    
    private func getFollowedUserIds(userId: String) async throws -> [String] {
        let follows: [Follow] = try await dbService.queryCollection(collection: "follows") { query in
            query.whereField("followerId", isEqualTo: userId)
        }
        return follows.map { $0.followingId }
    }
}
```

### fetchTrendingVideos()
- **Purpose**: Retrieves popular nature/animal content
- **Usage**: Called when trending tab is active
- **Returns**: Array of VideoMetadata
- **Example**:
```swift
extension FeedService {
    func fetchTrendingVideos() async throws -> [VideoMetadata] {
        let weekAgo = Date().addingTimeInterval(-7*24*60*60)
        return try await dbService.queryCollection(collection: "videos") { query in
            query
                .whereField("createdAt", isGreaterThan: weekAgo)
                .order(by: "likes", descending: true)
                .limit(to: 20)
        }
    }
}
```

## View Controllers

### FeedViewController
- **Purpose**: Main feed view controller managing video playback and scrolling
- **Example**:
```swift
class FeedViewController: UIViewController {
    private let feedService = FeedService.shared
    private var videos: [VideoMetadata] = []
    private var currentPage = 0
    private let pageSize = 10
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.isPagingEnabled = true
        cv.delegate = self
        cv.dataSource = self
        cv.register(VideoCell.self, forCellWithReuseIdentifier: "VideoCell")
        return cv
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        Task {
            await loadInitialContent()
        }
    }
    
    private func loadInitialContent() async {
        do {
            let feedType = FeedType.current
            videos = try await fetchVideos(for: feedType)
            collectionView.reloadData()
        } catch {
            handleError(error)
        }
    }
    
    private func fetchVideos(for type: FeedType) async throws -> [VideoMetadata] {
        switch type {
        case .fyp:
            return try await feedService.fetchFYPVideos(userId: currentUserId)
        case .following:
            return try await feedService.fetchFollowingVideos(userId: currentUserId)
        case .trending:
            return try await feedService.fetchTrendingVideos()
        }
    }
}
```

### VideoCell
- **Purpose**: Handles individual video playback and interactions
- **Example**:
```swift
class VideoCell: UICollectionViewCell {
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var videoMetadata: VideoMetadata?
    
    private lazy var playerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }()
    
    private lazy var interactionBar: VideoInteractionBar = {
        let bar = VideoInteractionBar()
        bar.delegate = self
        return bar
    }()
    
    func configure(with metadata: VideoMetadata) {
        self.videoMetadata = metadata
        setupPlayer(with: URL(string: metadata.url)!)
        interactionBar.configure(likes: metadata.likes, comments: metadata.comments)
    }
    
    private func setupPlayer(with url: URL) {
        player = AVPlayer(url: url)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspectFill
        playerLayer?.frame = contentView.bounds
        playerView.layer.addSublayer(playerLayer!)
    }
    
    func startPlayback() {
        player?.play()
    }
    
    func pausePlayback() {
        player?.pause()
    }
}
```

### VideoInteractionBar
- **Purpose**: Handles likes, comments, and sharing
- **Example**:
```swift
class VideoInteractionBar: UIView {
    weak var delegate: VideoInteractionDelegate?
    
    private lazy var likeButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(handleLike), for: .touchUpInside)
        return button
    }()
    
    private lazy var commentButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(handleComment), for: .touchUpInside)
        return button
    }()
    
    func configure(likes: Int, comments: Int) {
        likeButton.setTitle("\(likes)", for: .normal)
        commentButton.setTitle("\(comments)", for: .normal)
    }
    
    @objc private func handleLike() {
        delegate?.didTapLike()
    }
    
    @objc private func handleComment() {
        delegate?.didTapComment()
    }
}
```

## Best Practices

1. **Memory Management**
   - Implement proper video preloading
   - Cache thumbnails efficiently
   - Clean up video resources
   - Use proper cell reuse

2. **Performance**
   - Use UICollectionView prefetching
   - Implement smooth scrolling
   - Optimize video playback
   - Handle background/foreground transitions

3. **User Experience**
   - Implement proper loading states
   - Handle network transitions
   - Provide haptic feedback
   - Support pull-to-refresh

4. **Video Playback**
   - Preload next video
   - Handle audio routing
   - Support picture-in-picture
   - Implement proper buffering

## Integration Example

```swift
// Feed view controller implementation with pagination
extension FeedViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let urls = indexPaths.compactMap { URL(string: videos[$0.item].url) }
        VideoPreloader.shared.preloadVideos(urls)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let visibleCells = collectionView.visibleCells as! [VideoCell]
        
        // Pause all cells except the current one
        visibleCells.forEach { cell in
            if cell == collectionView.visibleCells.first {
                cell.startPlayback()
            } else {
                cell.pausePlayback()
            }
        }
        
        // Load more content if needed
        if scrollView.contentOffset.y >= scrollView.contentSize.height - scrollView.bounds.height {
            Task {
                await loadMoreContent()
            }
        }
    }
    
    private func loadMoreContent() async {
        guard !isLoading else { return }
        isLoading = true
        
        do {
            let newVideos = try await fetchVideos(for: .current)
            videos.append(contentsOf: newVideos)
            collectionView.reloadData()
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
}
```

## Common Issues and Solutions

1. **Memory Management**
   - Problem: High memory usage with multiple videos
   - Solution: Implement proper video cleanup and preloading

2. **Smooth Scrolling**
   - Problem: Jerky video transitions
   - Solution: Use proper cell preparation and video preloading

3. **Network Handling**
   - Problem: Poor performance on slow networks
   - Solution: Implement adaptive quality and proper buffering

4. **Battery Usage**
   - Problem: High battery consumption
   - Solution: Optimize video playback and preloading strategies 