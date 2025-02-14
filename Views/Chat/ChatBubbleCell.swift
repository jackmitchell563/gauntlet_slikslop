import UIKit

/// Cell for displaying chat messages
class ChatBubbleCell: UICollectionViewCell {
    static let identifier = "ChatBubbleCell"
    
    // MARK: - Properties
    
    private var message: ChatMessage?
    private var loadingSpinner: UIActivityIndicatorView?
    private var errorIcon: UIImageView?
    
    // MARK: - UI Components
    
    private let bubbleView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 20
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var audioButton: AudioButton = {
        let button = AudioButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.addSubview(avatarImageView)
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(messageLabel)
        contentView.addSubview(audioButton)
        
        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            avatarImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            avatarImageView.widthAnchor.constraint(equalToConstant: 40),
            avatarImageView.heightAnchor.constraint(equalToConstant: 40),
            
            bubbleView.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 8),
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -8),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),
            
            audioButton.topAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: 4),
            audioButton.centerXAnchor.constraint(equalTo: avatarImageView.centerXAnchor),
            audioButton.widthAnchor.constraint(equalToConstant: 32),
            audioButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    // MARK: - Configuration
    
    func configure(with message: ChatMessage, profileImageURL: String? = nil) {
        self.message = message
        
        // Set text
        messageLabel.text = message.text
        
        // Configure audio button visibility based on message properties
        audioButton.isHidden = message.sender == .user || !message.audioAvailable
        if !audioButton.isHidden {
            audioButton.addTarget(self, action: #selector(handleAudioButtonTap), for: .touchUpInside)
        }
        
        // Add observer for audio generation completion
        if message.sender == .character {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAudioGenerated(_:)),
                name: FishAudioService.audioGenerationCompleted,
                object: nil
            )
        }
        
        // Style based on sender
        if message.sender == .user {
            bubbleView.backgroundColor = .systemBlue
            messageLabel.textColor = .white
            
            // Load user avatar
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
        } else {
            bubbleView.backgroundColor = .secondarySystemBackground
            messageLabel.textColor = .label
            
            // Load character avatar
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
        }
    }
    
    @objc private func handleAudioGenerated(_ notification: Notification) {
        guard let messageId = notification.userInfo?["messageId"] as? String,
              let message = self.message,
              messageId == message.id else {
            return
        }
        
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            self?.message?.audioAvailable = true
            self?.audioButton.isHidden = false
            self?.audioButton.addTarget(self, action: #selector(self?.handleAudioButtonTap), for: .touchUpInside)
        }
    }
    
    // MARK: - Actions
    
    @objc private func handleAudioButtonTap() {
        guard let message = message,
              let character = message.character else {
            return
        }
        
        do {
            let audioURL = try StableDiffusionService.shared.getAudioStorageURL(for: character)
                .appendingPathComponent("\(message.id).mp3")
            audioButton.playAudio(url: audioURL)
        } catch {
            print("❌ ChatBubbleCell - Error playing audio: \(error)")
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        message = nil
        messageLabel.text = nil
        avatarImageView.image = nil
        audioButton.stopAudio()
        audioButton.isHidden = true
        // Remove any observers
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Size Calculation
    
    static func size(for message: ChatMessage, width: CGFloat) -> CGSize {
        // Fixed margins and spacing
        let avatarWidth: CGFloat = 40
        let horizontalMargins: CGFloat = 36 // 8 + 8 + 12 + 8
        let verticalMargins: CGFloat = 32 // 8 + 8 + 8 + 8
        let audioButtonHeight: CGFloat = message.sender == .character ? 36 : 0 // Height for audio button if character message
        
        // Available width for text
        let maxTextWidth = width - avatarWidth - horizontalMargins
        
        // Create layout manager to calculate lines
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude))
        let textStorage = NSTextStorage(string: message.text, attributes: [.font: UIFont.systemFont(ofSize: 16)])
        
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        // Make sure the layout manager lays out the text
        layoutManager.ensureLayout(for: textContainer)
        
        // Calculate number of lines and total height
        var lineCount = 0
        var lastLineIndex = 0
        
        while layoutManager.lineFragmentRect(forGlyphAt: lastLineIndex, effectiveRange: nil, withoutAdditionalLayout: true).maxY > 0 {
            lineCount += 1
            lastLineIndex = layoutManager.glyphIndexForCharacter(at: lastLineIndex + 1)
            if lastLineIndex >= layoutManager.numberOfGlyphs {
                break
            }
        }
        
        let textRect = layoutManager.usedRect(for: textContainer)
        let height = ceil(textRect.height) + verticalMargins + audioButtonHeight // might need to change this
        
        return CGSize(width: width, height: max(height, 56)) // Minimum height of 56
    }
}

// MARK: - Layout Configuration

extension NSAttributedString {
    struct LayoutConfig {
        let font: UIFont
        let paragraphStyle: NSParagraphStyle
        let messagePadding: UIEdgeInsets
        var maxWidth: CGFloat?
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