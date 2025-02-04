# User Profile

## Overview

The `ProfileView.swift` file manages user profiles, including display and interaction features. While the core video grid uses UIKit's collection view for performance, the profile interface is built with SwiftUI for:
- Rapid development of static profile elements
- Easy state management for profile data
- Smooth animations for profile interactions
- Simple implementation of dark mode and accessibility features

The profile system demonstrates our mixed-approach architecture, using SwiftUI where it excels while leveraging UIKit for performance-critical video components.

## Core Functions

### ProfileService

### getUserProfile(userId:)
- **Purpose**: Fetches user profile data
- **Usage**: Called when loading profile page
- **Parameters**:
  - userId: User identifier
- **Returns**: UserProfile object
- **Example**:
```swift
class ProfileService {
    static let shared = ProfileService()
    private let dbService = DatabaseService.shared
    
    func getUserProfile(userId: String) async throws -> UserProfile {
        return try await dbService.getDocument(collection: "users", docId: userId)
    }
}
```

### fetchUserVideos(userId:)
- **Purpose**: Retrieves videos uploaded by user
- **Usage**: Called when displaying profile content
- **Parameters**:
  - userId: User identifier
- **Returns**: Array of VideoMetadata
- **Example**:
```swift
extension ProfileService {
    func fetchUserVideos(userId: String) async throws -> [VideoMetadata] {
        return try await dbService.queryCollection(collection: "videos") { query in
            query
                .whereField("creatorId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
        }
    }
}
```

### toggleFollow(targetUserId:currentUserId:)
- **Purpose**: Handles follow/unfollow actions
- **Usage**: Called from profile or video card
- **Parameters**:
  - targetUserId: Profile to follow/unfollow
  - currentUserId: User performing action
- **Example**:
```swift
extension ProfileService {
    func toggleFollow(targetUserId: String, currentUserId: String) async throws {
        let followId = "\(currentUserId)_\(targetUserId)"
        let follow: Follow? = try await dbService.getDocument(collection: "follows", docId: followId)
        
        if follow != nil {
            try await dbService.deleteDocument(collection: "follows", docId: followId)
        } else {
            let newFollow = Follow(
                id: followId,
                followerId: currentUserId,
                followingId: targetUserId,
                createdAt: Timestamp(date: Date())
            )
            try await dbService.createDocument(
                collection: "follows",
                data: newFollow.asDictionary()
            )
        }
    }
}
```

## View Controllers

### ProfileViewController
- **Purpose**: Main profile view controller managing user info and video grid
- **Example**:
```swift
class ProfileViewController: UIViewController {
    private let profileService = ProfileService.shared
    private var profile: UserProfile?
    private var videos: [VideoMetadata] = []
    
    private lazy var headerView: ProfileHeaderView = {
        let header = ProfileHeaderView()
        header.delegate = self
        return header
    }()
    
    private lazy var videoCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 1
        layout.minimumLineSpacing = 1
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.delegate = self
        cv.dataSource = self
        cv.register(VideoThumbnailCell.self, forCellWithReuseIdentifier: "VideoCell")
        return cv
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        Task {
            await loadProfileData()
        }
    }
    
    private func loadProfileData() async {
        do {
            async let profileData = profileService.getUserProfile(userId: userId)
            async let videosData = profileService.fetchUserVideos(userId: userId)
            
            let (profile, videos) = try await (profileData, videosData)
            
            self.profile = profile
            self.videos = videos
            
            headerView.configure(with: profile)
            videoCollectionView.reloadData()
        } catch {
            handleError(error)
        }
    }
}
```

### ProfileHeaderView
- **Purpose**: Displays user information and stats
- **Example**:
```swift
class ProfileHeaderView: UIView {
    weak var delegate: ProfileHeaderDelegate?
    
    private lazy var avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.layer.cornerRadius = 40
        iv.clipsToBounds = true
        return iv
    }()
    
    private lazy var statsView: ProfileStatsView = {
        let view = ProfileStatsView()
        return view
    }()
    
    private lazy var followButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(handleFollowTap), for: .touchUpInside)
        return button
    }()
    
    func configure(with profile: UserProfile) {
        if let photoURL = profile.photoURL {
            Task {
                await loadProfileImage(from: photoURL)
            }
        }
        
        statsView.configure(
            followers: profile.followerCount,
            following: profile.followingCount,
            likes: profile.totalLikes
        )
    }
    
    private func loadProfileImage(from urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            await MainActor.run {
                avatarImageView.image = UIImage(data: data)
            }
        } catch {
            print("Error loading profile image: \(error)")
        }
    }
    
    @objc private func handleFollowTap() {
        delegate?.didTapFollow()
    }
}
```

### VideoThumbnailCell
- **Purpose**: Displays video thumbnail in profile grid
- **Example**:
```swift
class VideoThumbnailCell: UICollectionViewCell {
    private lazy var thumbnailImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        return iv
    }()
    
    private lazy var statsOverlay: VideoStatsOverlay = {
        let overlay = VideoStatsOverlay()
        return overlay
    }()
    
    func configure(with video: VideoMetadata) {
        Task {
            await loadThumbnail(from: video.thumbnail)
        }
        statsOverlay.configure(likes: video.likes, views: video.views)
    }
    
    private func loadThumbnail(from urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            await MainActor.run {
                thumbnailImageView.image = UIImage(data: data)
            }
        } catch {
            print("Error loading thumbnail: \(error)")
        }
    }
}
```

## Best Practices

1. **Memory Management**
   - Use proper image caching
   - Implement efficient thumbnail loading
   - Clean up resources properly
   - Handle memory warnings

2. **Performance**
   - Load images asynchronously
   - Use proper collection view cell reuse
   - Implement pagination for videos
   - Cache profile data appropriately

3. **User Experience**
   - Implement smooth transitions
   - Add proper loading states
   - Handle errors gracefully
   - Support pull-to-refresh

4. **Data Management**
   - Use proper state management
   - Implement offline support
   - Handle data updates efficiently
   - Maintain data consistency

## Integration Example

```swift
// Profile view controller with collection view implementation
extension ProfileViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, 
                       numberOfItemsInSection section: Int) -> Int {
        return videos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, 
                       cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "VideoCell",
            for: indexPath
        ) as! VideoThumbnailCell
        
        cell.configure(with: videos[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView,
                       layout collectionViewLayout: UICollectionViewLayout,
                       sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width - 2) / 3
        return CGSize(width: width, height: width)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                       didSelectItemAt indexPath: IndexPath) {
        let video = videos[indexPath.item]
        let videoVC = VideoDetailViewController(video: video)
        navigationController?.pushViewController(videoVC, animated: true)
    }
}

// Profile header delegate implementation
extension ProfileViewController: ProfileHeaderDelegate {
    func didTapFollow() {
        guard let profile = profile else { return }
        
        Task {
            do {
                try await profileService.toggleFollow(
                    targetUserId: profile.id,
                    currentUserId: AuthService.shared.currentUserId
                )
                await loadProfileData() // Refresh data
            } catch {
                handleError(error)
            }
        }
    }
}
```

## Common Issues and Solutions

1. **Image Loading**
   - Problem: Slow image loading and flickering
   - Solution: Implement proper image caching and async loading

2. **Collection View Performance**
   - Problem: Laggy scrolling with many videos
   - Solution: Implement proper cell reuse and pagination

3. **State Management**
   - Problem: Inconsistent UI state
   - Solution: Implement proper state management with Combine

4. **Data Synchronization**
   - Problem: Outdated profile information
   - Solution: Implement real-time updates with Firebase listeners

## Profile Customization

1. **Theme Options**
   - Nature-themed backgrounds
   - Custom color schemes
   - Layout preferences
   - Font selections

2. **Content Organization**
   - Custom video collections
   - Featured content
   - Pinned videos
   - Content categories

3. **Privacy Settings**
   - View permissions
   - Interaction controls
   - Data visibility
   - Contact preferences 