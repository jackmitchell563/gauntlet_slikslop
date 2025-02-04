import UIKit

/// Protocol for handling video interactions
protocol VideoInteractionDelegate: AnyObject {
    func didTapLike(for videoId: String)
    func didTapComment(for videoId: String)
}

/// Custom view for video interaction buttons (likes, comments)
class VideoInteractionBar: UIView {
    // MARK: - Properties
    
    weak var delegate: VideoInteractionDelegate?
    private var videoId: String?
    
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
        let button = createInteractionButton(icon: "heart.fill")
        button.addTarget(self, action: #selector(handleLike), for: .touchUpInside)
        return button
    }()
    
    private lazy var commentButton: UIButton = {
        let button = createInteractionButton(icon: "bubble.right.fill")
        button.addTarget(self, action: #selector(handleComment), for: .touchUpInside)
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
        
        container.addSubview(button)
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44),
            
            label.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 4),
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    // MARK: - Configuration
    
    /// Configures the interaction bar with video metadata
    /// - Parameters:
    ///   - likes: Number of likes
    ///   - comments: Number of comments
    func configure(likes: Int, comments: Int) {
        likeCountLabel.text = formatCount(likes)
        commentCountLabel.text = formatCount(comments)
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
        guard let videoId = videoId else { return }
        delegate?.didTapLike(for: videoId)
        
        // Animate button
        UIView.animate(withDuration: 0.1, animations: {
            self.likeButton.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.likeButton.transform = .identity
            }
        }
    }
    
    @objc private func handleComment() {
        guard let videoId = videoId else { return }
        delegate?.didTapComment(for: videoId)
    }
} 