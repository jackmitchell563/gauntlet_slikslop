import UIKit

/// Cell for displaying chat messages
class ChatBubbleCell: UICollectionViewCell {
    static let identifier = "ChatBubbleCell"
    
    // MARK: - Properties
    
    private var loadingSpinner: UIActivityIndicatorView?
    private var errorIcon: UIImageView?
    
    // MARK: - UI Components
    
    private lazy var avatarContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var contentContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var bubbleView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 16
        iv.isHidden = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
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
    private var contentConstraints: [NSLayoutConstraint] = []
    
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
        
        // Add content container and its subviews
        contentView.addSubview(contentContainer)
        contentContainer.addArrangedSubview(bubbleView)
        bubbleView.addSubview(messageLabel)
        contentContainer.addArrangedSubview(imageView)
        
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
            timestampLabel.bottomAnchor.constraint(equalTo: avatarContainer.bottomAnchor),
            
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),
            
            imageView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Remove existing constraints
        NSLayoutConstraint.deactivate(avatarConstraints)
        NSLayoutConstraint.deactivate(contentConstraints)
        avatarConstraints.removeAll()
        contentConstraints.removeAll()
        
        // Reset images and text
        avatarImageView.image = nil
        imageView.image = nil
        timestampLabel.text = nil
        messageLabel.text = nil
        imageView.isHidden = true
        
        // Remove loading states
        loadingSpinner?.removeFromSuperview()
        loadingSpinner = nil
        errorIcon?.removeFromSuperview()
        errorIcon = nil
    }
    
    // MARK: - Configuration
    
    func configure(with message: ChatMessage, profileImageURL: String? = nil) {
        let timestamp = DateFormatter.messageTimestamp.string(from: message.timestamp)
        avatarContainer.isHidden = false
        timestampLabel.text = timestamp
        
        // Remove any existing constraints
        NSLayoutConstraint.deactivate(avatarConstraints)
        NSLayoutConstraint.deactivate(contentConstraints)
        avatarConstraints.removeAll()
        contentConstraints.removeAll()
        
        if message.sender == .user {
            // User message styling - right aligned
            avatarConstraints = [
                avatarContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
            ]
            
            contentConstraints = [
                contentContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
                contentContainer.trailingAnchor.constraint(equalTo: avatarContainer.leadingAnchor, constant: -12),
                contentContainer.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75),
                contentContainer.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor)
            ]
            
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
            
            // Style bubble
            bubbleView.backgroundColor = .systemBlue
            messageLabel.textColor = .white
            
        } else {
            // AI message styling - left aligned
            avatarConstraints = [
                avatarContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
            ]
            
            contentConstraints = [
                contentContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
                contentContainer.leadingAnchor.constraint(equalTo: avatarContainer.trailingAnchor, constant: 12),
                contentContainer.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75),
                contentContainer.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor)
            ]
            
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
            
            // Style bubble
            bubbleView.backgroundColor = .secondarySystemBackground
            messageLabel.textColor = .label
        }
        
        // Activate constraints
        NSLayoutConstraint.activate(avatarConstraints)
        NSLayoutConstraint.activate(contentConstraints)
        
        // Configure message content
        messageLabel.text = message.text
        
        // Handle image if present
        if message.type == .textWithImage {
            imageView.isHidden = false
            
            if let status = message.imageGenerationStatus {
                switch status {
                case .queued:
                    showLoadingState(message: "Queued...")
                case .generating:
                    showLoadingState(message: "Generating...")
                case .completed:
                    if let imageURL = message.imageURL {
                        loadImage(from: imageURL)
                    }
                case .failed:
                    showErrorState()
                }
            }
        } else {
            imageView.isHidden = true
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadImage(from url: URL) {
        Task {
            do {
                let image = try await ImageCacheService.shared.getImage(from: url)
                await MainActor.run {
                    imageView.image = image
                    loadingSpinner?.removeFromSuperview()
                    loadingSpinner = nil
                }
            } catch {
                print("❌ ChatBubbleCell - Error loading image: \(error)")
                showErrorState()
            }
        }
    }
    
    private func showLoadingState(message: String) {
        loadingSpinner?.removeFromSuperview()
        
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        imageView.addSubview(spinner)
        
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: imageView.centerYAnchor)
        ])
        
        loadingSpinner = spinner
    }
    
    private func showErrorState() {
        loadingSpinner?.removeFromSuperview()
        loadingSpinner = nil
        
        let errorImage = UIImage(systemName: "exclamationmark.triangle.fill")
        let imageView = UIImageView(image: errorImage)
        imageView.tintColor = .systemRed
        imageView.translatesAutoresizingMaskIntoConstraints = false
        self.imageView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: self.imageView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: self.imageView.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 32),
            imageView.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        errorIcon = imageView
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
        
        var height = ceil(textSize.height) + messageInsets.top + messageInsets.bottom
        
        // Add height for image if needed
        if message.type == .textWithImage {
            height += 208  // 200 for image + 8 for spacing
        }
        
        // Add height for timestamp
        height += 24  // Avatar height (48) + timestamp spacing (4) = 72 total for avatar container
        
        return CGSize(width: ceil(textSize.width) + messageInsets.left + messageInsets.right, height: height)
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