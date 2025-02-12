import UIKit

/// Custom button for displaying gallery access with image count badge
class GalleryButton: UIButton {
    // MARK: - Properties
    
    private let badgeLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .systemRed
        label.textColor = .white
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textAlignment = .center
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupButton() {
        // Configure button appearance
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        let image = UIImage(systemName: "photo.on.rectangle", withConfiguration: config)
        setImage(image, for: .normal)
        tintColor = .label
        
        // Add badge label
        addSubview(badgeLabel)
        
        NSLayoutConstraint.activate([
            badgeLabel.topAnchor.constraint(equalTo: topAnchor, constant: -5),
            badgeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 5),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
            badgeLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    // MARK: - Public Methods
    
    /// Updates the badge count
    /// - Parameter count: Number of images to display in badge
    func updateBadgeCount(_ count: Int) {
        badgeLabel.text = count > 99 ? "99+" : "\(count)"
        badgeLabel.isHidden = count == 0
        
        // Ensure minimum width for single digits
        if count < 10 {
            badgeLabel.widthAnchor.constraint(equalToConstant: 20).isActive = true
        }
    }
} 