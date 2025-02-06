import UIKit

/// View for displaying character banner and information
class CharacterBannerView: UIView {
    // MARK: - Properties
    
    private let character: GameCharacter
    
    // MARK: - UI Components
    
    private lazy var bannerImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .secondarySystemBackground
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private lazy var gradientOverlay: CAGradientLayer = {
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.black.withAlphaComponent(0.7).cgColor,
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.7).cgColor
        ]
        gradient.locations = [0, 0.5, 1]
        return gradient
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var gameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textColor = .white.withAlphaComponent(0.8)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    
    init(character: GameCharacter) {
        self.character = character
        super.init(frame: .zero)
        setupUI()
        loadBannerImage()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Add subviews
        addSubview(bannerImageView)
        layer.addSublayer(gradientOverlay)
        addSubview(nameLabel)
        addSubview(gameLabel)
        
        // Configure labels
        nameLabel.text = character.name
        gameLabel.text = character.game.rawValue
        
        // Setup constraints
        NSLayoutConstraint.activate([
            bannerImageView.topAnchor.constraint(equalTo: topAnchor),
            bannerImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bannerImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bannerImageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            nameLabel.bottomAnchor.constraint(equalTo: gameLabel.topAnchor, constant: -4),
            
            gameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            gameLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientOverlay.frame = bounds
    }
    
    // MARK: - Image Loading
    
    private func loadBannerImage() {
        CharacterAssetService.shared.getBannerImage(for: character) { [weak self] image in
            self?.bannerImageView.image = image
        }
    }
} 