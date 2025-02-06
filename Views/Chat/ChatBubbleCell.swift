import UIKit

/// Cell for displaying chat messages
class ChatBubbleCell: UICollectionViewCell {
    static let identifier = "ChatBubbleCell"
    
    // MARK: - UI Components
    
    private lazy var bubbleView: ChatBubbleView = {
        let view = ChatBubbleView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var timestampLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
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
        contentView.addSubview(bubbleView)
        contentView.addSubview(timestampLabel)
        
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor),
            bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            timestampLabel.topAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: 4),
            timestampLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor),
            timestampLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    // MARK: - Configuration
    
    func configure(with message: ChatMessage) {
        bubbleView.configure(with: message)
        timestampLabel.text = DateFormatter.messageTimestamp.string(from: message.timestamp)
        
        // Align timestamp based on sender
        if message.sender == .user {
            timestampLabel.textAlignment = .right
        } else {
            timestampLabel.textAlignment = .left
        }
    }
    
    // MARK: - Size Calculation
    
    static func size(for message: ChatMessage, width: CGFloat) -> CGSize {
        let bubbleSize = ChatBubbleView.size(for: message, width: width)
        return CGSize(width: width, height: bubbleSize.height + 24) // Add space for timestamp
    }
}

/// Custom view for chat message bubbles
class ChatBubbleView: UIView {
    // MARK: - Properties
    
    private var message: ChatMessage?
    
    // MARK: - UI Components
    
    private lazy var avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 16
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
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
        addSubview(avatarImageView)
        addSubview(bubbleBackgroundView)
        bubbleBackgroundView.addSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            avatarImageView.topAnchor.constraint(equalTo: topAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 32),
            avatarImageView.heightAnchor.constraint(equalToConstant: 32),
            
            messageLabel.topAnchor.constraint(equalTo: bubbleBackgroundView.topAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleBackgroundView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleBackgroundView.trailingAnchor, constant: -12),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleBackgroundView.bottomAnchor, constant: -8)
        ])
    }
    
    // MARK: - Configuration
    
    func configure(with message: ChatMessage) {
        self.message = message
        messageLabel.text = message.text
        
        if message.sender == .user {
            // User message styling
            avatarImageView.isHidden = true
            bubbleBackgroundView.backgroundColor = .systemBlue
            messageLabel.textColor = .white
            
            // Right-aligned constraints
            NSLayoutConstraint.activate([
                bubbleBackgroundView.topAnchor.constraint(equalTo: topAnchor),
                bubbleBackgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
                bubbleBackgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
                bubbleBackgroundView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.75)
            ])
        } else {
            // Character message styling
            avatarImageView.isHidden = false
            bubbleBackgroundView.backgroundColor = .secondarySystemBackground
            messageLabel.textColor = .label
            
            // Left-aligned constraints with avatar
            NSLayoutConstraint.activate([
                avatarImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
                bubbleBackgroundView.topAnchor.constraint(equalTo: topAnchor),
                bubbleBackgroundView.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 8),
                bubbleBackgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
                bubbleBackgroundView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.75)
            ])
        }
        
        setNeedsLayout()
    }
    
    // MARK: - Size Calculation
    
    static func size(for message: ChatMessage, width: CGFloat) -> CGSize {
        let maxBubbleWidth = width * 0.75
        let messageInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        
        let maxTextWidth = maxBubbleWidth - messageInsets.left - messageInsets.right
        let textSize = NSString(string: message.text).boundingRect(
            with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: UIFont.systemFont(ofSize: 16)],
            context: nil
        ).size
        
        let bubbleHeight = ceil(textSize.height) + messageInsets.top + messageInsets.bottom
        return CGSize(width: width, height: bubbleHeight)
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