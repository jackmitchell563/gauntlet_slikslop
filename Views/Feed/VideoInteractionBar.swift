import UIKit

/// Protocol for handling video interactions
protocol VideoInteractionDelegate: AnyObject {
    func didTapLike(for videoId: String)
    func didTapComment(for videoId: String)
    func didTapCreatorProfile(for creatorId: String)
}

/// Custom view for video interaction buttons (likes, comments)
class VideoInteractionBar: UIView {
    // MARK: - Properties
    
    private var videoId: String?
    private var creatorId: String?
    private var creatorPhotoURL: String?
    private(set) var isLiked: Bool = false
    private var isProcessingLike: Bool = false
    weak var delegate: VideoInteractionDelegate?
    
    // MARK: - UI Components
    
    private lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var profileButton: UIButton = {
        let button = UIButton()
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(handleProfileTap), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowOpacity = 0.75
        button.layer.shadowRadius = 2
        button.isUserInteractionEnabled = true  // Explicitly enable user interaction
        return button
    }()
    
    private lazy var profileImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isUserInteractionEnabled = false  // Disable user interaction on the image view
        return iv
    }()
    
    private lazy var likeButton: UIButton = {
        let button = UIButton()
        let config = UIImage.SymbolConfiguration(pointSize: 24)  // 16 * 1.5
        button.setImage(UIImage(systemName: "heart.fill", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(handleLike), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isUserInteractionEnabled = true
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowOpacity = 0.75
        button.layer.shadowRadius = 2
        return button
    }()
    
    private lazy var commentButton: UIButton = {
        let button = createInteractionButton(icon: "bubble.right.fill")
        button.addTarget(self, action: #selector(handleComment), for: .touchUpInside)
        button.isUserInteractionEnabled = true
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowOpacity = 0.75
        button.layer.shadowRadius = 2
        return button
    }()
    
    private lazy var likeCountLabel: UILabel = {
        let label = createCountLabel()
        return label
    }()
    
    private lazy var commentCountLabel: UILabel = {
        let label = createCountLabel()
        return label
    }()
    
    // MARK: - Image Cache
    
    class ImageCache {
        static let shared = ImageCache()
        private let cache = NSCache<NSString, UIImage>()
        
        private init() {}
        
        func setImage(_ image: UIImage, forKey key: String) {
            cache.setObject(image, forKey: key as NSString)
        }
        
        func getImage(forKey key: String) -> UIImage? {
            return cache.object(forKey: key as NSString)
        }
    }
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        addSubview(stackView)
        
        // Add profile button and image
        profileButton.addSubview(profileImageView)
        let profileContainer = createButtonContainer(button: profileButton, label: nil)
        stackView.addArrangedSubview(profileContainer)
        
        // Add like button and count
        let likeContainer = createButtonContainer(button: likeButton, label: likeCountLabel)
        stackView.addArrangedSubview(likeContainer)
        
        // Add comment button and count
        let commentContainer = createButtonContainer(button: commentButton, label: commentCountLabel)
        stackView.addArrangedSubview(commentContainer)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Profile image constraints - Updated to ensure proper centering and sizing
            profileImageView.centerXAnchor.constraint(equalTo: profileButton.centerXAnchor),
            profileImageView.centerYAnchor.constraint(equalTo: profileButton.centerYAnchor),
            profileImageView.widthAnchor.constraint(equalTo: profileButton.widthAnchor),
            profileImageView.heightAnchor.constraint(equalTo: profileButton.heightAnchor)
        ])
    }
    
    // MARK: - Helper Methods
    
    private func createInteractionButton(icon: String) -> UIButton {
        let button = UIButton()
        let config = UIImage.SymbolConfiguration(pointSize: 24)  // 16 * 1.5
        button.setImage(UIImage(systemName: icon, withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowOpacity = 1.0
        button.layer.shadowRadius = 4
        return button
    }
    
    private func createCountLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .medium)  // 12 * 1.5
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        // Add continuous shadow updates for dynamic text
        label.layer.shadowPath = nil
        label.layer.shouldRasterize = false
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        label.layer.shadowOpacity = 1.0
        label.layer.shadowRadius = 4
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }
    
    private func createButtonContainer(button: UIButton, label: UILabel?) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isUserInteractionEnabled = true
        
        container.addSubview(button)
        if let label = label {
            container.addSubview(label)
        }
        
        // Set constant size for all buttons
        let buttonSize: CGFloat = 48  // 32 * 1.5
        
        var constraints = [
            button.widthAnchor.constraint(equalToConstant: buttonSize),
            button.heightAnchor.constraint(equalToConstant: buttonSize)
        ]
        
        if let label = label {
            // For buttons with labels (like and comment buttons)
            constraints.append(contentsOf: [
                button.topAnchor.constraint(equalTo: container.topAnchor),
                button.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                label.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 4),
                label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                label.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor)
            ])
        } else {
            // For profile button (no label)
            constraints.append(contentsOf: [
                button.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                button.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                button.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor),
                button.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor)
            ])
        }
        
        // Container sizing
        constraints.append(contentsOf: [
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: buttonSize + 16),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: label != nil ? 75 : buttonSize + 16)  // Adjusted height based on whether there's a label
        ])
        
        NSLayoutConstraint.activate(constraints)
        
        return container
    }
    
    // MARK: - Configuration
    
    /// Configures the interaction bar with video metadata
    /// - Parameters:
    ///   - videoId: ID of the video
    ///   - creatorId: ID of the video creator
    ///   - creatorPhotoURL: URL of the creator's profile photo
    ///   - likes: Number of likes
    ///   - comments: Number of comments
    ///   - isLiked: Whether the video is liked by the current user
    ///   - isProcessing: Whether a like operation is in progress
    func configure(
        videoId: String,
        creatorId: String,
        creatorPhotoURL: String?,
        likes: Int,
        comments: Int,
        isLiked: Bool = false,
        isProcessing: Bool = false
    ) {
        print("📱 VideoInteractionBar - Configuring with creatorId: \(creatorId)")
        self.videoId = videoId
        self.creatorId = creatorId
        self.creatorPhotoURL = creatorPhotoURL
        self.isLiked = isLiked
        self.isProcessingLike = isProcessing
        updateLikeCount(likes)
        updateCommentCount(comments)
        updateLikeButtonAppearance()
        loadProfileImage()
        
        // Update button state
        likeButton.isEnabled = !isProcessing
        likeButton.alpha = isProcessing ? 0.5 : 1.0
        
        // Verify profile button setup
        print("🔍 VideoInteractionBar - Profile button state: isUserInteractionEnabled=\(profileButton.isUserInteractionEnabled), hasTarget=\(profileButton.allTargets.count > 0)")
    }
    
    /// Updates the like count display
    /// - Parameter count: New like count to display
    func updateLikeCount(_ count: Int) {
        print("📱 VideoInteractionBar - Updating like count to: \(count)")
        likeCountLabel.text = formatCount(count)
    }
    
    /// Updates the comment count display
    /// - Parameter count: New comment count to display
    func updateCommentCount(_ count: Int) {
        commentCountLabel.text = formatCount(count)
    }
    
    /// Updates the like button appearance based on like state
    private func updateLikeButtonAppearance() {
        print("📱 VideoInteractionBar - Updating button appearance, isLiked: \(isLiked)")
        likeButton.tintColor = isLiked ? .systemPink : .white
    }
    
    private func formatCount(_ count: Int) -> String {
        switch count {
        case 0..<1000:
            return "\(count)"
        case 1000..<1_000_000:
            return String(format: "%.1fK", Double(count) / 1000)
        default:
            return String(format: "%.1fM", Double(count) / 1_000_000)
        }
    }
    
    private func loadProfileImage() {
        guard let urlString = creatorPhotoURL,
              let url = URL(string: urlString) else {
            setPlaceholderImage()
            return
        }
        
        if let cachedImage = ImageCache.shared.getImage(forKey: urlString) {
            profileImageView.image = cachedImage
            return
        }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        ImageCache.shared.setImage(image, forKey: urlString)
                        profileImageView.image = image
                    }
                }
            } catch {
                await MainActor.run {
                    setPlaceholderImage()
                }
            }
        }
    }
    
    private func setPlaceholderImage() {
        let config = UIImage.SymbolConfiguration(pointSize: 24)
        profileImageView.image = UIImage(systemName: "person.circle.fill", withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal)
    }
    
    // MARK: - Actions
    
    @objc private func handleLike() {
        guard let videoId = videoId, !isProcessingLike else {
            print("📱 VideoInteractionBar - Like action blocked: \(isProcessingLike ? "Processing in progress" : "No video ID")")
            return
        }
        
        print("👆 VideoInteractionBar - Like button tapped for video: \(videoId)")
        
        // Set processing state and update UI
        isProcessingLike = true
        likeButton.isEnabled = false
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        // Animate button
        UIView.animate(withDuration: 0.1, animations: {
            self.likeButton.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.likeButton.transform = .identity
            }
        }
        
        print("📱 VideoInteractionBar - Delegating like tap to VideoPlayerCell")
        delegate?.didTapLike(for: videoId)
    }
    
    @objc private func handleComment() {
        guard let videoId = videoId else { return }
        delegate?.didTapComment(for: videoId)
    }
    
    @objc private func handleProfileTap() {
        print("👆 VideoInteractionBar - Profile button tapped")
        guard let creatorId = creatorId else {
            print("❌ VideoInteractionBar - No creatorId available for profile tap")
            return
        }
        print("📱 VideoInteractionBar - Delegating profile tap for creator: \(creatorId)")
        delegate?.didTapCreatorProfile(for: creatorId)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Update corner radius in layoutSubviews to ensure it's always circular
        profileButton.layer.cornerRadius = profileButton.bounds.width / 2
    }
} 