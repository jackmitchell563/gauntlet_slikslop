import UIKit

/// View for displaying character banner and information
protocol CharacterBannerViewDelegate: AnyObject {
    func characterBannerViewDidTapGallery(_ bannerView: CharacterBannerView)
}

class CharacterBannerView: UIView {
    // MARK: - Properties
    
    private let character: GameCharacter
    private var isImageLoaded = false
    private var relationshipStatus: Int = 0
    weak var delegate: CharacterBannerViewDelegate?
    
    // MARK: - Scaling Properties
    
    private let defaultHeight: CGFloat = 220
    private let compactHeight: CGFloat = 160  // ~27% reduction
    private var heightConstraint: NSLayoutConstraint?
    private var isCompact: Bool = false
    
    // Size constraints that need to be updated
    private var profileContainerWidthConstraint: NSLayoutConstraint?
    private var profileContainerHeightConstraint: NSLayoutConstraint?
    private var profileImageWidthConstraint: NSLayoutConstraint?
    private var profileImageHeightConstraint: NSLayoutConstraint?
    private var relationshipStatusWidthConstraint: NSLayoutConstraint?
    private var relationshipStatusHeightConstraint: NSLayoutConstraint?
    
    // Default sizes
    private let defaultProfileSize: CGFloat = 120
    private let defaultImageSize: CGFloat = 100
    private let compactScale: CGFloat = 0.73
    
    // Spacing constraints
    private var topSpacingConstraint: NSLayoutConstraint?
    private var nameSpacingConstraint: NSLayoutConstraint?
    private var gameSpacingConstraint: NSLayoutConstraint?
    private var relationshipSpacingConstraint: NSLayoutConstraint?
    
    // Default spacing values
    private let defaultTopSpacing: CGFloat = 20
    private let defaultNameSpacing: CGFloat = 4
    private let defaultGameSpacing: CGFloat = 4
    private let defaultRelationshipSpacing: CGFloat = 4
    
    // MARK: - UI Components
    
    private lazy var profileContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var relationshipStatusView: RelationshipStatusView = {
        let view = RelationshipStatusView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFill  // Ensure smooth scaling
        return view
    }()
    
    private lazy var profileImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 50 // Will make a 100x100 circle
        iv.backgroundColor = .secondarySystemBackground
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var gameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var relationshipLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var galleryButton: GalleryButton = {
        let button = GalleryButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(galleryButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Initialization
    
    init(character: GameCharacter) {
        self.character = character
        super.init(frame: .zero)
        setupUI()
        loadProfileImage()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        backgroundColor = .systemBackground
        
        // Add subviews
        addSubview(profileContainerView)
        profileContainerView.addSubview(relationshipStatusView)
        profileContainerView.addSubview(profileImageView)
        profileContainerView.addSubview(loadingIndicator)
        addSubview(nameLabel)
        addSubview(gameLabel)
        addSubview(relationshipLabel)
        addSubview(galleryButton)
        
        // Configure labels
        nameLabel.text = character.name
        gameLabel.text = character.game.rawValue
        
        // Create constraints
        let heightConstraint = heightAnchor.constraint(equalToConstant: defaultHeight)
        let profileContainerWidth = profileContainerView.widthAnchor.constraint(equalToConstant: defaultProfileSize)
        let profileContainerHeight = profileContainerView.heightAnchor.constraint(equalToConstant: defaultProfileSize)
        let profileImageWidth = profileImageView.widthAnchor.constraint(equalToConstant: defaultImageSize)
        let profileImageHeight = profileImageView.heightAnchor.constraint(equalToConstant: defaultImageSize)
        let relationshipStatusWidth = relationshipStatusView.widthAnchor.constraint(equalToConstant: defaultProfileSize)
        let relationshipStatusHeight = relationshipStatusView.heightAnchor.constraint(equalToConstant: defaultProfileSize)
        
        // Store constraints
        self.heightConstraint = heightConstraint
        self.profileContainerWidthConstraint = profileContainerWidth
        self.profileContainerHeightConstraint = profileContainerHeight
        self.profileImageWidthConstraint = profileImageWidth
        self.profileImageHeightConstraint = profileImageHeight
        self.relationshipStatusWidthConstraint = relationshipStatusWidth
        self.relationshipStatusHeightConstraint = relationshipStatusHeight
        
        NSLayoutConstraint.activate([
            // Banner height
            heightConstraint,
            
            // Profile container view
            profileContainerView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            profileContainerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            profileContainerWidth,
            profileContainerHeight,
            
            // Profile image
            profileImageView.centerXAnchor.constraint(equalTo: profileContainerView.centerXAnchor),
            profileImageView.centerYAnchor.constraint(equalTo: profileContainerView.centerYAnchor),
            profileImageWidth,
            profileImageHeight,
            
            // Gallery button
            galleryButton.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            galleryButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            galleryButton.widthAnchor.constraint(equalToConstant: 44),
            galleryButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Labels with tighter spacing
            nameLabel.topAnchor.constraint(equalTo: profileContainerView.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            gameLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            gameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            gameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            relationshipLabel.topAnchor.constraint(equalTo: gameLabel.bottomAnchor, constant: 2),
            relationshipLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            relationshipLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            // Replace the relative constraints with explicit size constraints
            relationshipStatusView.centerXAnchor.constraint(equalTo: profileContainerView.centerXAnchor),
            relationshipStatusView.centerYAnchor.constraint(equalTo: profileContainerView.centerYAnchor),
            relationshipStatusWidth,
            relationshipStatusHeight,
            
            loadingIndicator.centerXAnchor.constraint(equalTo: profileImageView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: profileImageView.centerYAnchor)
        ])
        
        // Start loading animation
        loadingIndicator.startAnimating()
    }
    
    // MARK: - Image Loading
    
    private func loadProfileImage() {
        // Skip if image is already loaded
        guard !isImageLoaded else { return }
        
        Task {
            if let image = await CharacterAssetService.shared.loadProfileImage(for: character) {
                await MainActor.run {
                    // Animate the image appearance
                    UIView.transition(with: self.profileImageView,
                                    duration: 0.3,
                                    options: .transitionCrossDissolve) {
                        self.profileImageView.image = image
                    }
                    
                    // Update UI state
                    self.loadingIndicator.stopAnimating()
                    self.isImageLoaded = true
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Preloads the profile image for this view
    func preloadImage() async {
        guard !isImageLoaded else { return }
        
        if let _ = await CharacterAssetService.shared.loadProfileImage(for: character) {
            print("📱 CharacterBannerView - Successfully preloaded profile for: \(character.name)")
        } else {
            print("❌ CharacterBannerView - Failed to preload profile for: \(character.name)")
        }
    }
    
    func updateRelationshipStatus(_ status: Int) {
        relationshipStatus = status
        relationshipStatusView.relationshipValue = status
        
        // Update relationship label text
        let percentage = Double(status) / 10.0
        let descriptor = RelationshipStatusView.RelationshipDescriptor.from(percentage: percentage)
        relationshipLabel.text = String(format: "%.1f%% - %@", percentage, descriptor.rawValue)
        relationshipLabel.textColor = percentage >= 0 ? .systemGreen : .systemRed
    }
    
    /// Updates the gallery badge count
    /// - Parameter count: Number of images in the gallery
    func updateGalleryCount(_ count: Int) {
        galleryButton.updateBadgeCount(count)
    }
    
    // MARK: - Actions
    
    @objc private func galleryButtonTapped() {
        delegate?.characterBannerViewDidTapGallery(self)
    }
    
    // MARK: - Helper Methods
    
    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        return nil
    }
}

// MARK: - Scaling

extension CharacterBannerView {
    /// Sets the banner view to compact or full size mode
    /// - Parameters:
    ///   - compact: Whether to use compact mode
    ///   - animated: Whether to animate the transition
    func setCompactMode(_ compact: Bool, animated: Bool = true) {
        guard compact != isCompact else { return }
        isCompact = compact
        
        let duration = animated ? 0.3 : 0
        
        // Calculate new sizes
        let containerSize = compact ? defaultProfileSize * compactScale : defaultProfileSize
        let imageSize = compact ? defaultImageSize * compactScale : defaultImageSize
        let newHeight = compact ? compactHeight : defaultHeight
        
        // Update font sizes
        let nameFontSize = compact ? 18.0 : 24.0
        let gameFontSize = compact ? 12.0 : 16.0
        let relationshipFontSize = compact ? 10.0 : 14.0
        
        // Perform updates within animation block
        if animated {
            UIView.animate(withDuration: duration) {
                // Update sizes
                self.heightConstraint?.constant = newHeight
                self.profileContainerWidthConstraint?.constant = containerSize
                self.profileContainerHeightConstraint?.constant = containerSize
                self.profileImageWidthConstraint?.constant = imageSize
                self.profileImageHeightConstraint?.constant = imageSize
                self.relationshipStatusWidthConstraint?.constant = containerSize
                self.relationshipStatusHeightConstraint?.constant = containerSize
                
                // Update fonts
                self.nameLabel.font = .systemFont(ofSize: nameFontSize, weight: .bold)
                self.gameLabel.font = .systemFont(ofSize: gameFontSize)
                self.relationshipLabel.font = .systemFont(ofSize: relationshipFontSize)
                
                // Force layout update
                self.layoutIfNeeded()
            }
        } else {
            // Apply changes immediately
            heightConstraint?.constant = newHeight
            profileContainerWidthConstraint?.constant = containerSize
            profileContainerHeightConstraint?.constant = containerSize
            profileImageWidthConstraint?.constant = imageSize
            profileImageHeightConstraint?.constant = imageSize
            relationshipStatusWidthConstraint?.constant = containerSize
            relationshipStatusHeightConstraint?.constant = containerSize
            
            nameLabel.font = .systemFont(ofSize: nameFontSize, weight: .bold)
            gameLabel.font = .systemFont(ofSize: gameFontSize)
            relationshipLabel.font = .systemFont(ofSize: relationshipFontSize)
            
            layoutIfNeeded()
        }
    }
} 