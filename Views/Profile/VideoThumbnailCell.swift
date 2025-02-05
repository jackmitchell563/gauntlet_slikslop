import UIKit

/// Collection view cell for displaying video thumbnails in profile grid
class VideoThumbnailCell: UICollectionViewCell {
    // MARK: - Properties
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.alpha = self.isHighlighted ? 0.7 : 1.0
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            }
        }
    }
    
    // MARK: - UI Components
    
    private lazy var thumbnailImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .systemGray6
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isUserInteractionEnabled = true
        return iv
    }()
    
    private lazy var statsOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var likeIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "heart.fill")
        iv.tintColor = .white
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private lazy var likeCountLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var playIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "play.fill")
        iv.tintColor = .white
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        contentView.isUserInteractionEnabled = true
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.image = nil
        likeCountLabel.text = nil
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        contentView.addSubview(thumbnailImageView)
        contentView.addSubview(statsOverlay)
        statsOverlay.addSubview(likeIcon)
        statsOverlay.addSubview(likeCountLabel)
        contentView.addSubview(playIcon)
        
        NSLayoutConstraint.activate([
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            statsOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            statsOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            statsOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            statsOverlay.heightAnchor.constraint(equalToConstant: 24),
            
            likeIcon.leadingAnchor.constraint(equalTo: statsOverlay.leadingAnchor, constant: 4),
            likeIcon.centerYAnchor.constraint(equalTo: statsOverlay.centerYAnchor),
            likeIcon.widthAnchor.constraint(equalToConstant: 12),
            likeIcon.heightAnchor.constraint(equalToConstant: 12),
            
            likeCountLabel.leadingAnchor.constraint(equalTo: likeIcon.trailingAnchor, constant: 2),
            likeCountLabel.centerYAnchor.constraint(equalTo: statsOverlay.centerYAnchor),
            
            playIcon.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            playIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            playIcon.widthAnchor.constraint(equalToConstant: 24),
            playIcon.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    // MARK: - Configuration
    
    func configure(with video: VideoMetadata) {
        likeCountLabel.text = formatCount(video.stats.likes)
        
        Task {
            await loadThumbnail(from: video.thumbnail)
        }
    }
    
    private func loadThumbnail(from urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    thumbnailImageView.image = image
                }
            }
        } catch {
            print("Error loading thumbnail: \(error)")
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
} 