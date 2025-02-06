import UIKit
import AVKit
import Combine

class VideoPlayerCell: UICollectionViewCell {
    static let identifier = "VideoPlayerCell"
    
    // MARK: - Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var metadata: VideoMetadata?
    
    // MARK: - UI Components
    
    private lazy var playerView: VideoPlayerView = {
        let view = VideoPlayerView()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var gradientOverlay: CAGradientLayer = {
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.black.withAlphaComponent(0.7).cgColor,
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.7).cgColor
        ]
        gradient.locations = [0, 0.3, 0.7, 1]
        return gradient
    }()
    
    private lazy var interactionOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white.withAlphaComponent(0.8)
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var interactionBar: VideoInteractionBar = {
        let bar = VideoInteractionBar()
        bar.delegate = self
        bar.translatesAutoresizingMaskIntoConstraints = false
        return bar
    }()
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientOverlay.frame = bounds
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        cleanup()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        backgroundColor = .black
        
        // Add subviews
        contentView.addSubview(playerView)
        contentView.layer.addSublayer(gradientOverlay)
        contentView.addSubview(interactionOverlay)
        
        interactionOverlay.addSubview(titleLabel)
        interactionOverlay.addSubview(descriptionLabel)
        interactionOverlay.addSubview(interactionBar)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            interactionOverlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            interactionOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            interactionOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            interactionOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            interactionBar.trailingAnchor.constraint(equalTo: interactionOverlay.trailingAnchor, constant: -16),
            interactionBar.centerYAnchor.constraint(equalTo: interactionOverlay.centerYAnchor),
            interactionBar.widthAnchor.constraint(equalToConstant: 60),
            
            titleLabel.leadingAnchor.constraint(equalTo: interactionOverlay.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: interactionBar.leadingAnchor, constant: -16),
            titleLabel.bottomAnchor.constraint(equalTo: descriptionLabel.topAnchor, constant: -8),
            
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: interactionOverlay.bottomAnchor, constant: -120)
        ])
    }
    
    private func setupGestures() {
        // Create a tap gesture recognizer for the cell's content
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleCellTap))
        tapGesture.delegate = self
        contentView.addGestureRecognizer(tapGesture)
        
        // Ensure buttons can still be tapped
        tapGesture.cancelsTouchesInView = false
        tapGesture.requiresExclusiveTouchType = false
    }
    
    @objc private func handleCellTap(_ gesture: UITapGestureRecognizer) {
        // Forward the tap to the player view
        if gesture.state == .ended {
            playerView.handleTap()
        }
    }
    
    // MARK: - Configuration
    
    func configure(with metadata: VideoMetadata) {
        self.metadata = metadata
        
        titleLabel.text = metadata.title
        descriptionLabel.text = metadata.description
        
        // Configure interaction bar with all necessary data
        interactionBar.configure(
            videoId: metadata.id,
            creatorId: metadata.creatorId,
            creatorPhotoURL: metadata.creatorPhotoURL,
            likes: metadata.stats.likes,
            comments: metadata.stats.comments,
            isLiked: false
        )
        
        // Check like state asynchronously
        Task {
            do {
                guard let userId = AuthService.shared.currentUserId else {
                    print("❌ VideoPlayerCell - No authenticated user for like state check")
                    return
                }
                
                let isLiked = try await LikeService.shared.isVideoLiked(videoId: metadata.id, userId: userId)
                print("📱 VideoPlayerCell - Retrieved like state for video: \(metadata.id), isLiked: \(isLiked)")
                
                // Update UI on main thread
                await MainActor.run {
                    interactionBar.configure(
                        videoId: metadata.id,
                        creatorId: metadata.creatorId,
                        creatorPhotoURL: metadata.creatorPhotoURL,
                        likes: metadata.stats.likes,
                        comments: metadata.stats.comments,
                        isLiked: isLiked
                    )
                }
            } catch {
                print("❌ VideoPlayerCell - Error checking like state: \(error)")
            }
        }
        
        playerView.configure(with: URL(string: metadata.url)!, isFirstCell: tag == 0)
        // Only pause if not the first video
        if tag != 0 {
            playerView.pause()
        }
    }
    
    // MARK: - Playback Control
    
    func play() {
        playerView.play()
    }
    
    func pause() {
        playerView.pause()
    }
    
    // MARK: - Interaction Handlers
    
    @objc private func handleShare() {
        guard let metadata = metadata else { return }
        
        let items = [
            metadata.title,
            metadata.url
        ]
        
        let ac = UIActivityViewController(activityItems: items, applicationActivities: nil)
        parentViewController?.present(ac, animated: true)
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        playerView.cleanup()
        cancellables.removeAll()
        metadata = nil
    }
}

// MARK: - VideoPlayerViewDelegate

extension VideoPlayerCell: VideoPlayerViewDelegate {
    func videoPlayerViewDidTapToTogglePlayback(_ view: VideoPlayerView) {
        // No additional handling needed, the VideoPlayerView handles everything
    }
}

// MARK: - VideoInteractionDelegate

extension VideoPlayerCell: VideoInteractionDelegate {
    func didTapLike(for videoId: String) {
        print("👆 VideoPlayerCell - Handling like tap for video: \(videoId)")
        
        guard var metadata = metadata else {
            print("❌ VideoPlayerCell - No metadata available for like action")
            return
        }
        
        guard let userId = AuthService.shared.currentUserId else {
            print("❌ VideoPlayerCell - No authenticated user for like action")
            return
        }
        
        print("📱 VideoPlayerCell - Starting like toggle process for user: \(userId)")
        
        // Show processing state immediately
        interactionBar.configure(
            videoId: videoId,
            creatorId: metadata.creatorId,
            creatorPhotoURL: metadata.creatorPhotoURL,
            likes: metadata.stats.likes,
            comments: metadata.stats.comments,
            isLiked: !interactionBar.isLiked,  // Preview the new state
            isProcessing: true
        )
        
        Task {
            do {
                // Toggle like and get new state
                print("📱 VideoPlayerCell - Calling LikeService to toggle like")
                let isLiked = try await LikeService.shared.toggleLike(videoId: videoId, userId: userId)
                print("📱 VideoPlayerCell - Like toggled successfully, new state: \(isLiked)")
                
                // Update local metadata
                let newLikeCount = metadata.stats.likes + (isLiked ? 1 : -1)
                print("📱 VideoPlayerCell - Updating like count from \(metadata.stats.likes) to \(newLikeCount)")
                metadata.stats.likes = newLikeCount
                self.metadata = metadata
                
                // Update UI
                await MainActor.run {
                    print("📱 VideoPlayerCell - Updating UI with new like state")
                    interactionBar.configure(
                        videoId: videoId,
                        creatorId: metadata.creatorId,
                        creatorPhotoURL: metadata.creatorPhotoURL,
                        likes: newLikeCount,
                        comments: metadata.stats.comments,
                        isLiked: isLiked,
                        isProcessing: false
                    )
                }
            } catch {
                print("❌ VideoPlayerCell - Error toggling like: \(error)")
                // Reset UI on error
                await MainActor.run {
                    interactionBar.configure(
                        videoId: videoId,
                        creatorId: metadata.creatorId,
                        creatorPhotoURL: metadata.creatorPhotoURL,
                        likes: metadata.stats.likes,
                        comments: metadata.stats.comments,
                        isLiked: !interactionBar.isLiked,  // Revert to original state
                        isProcessing: false
                    )
                }
            }
        }
    }
    
    func didTapComment(for videoId: String) {
        guard let metadata = metadata else {
            print("❌ VideoPlayerCell - No metadata available for comment action")
            return
        }
        
        // Create and present comment view controller
        let commentVC = CommentViewController(videoId: videoId, creatorId: metadata.creatorId)
        commentVC.modalPresentationStyle = .pageSheet
        
        if let sheet = commentVC.sheetPresentationController {
            // Create custom detent that's 1 point smaller than maximum height
            let customDetent = UISheetPresentationController.Detent.custom { context in
                return context.maximumDetentValue - 1
            }
            let mediumDetent = UISheetPresentationController.Detent.medium()
            
            sheet.detents = [mediumDetent, customDetent]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.delegate = self
            
            if #available(iOS 15.0, *) {
                sheet.preferredCornerRadius = 15.0
            }
        }
        
        // Present the comment section
        parentViewController?.present(commentVC, animated: true)
    }
    
    func didTapCreatorProfile(for creatorId: String) {
        print("👆 VideoPlayerCell - Received profile tap for creator: \(creatorId)")
        guard let metadata = metadata else {
            print("❌ VideoPlayerCell - No metadata available for profile action")
            return
        }
        
        guard let parentVC = parentViewController else {
            print("❌ VideoPlayerCell - No parent view controller found")
            return
        }
        
        print("📱 VideoPlayerCell - Creating ProfileViewController for creator: \(creatorId)")
        let profileVC = ProfileViewController(userId: creatorId)
        profileVC.modalPresentationStyle = .pageSheet
        
        if let sheet = profileVC.sheetPresentationController {
            // Create custom detent that's 1 point smaller than maximum height
            let customDetent = UISheetPresentationController.Detent.custom { context in
                return context.maximumDetentValue - 1
            }
            let mediumDetent = UISheetPresentationController.Detent.medium()
            
            sheet.detents = [mediumDetent, customDetent]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.delegate = self
            
            if #available(iOS 15.0, *) {
                sheet.preferredCornerRadius = 15.0
            }
        }
        
        // Present the profile view controller
        parentVC.present(profileVC, animated: true)
    }
    
    func didTapCharacterInteraction(for videoId: String) {
        print("👆 VideoPlayerCell - Character interaction tapped for video: \(videoId)")
        
        // Pause the video
        pause()
        
        // Create and present the character selection view controller
        let selectionVC = CharacterSelectionViewController()
        selectionVC.modalPresentationStyle = .pageSheet
        selectionVC.delegate = self // Set the delegate
        
        if let sheet = selectionVC.sheetPresentationController {
            // Create a custom detent that's 1 point smaller than maximum height
            let customDetent = UISheetPresentationController.Detent.custom { context in
                return context.maximumDetentValue - 1
            }
            let mediumDetent = UISheetPresentationController.Detent.medium()
            
            sheet.detents = [mediumDetent, customDetent]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.delegate = self // Set sheet delegate
            
            if #available(iOS 15.0, *) {
                sheet.preferredCornerRadius = 15.0
            }
        }
        
        parentViewController?.present(selectionVC, animated: true)
    }
}

// MARK: - CharacterSelectionDelegate

extension VideoPlayerCell: CharacterSelectionDelegate {
    func characterSelectionViewController(_ viewController: CharacterSelectionViewController, didSelect character: GameCharacter) {
        print("📱 VideoPlayerCell - Character selected: \(character.name)")
        
        // Dismiss the character selection view controller
        viewController.dismiss(animated: true) { [weak self] in
            // Present the chat view controller
            let chatVC = ChatViewController(character: character)
            chatVC.modalPresentationStyle = .pageSheet
            
            if let sheet = chatVC.sheetPresentationController {
                // Create a custom detent that's 1 point smaller than maximum height
                let customDetent = UISheetPresentationController.Detent.custom { context in
                    return context.maximumDetentValue - 1
                }
                
                sheet.detents = [customDetent]
                sheet.prefersGrabberVisible = true
                sheet.prefersScrollingExpandsWhenScrolledToEdge = true
                sheet.prefersEdgeAttachedInCompactHeight = true
                sheet.delegate = self // Set sheet delegate
                
                if #available(iOS 15.0, *) {
                    sheet.preferredCornerRadius = 15.0
                }
            }
            
            self?.parentViewController?.present(chatVC, animated: true)
        }
    }
}

// MARK: - UISheetPresentationControllerDelegate

extension VideoPlayerCell: UISheetPresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        print("📱 VideoPlayerCell - Sheet dismissed, resuming video playback")
        play()
    }
}

// MARK: - Helper Views

class InteractionButton: UIButton {
    private let spacing: CGFloat = 4
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupButton() {
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(
            top: spacing,
            leading: -imageView!.frame.size.width,
            bottom: -imageView!.frame.size.height,
            trailing: 0
        )
        configuration = config
        
        // Add basic styling
        tintColor = .white
        configuration?.baseForegroundColor = .white
        
        // Set size constraints
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 60),
            heightAnchor.constraint(equalToConstant: 60)
        ])
    }
}

// MARK: - Extensions

extension UIView {
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder?.next
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        return nil
    }
}

// MARK: - UIGestureRecognizerDelegate

extension VideoPlayerCell: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Don't handle taps on the interaction bar or its subviews
        if touch.view?.isDescendant(of: interactionBar) == true {
            return false
        }
        return true
    }
} 