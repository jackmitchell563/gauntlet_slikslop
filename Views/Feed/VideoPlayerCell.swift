import UIKit
import AVKit
import Combine

class VideoPlayerCell: UICollectionViewCell {
    static let identifier = "VideoPlayerCell"
    
    // MARK: - Properties
    
    private var cancellables = Set<AnyCancellable>()
    private(set) var metadata: VideoMetadata?
    
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
    
    private lazy var interactionStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var likeButton: InteractionButton = {
        let button = InteractionButton(type: .system)
        button.setImage(UIImage(systemName: "heart.fill"), for: .normal)
        button.addTarget(self, action: #selector(handleLike), for: .touchUpInside)
        return button
    }()
    
    private lazy var commentButton: InteractionButton = {
        let button = InteractionButton(type: .system)
        button.setImage(UIImage(systemName: "bubble.right.fill"), for: .normal)
        button.addTarget(self, action: #selector(handleComment), for: .touchUpInside)
        return button
    }()
    
    private lazy var shareButton: InteractionButton = {
        let button = InteractionButton(type: .system)
        button.setImage(UIImage(systemName: "arrowshape.turn.up.right.fill"), for: .normal)
        button.addTarget(self, action: #selector(handleShare), for: .touchUpInside)
        return button
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
        interactionOverlay.addSubview(interactionStack)
        
        // Add interaction buttons
        [likeButton, commentButton, shareButton].forEach {
            interactionStack.addArrangedSubview($0)
        }
        
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
            
            interactionStack.trailingAnchor.constraint(equalTo: interactionOverlay.trailingAnchor, constant: -16),
            interactionStack.centerYAnchor.constraint(equalTo: interactionOverlay.centerYAnchor),
            interactionStack.widthAnchor.constraint(equalToConstant: 60),
            
            titleLabel.leadingAnchor.constraint(equalTo: interactionOverlay.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: interactionStack.leadingAnchor, constant: -16),
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
        likeButton.setTitle("\(metadata.likes)", for: .normal)
        
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
    
    @objc private func handleLike() {
        guard let metadata = metadata else { return }
        
        Task {
            do {
                try await FeedService.shared.updateLikeCount(videoId: metadata.id, increment: true)
                // Update UI optimistically
                likeButton.setTitle("\(metadata.likes + 1)", for: .normal)
            } catch {
                print("Error updating like count: \(error)")
            }
        }
    }
    
    @objc private func handleComment() {
        // TODO: Show comments overlay
    }
    
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
    }
}

// MARK: - VideoPlayerViewDelegate

extension VideoPlayerCell: VideoPlayerViewDelegate {
    func videoPlayerViewDidTapToTogglePlayback(_ view: VideoPlayerView) {
        // No additional handling needed, the VideoPlayerView handles everything
    }
}

// MARK: - Helper Views

class InteractionButton: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupButton() {
        tintColor = .white
        titleLabel?.font = .systemFont(ofSize: 14)
        
        // Configure content
        contentHorizontalAlignment = .center
        contentVerticalAlignment = .center
        
        // Set content spacing
        let spacing: CGFloat = 4
        titleEdgeInsets = UIEdgeInsets(top: spacing, left: -imageView!.frame.size.width, bottom: -imageView!.frame.size.height, right: 0)
        imageEdgeInsets = UIEdgeInsets(top: -(titleLabel!.frame.size.height + spacing), left: 0, bottom: 0, right: -titleLabel!.frame.size.width)
        
        // Set size
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
        // Don't handle taps on buttons
        if touch.view is UIButton {
            return false
        }
        return true
    }
} 