import UIKit

/// Protocol for handling video interactions
protocol VideoInteractionDelegate: AnyObject {
    func didTapLike(for videoId: String)
    func didTapComment(for videoId: String)
}

/// Custom view for video interaction buttons (likes, comments)
class VideoInteractionBar: UIView {
    // MARK: - Properties
    
    private var videoId: String?
    private(set) var isLiked: Bool = false
    private var isProcessingLike: Bool = false
    weak var delegate: VideoInteractionDelegate?
    
    // MARK: - UI Components
    
    private lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var likeButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: "heart.fill"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(handleLike), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isUserInteractionEnabled = true
        return button
    }()
    
    private lazy var commentButton: UIButton = {
        let button = createInteractionButton(icon: "bubble.right.fill")
        button.addTarget(self, action: #selector(handleComment), for: .touchUpInside)
        button.isUserInteractionEnabled = true
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
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    // MARK: - Helper Methods
    
    private func createInteractionButton(icon: String) -> UIButton {
        let button = UIButton()
        button.setImage(UIImage(systemName: icon), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    private func createCountLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private func createButtonContainer(button: UIButton, label: UILabel) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isUserInteractionEnabled = true
        
        container.addSubview(button)
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44),
            
            label.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 4),
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 70)
        ])
        
        return container
    }
    
    // MARK: - Configuration
    
    /// Configures the interaction bar with video metadata
    /// - Parameters:
    ///   - videoId: ID of the video
    ///   - likes: Number of likes
    ///   - comments: Number of comments
    ///   - isLiked: Whether the video is liked by the current user
    ///   - isProcessing: Whether a like operation is in progress
    func configure(videoId: String, likes: Int, comments: Int, isLiked: Bool = false, isProcessing: Bool = false) {
        print("📱 VideoInteractionBar - Configuring for video: \(videoId), likes: \(likes), isLiked: \(isLiked), isProcessing: \(isProcessing)")
        self.videoId = videoId
        self.isLiked = isLiked
        self.isProcessingLike = isProcessing
        updateLikeCount(likes)
        updateCommentCount(comments)
        updateLikeButtonAppearance()
        
        // Update button state
        likeButton.isEnabled = !isProcessing
        likeButton.alpha = isProcessing ? 0.5 : 1.0
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
} 