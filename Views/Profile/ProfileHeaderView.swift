import UIKit

protocol ProfileHeaderDelegate: AnyObject {
    func didTapFollow()
}

/// Header view for profile displaying user information and stats
class ProfileHeaderView: UIView {
    // MARK: - Properties
    
    weak var delegate: ProfileHeaderDelegate?
    private var isFollowing = false
    private var isCurrentUser = false
    private var profile: UserProfile?
    
    // MARK: - UI Components
    
    private lazy var avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.layer.cornerRadius = 40
        iv.clipsToBounds = true
        iv.backgroundColor = .systemGray5
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var bioLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var statsView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.spacing = 80
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var followButton: UIButton = {
        let button = UIButton(type: .system)
        button.layer.cornerRadius = 22
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.addTarget(self, action: #selector(handleFollowTap), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
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
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .systemBackground
        
        // Add subviews
        addSubview(avatarImageView)
        addSubview(nameLabel)
        addSubview(bioLabel)
        addSubview(statsView)
        addSubview(followButton)
        
        // Add stats items
        ["Followers", "Following", "Likes"].forEach { title in
            let item = createStatsItem(title: title)
            statsView.addArrangedSubview(item)
        }
        
        // Setup constraints
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 280),
            
            avatarImageView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            avatarImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 80),
            avatarImageView.heightAnchor.constraint(equalToConstant: 80),
            
            nameLabel.topAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            bioLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            bioLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            bioLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            statsView.topAnchor.constraint(equalTo: bioLabel.bottomAnchor, constant: 16),
            statsView.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            followButton.topAnchor.constraint(equalTo: statsView.bottomAnchor, constant: 16),
            followButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            followButton.widthAnchor.constraint(equalToConstant: 150),
            followButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func createStatsItem(title: String) -> UIView {
        let container = UIView()
        
        let countLabel = UILabel()
        countLabel.font = .systemFont(ofSize: 20, weight: .bold)
        countLabel.textAlignment = .center
        countLabel.tag = 1 // Tag for later access
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(countLabel)
        container.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            countLabel.topAnchor.constraint(equalTo: container.topAnchor),
            countLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 4),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    // MARK: - Configuration
    
    /// Configures the header view with user profile data
    /// - Parameters:
    ///   - profile: UserProfile to display
    ///   - followerCount: Number of followers
    ///   - followingCount: Number of users being followed
    ///   - isFollowing: Whether the current user is following this profile
    func configure(
        with profile: UserProfile,
        followerCount: Int,
        followingCount: Int,
        isFollowing: Bool
    ) {
        self.profile = profile
        self.isFollowing = isFollowing
        self.isCurrentUser = profile.id == AuthService.shared.currentUserId
        
        nameLabel.text = profile.displayName
        bioLabel.text = profile.bio
        
        // Update stats
        updateStats(
            followers: followerCount,
            following: followingCount,
            likes: profile.totalLikes
        )
        
        // Update follow button state
        updateFollowButtonAppearance()
        
        // Load profile image if available
        if let photoURL = profile.photoURL {
            Task {
                await loadProfileImage(from: photoURL)
            }
        } else {
            avatarImageView.image = UIImage(systemName: "person.circle.fill")
            avatarImageView.tintColor = .systemGray3
        }
    }
    
    /// Updates the stats display
    /// - Parameters:
    ///   - followers: Number of followers
    ///   - following: Number of users being followed
    ///   - likes: Total number of likes
    private func updateStats(followers: Int, following: Int, likes: Int) {
        let stats = [
            ("Followers", followers),
            ("Following", following),
            ("Likes", likes)
        ]
        
        for (index, (title, count)) in stats.enumerated() {
            let statView = statsView.arrangedSubviews[index]
            if let countLabel = statView.viewWithTag(1) as? UILabel {
                countLabel.text = formatCount(count)
            }
        }
    }
    
    private func loadProfileImage(from urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    avatarImageView.image = image
                }
            }
        } catch {
            print("Error loading profile image: \(error)")
            await MainActor.run {
                avatarImageView.image = UIImage(systemName: "person.circle.fill")
                avatarImageView.tintColor = .systemGray3
            }
        }
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
    
    private func updateFollowButtonAppearance() {
        if isCurrentUser {
            followButton.setTitle("Edit Profile", for: .normal)
            followButton.backgroundColor = .systemGray5
            followButton.setTitleColor(.label, for: .normal)
        } else {
            followButton.setTitle(isFollowing ? "Following" : "Follow", for: .normal)
            followButton.backgroundColor = isFollowing ? .systemGray5 : .systemPink
            followButton.setTitleColor(isFollowing ? .label : .white, for: .normal)
        }
    }
    
    // MARK: - Actions
    
    @objc private func handleFollowTap() {
        guard !isCurrentUser else {
            // TODO: Handle edit profile
            return
        }
        
        isFollowing.toggle()
        updateFollowButtonAppearance()
        delegate?.didTapFollow()
    }
} 