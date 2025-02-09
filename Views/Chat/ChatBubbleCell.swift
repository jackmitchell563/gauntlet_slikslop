import UIKit

/// Cell for displaying chat messages
class ChatBubbleCell: UICollectionViewCell {
    static let identifier = "ChatBubbleCell"
    
    // MARK: - UI Components
    
    private lazy var avatarContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var bubbleView: ChatBubbleView = {
        let view = ChatBubbleView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 24
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private lazy var timestampLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 9)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private var avatarConstraints: [NSLayoutConstraint] = []
    private var bubbleConstraints: [NSLayoutConstraint] = []
    
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
        // Add avatar container and its subviews
        contentView.addSubview(avatarContainer)
        avatarContainer.addSubview(avatarImageView)
        avatarContainer.addSubview(timestampLabel)
        
        // Add bubble view
        contentView.addSubview(bubbleView)
        
        // Setup avatar container constraints
        NSLayoutConstraint.activate([
            avatarContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            avatarContainer.widthAnchor.constraint(equalToConstant: 48),
            
            avatarImageView.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            avatarImageView.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 48),
            avatarImageView.heightAnchor.constraint(equalToConstant: 48),
            
            timestampLabel.topAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: 4),
            timestampLabel.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            timestampLabel.widthAnchor.constraint(equalTo: avatarContainer.widthAnchor),
            timestampLabel.bottomAnchor.constraint(equalTo: avatarContainer.bottomAnchor)
        ])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Remove existing constraints
        NSLayoutConstraint.deactivate(avatarConstraints)
        NSLayoutConstraint.deactivate(bubbleConstraints)
        avatarConstraints.removeAll()
        bubbleConstraints.removeAll()
        
        // Reset images and text
        avatarImageView.image = nil
        timestampLabel.text = nil
        bubbleView.removeFromSuperview()
    }
    
    // MARK: - Configuration
    
    func configure(with message: ChatMessage, profileImageURL: String? = nil) {
        let timestamp = DateFormatter.messageTimestamp.string(from: message.timestamp)
        avatarContainer.isHidden = false
        timestampLabel.text = timestamp
        
        // Remove any existing constraints
        NSLayoutConstraint.deactivate(avatarConstraints)
        NSLayoutConstraint.deactivate(bubbleConstraints)
        avatarConstraints.removeAll()
        bubbleConstraints.removeAll()
        
        bubbleView.removeFromSuperview()
        contentView.addSubview(bubbleView)
        
        if message.sender == .user {
            // User message styling - right aligned
            let avatarConstraint = avatarContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
            avatarConstraints = [avatarConstraint]
            avatarConstraint.isActive = true
            
            // Set user avatar
            if let currentUser = FirebaseConfig.getAuthInstance().currentUser,
               let photoURL = currentUser.photoURL {
                Task {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: photoURL)
                        await MainActor.run {
                            avatarImageView.image = UIImage(data: data)
                        }
                    } catch {
                        print("❌ ChatBubbleCell - Error loading user profile image: \(error)")
                        avatarImageView.image = UIImage(systemName: "person.circle.fill")
                    }
                }
            } else {
                avatarImageView.image = UIImage(systemName: "person.circle.fill")
            }
            
            // Right-aligned bubble
            bubbleConstraints = [
                bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor),
                bubbleView.trailingAnchor.constraint(equalTo: avatarContainer.leadingAnchor, constant: -12),
                bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75),
                bubbleView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor)
            ]
            NSLayoutConstraint.activate(bubbleConstraints)
            
            bubbleView.configure(with: message, isUser: true)
            
        } else {
            // AI message styling - left aligned
            let avatarConstraint = avatarContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
            avatarConstraints = [avatarConstraint]
            avatarConstraint.isActive = true
            
            // Load AI profile image
            if let profileURLString = profileImageURL,
               let profileURL = URL(string: profileURLString) {
                Task {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: profileURL)
                        await MainActor.run {
                            avatarImageView.image = UIImage(data: data)
                        }
                    } catch {
                        print("❌ ChatBubbleCell - Error loading AI profile image: \(error)")
                        avatarImageView.image = UIImage(systemName: "person.circle.fill")
                    }
                }
            } else {
                avatarImageView.image = UIImage(systemName: "person.circle.fill")
            }
            
            // Left-aligned bubble
            bubbleConstraints = [
                bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor),
                bubbleView.leadingAnchor.constraint(equalTo: avatarContainer.trailingAnchor, constant: 12),
                bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75),
                bubbleView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor)
            ]
            NSLayoutConstraint.activate(bubbleConstraints)
            
            bubbleView.configure(with: message, isUser: false)
        }
    }
    
    // MARK: - Size Calculation
    
    static func size(for message: ChatMessage, width: CGFloat) -> CGSize {
        let bubbleSize = ChatBubbleView.size(for: message, width: width * 0.75)  // Use 75% of width
        let avatarHeight: CGFloat = 48 // Avatar height
        let timestampHeight: CGFloat = 20 // Font size (12) + padding
        let totalHeight = max(bubbleSize.height, avatarHeight + timestampHeight + 4) // 4 is spacing between avatar and timestamp
        return CGSize(width: width, height: totalHeight)
    }
}

/// Custom view for chat message bubbles
class ChatBubbleView: UIView {
    // MARK: - Properties
    
    private var message: ChatMessage?
    
    // MARK: - UI Components
    
    private lazy var bubbleBackgroundView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
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
        addSubview(bubbleBackgroundView)
        bubbleBackgroundView.addSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            bubbleBackgroundView.topAnchor.constraint(equalTo: topAnchor),
            bubbleBackgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bubbleBackgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bubbleBackgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            messageLabel.topAnchor.constraint(equalTo: bubbleBackgroundView.topAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleBackgroundView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleBackgroundView.trailingAnchor, constant: -12),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleBackgroundView.bottomAnchor, constant: -8)
        ])
    }
    
    // MARK: - Configuration
    
    func configure(with message: ChatMessage, isUser: Bool) {
        self.message = message
        messageLabel.text = message.text
        bubbleBackgroundView.backgroundColor = isUser ? .systemBlue : .secondarySystemBackground
        messageLabel.textColor = isUser ? .white : .label
    }
    
    // MARK: - Size Calculation
    
    static func size(for message: ChatMessage, width: CGFloat) -> CGSize {
        let messageInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        let availableWidth = width - messageInsets.left - messageInsets.right
        
        let textSize = NSString(string: message.text).boundingRect(
            with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: UIFont.systemFont(ofSize: 16)],
            context: nil
        ).size
        
        let height = ceil(textSize.height) + messageInsets.top + messageInsets.bottom
        return CGSize(width: ceil(textSize.width) + messageInsets.left + messageInsets.right, height: height)
    }
}

// MARK: - Helper Extensions

extension DateFormatter {
    static let messageTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
} 