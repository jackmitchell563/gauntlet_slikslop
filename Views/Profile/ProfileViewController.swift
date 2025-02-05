import UIKit
import FirebaseFirestore

/// View controller for displaying user profiles and their videos
class ProfileViewController: UIViewController {
    // MARK: - Properties
    
    private let userId: String
    private let profileService = ProfileService.shared
    private var profile: UserProfile?
    private var videos: [VideoMetadata] = []
    
    // MARK: - UI Components
    
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
        cv.backgroundColor = .systemBackground
        cv.register(VideoThumbnailCell.self, forCellWithReuseIdentifier: "VideoCell")
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // MARK: - Initialization
    
    init(userId: String) {
        self.userId = userId
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        Task {
            await loadProfileData()
        }
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add subviews
        view.addSubview(headerView)
        view.addSubview(videoCollectionView)
        view.addSubview(loadingIndicator)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            videoCollectionView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            videoCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // MARK: - Data Loading
    
    private func loadProfileData() async {
        loadingIndicator.startAnimating()
        
        do {
            async let profileData = profileService.getUserProfile(userId: userId)
            async let videosData = profileService.fetchUserVideos(userId: userId)
            
            let (profile, videos) = try await (profileData, videosData)
            
            await MainActor.run {
                self.profile = profile
                self.videos = videos
                
                headerView.configure(with: profile)
                videoCollectionView.reloadData()
                loadingIndicator.stopAnimating()
            }
        } catch {
            await MainActor.run {
                loadingIndicator.stopAnimating()
                // TODO: Show error state
                print("Error loading profile: \(error)")
            }
        }
    }
}

// MARK: - UICollectionViewDataSource

extension ProfileViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return videos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "VideoCell",
            for: indexPath
        ) as! VideoThumbnailCell
        
        cell.configure(with: videos[indexPath.item])
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension ProfileViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                       layout collectionViewLayout: UICollectionViewLayout,
                       sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width - 2) / 3
        return CGSize(width: width, height: width)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let video = videos[indexPath.item]
        let videoVC = VideoDetailViewController(video: video)
        navigationController?.pushViewController(videoVC, animated: true)
    }
}

// MARK: - ProfileHeaderDelegate

extension ProfileViewController: ProfileHeaderDelegate {
    func didTapFollow() {
        guard let profile = profile else { return }
        guard let currentUserId = AuthService.shared.currentUserId else {
            // TODO: Show sign in prompt
            return
        }
        
        Task {
            do {
                try await profileService.toggleFollow(
                    targetUserId: profile.id,
                    currentUserId: currentUserId
                )
                await loadProfileData() // Refresh data
            } catch {
                // TODO: Show error state
                print("Error toggling follow: \(error)")
            }
        }
    }
} 