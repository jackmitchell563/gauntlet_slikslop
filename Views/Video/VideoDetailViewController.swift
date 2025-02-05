import UIKit
import AVKit

/// View controller for displaying detailed video information and playback
class VideoDetailViewController: UIViewController {
    // MARK: - Properties
    
    private let video: VideoMetadata
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    
    // MARK: - UI Components
    
    private lazy var playerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var statsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var creatorButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.addTarget(self, action: #selector(handleCreatorTap), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Initialization
    
    init(video: VideoMetadata) {
        self.video = video
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureVideo()
        loadCreatorInfo()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = playerView.bounds
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player?.pause()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add subviews
        view.addSubview(playerView)
        view.addSubview(titleLabel)
        view.addSubview(creatorButton)
        view.addSubview(statsLabel)
        view.addSubview(descriptionLabel)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.heightAnchor.constraint(equalTo: playerView.widthAnchor, multiplier: 16/9),
            
            titleLabel.topAnchor.constraint(equalTo: playerView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            creatorButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            creatorButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            statsLabel.centerYAnchor.constraint(equalTo: creatorButton.centerYAnchor),
            statsLabel.leadingAnchor.constraint(equalTo: creatorButton.trailingAnchor, constant: 8),
            statsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            descriptionLabel.topAnchor.constraint(equalTo: creatorButton.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    private func configureVideo() {
        // Configure video player
        guard let videoURL = URL(string: video.url) else { return }
        player = AVPlayer(url: videoURL)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspectFill
        playerView.layer.addSublayer(playerLayer!)
        
        // Configure UI
        titleLabel.text = video.title
        descriptionLabel.text = video.description
        statsLabel.text = formatStats()
        
        // Start playback
        player?.play()
    }
    
    private func loadCreatorInfo() {
        Task {
            do {
                let creator = try await ProfileService.shared.getUserProfile(userId: video.creatorId)
                await MainActor.run {
                    creatorButton.setTitle(creator.displayName, for: .normal)
                }
            } catch {
                print("Error loading creator info: \(error)")
            }
        }
    }
    
    private func formatStats() -> String {
        let likes = formatCount(video.stats.likes)
        let comments = formatCount(video.stats.comments)
        return "\(likes) likes • \(comments) comments"
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
    
    // MARK: - Actions
    
    @objc private func handleCreatorTap() {
        let profileVC = ProfileViewController(userId: video.creatorId)
        navigationController?.pushViewController(profileVC, animated: true)
    }
} 