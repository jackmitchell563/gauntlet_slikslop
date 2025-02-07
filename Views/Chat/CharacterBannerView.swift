import UIKit

/// View for displaying character banner and information
class CharacterBannerView: UIView {
    // MARK: - Properties
    
    private let character: GameCharacter
    private var isImageLoaded = false
    
    // MARK: - UI Components
    
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
        addSubview(profileImageView)
        addSubview(loadingIndicator)
        addSubview(nameLabel)
        addSubview(gameLabel)
        
        // Configure labels
        nameLabel.text = character.name
        gameLabel.text = character.game.rawValue
        
        // Setup constraints
        NSLayoutConstraint.activate([
            profileImageView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            profileImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 100),
            profileImageView.heightAnchor.constraint(equalToConstant: 100),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: profileImageView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: profileImageView.centerYAnchor),
            
            nameLabel.topAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            gameLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            gameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            gameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            gameLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
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
} 