import UIKit

/// View for displaying character banner and information
class CharacterBannerView: UIView {
    // MARK: - Properties
    
    private let character: GameCharacter
    private var isImageLoaded = false
    private var relationshipStatus: Int = 0
    
    // MARK: - UI Components
    
    private lazy var profileContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var relationshipStatusView: RelationshipStatusView = {
        let view = RelationshipStatusView()
        view.translatesAutoresizingMaskIntoConstraints = false
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
        
        // Configure labels
        nameLabel.text = character.name
        gameLabel.text = character.game.rawValue
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Profile container view
            profileContainerView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            profileContainerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            profileContainerView.widthAnchor.constraint(equalToConstant: 120),  // Larger to accommodate relationship circle
            profileContainerView.heightAnchor.constraint(equalToConstant: 120),
            
            // Relationship status view (larger circle)
            relationshipStatusView.centerXAnchor.constraint(equalTo: profileContainerView.centerXAnchor),
            relationshipStatusView.centerYAnchor.constraint(equalTo: profileContainerView.centerYAnchor),
            relationshipStatusView.widthAnchor.constraint(equalTo: profileContainerView.widthAnchor),
            relationshipStatusView.heightAnchor.constraint(equalTo: profileContainerView.heightAnchor),
            
            // Profile image view (smaller circle)
            profileImageView.centerXAnchor.constraint(equalTo: profileContainerView.centerXAnchor),
            profileImageView.centerYAnchor.constraint(equalTo: profileContainerView.centerYAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 100),
            profileImageView.heightAnchor.constraint(equalToConstant: 100),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: profileImageView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: profileImageView.centerYAnchor),
            
            nameLabel.topAnchor.constraint(equalTo: profileContainerView.bottomAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            gameLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            gameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            gameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            relationshipLabel.topAnchor.constraint(equalTo: gameLabel.bottomAnchor, constant: 4),
            relationshipLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            relationshipLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            relationshipLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
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
} 