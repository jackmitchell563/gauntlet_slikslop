import UIKit
import AVFoundation

/// A UICollectionViewCell subclass that handles video playback and user interactions
class VideoCell: UICollectionViewCell {
    // MARK: - Properties
    
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var videoMetadata: VideoMetadata?
    
    // Reuse identifier for the cell
    static let identifier = "VideoCell"
    
    // MARK: - UI Components
    
    private lazy var playerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var interactionBar: VideoInteractionBar = {
        let bar = VideoInteractionBar()
        bar.translatesAutoresizingMaskIntoConstraints = false
        return bar
    }()
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        cleanup()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        contentView.addSubview(playerView)
        contentView.addSubview(interactionBar)
        
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            interactionBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            interactionBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),
            interactionBar.widthAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    // MARK: - Configuration
    
    /// Configures the cell with video metadata and prepares for playback
    /// - Parameter metadata: The metadata for the video to be played
    func configure(with metadata: VideoMetadata) {
        self.videoMetadata = metadata
        setupPlayer(with: URL(string: metadata.url)!)
        interactionBar.configure(likes: metadata.likes, comments: 0) // TODO: Add comments count to metadata
    }
    
    private func setupPlayer(with url: URL) {
        // Clean up any existing player
        cleanup()
        
        // Create new player and layer
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        playerLayer = AVPlayerLayer(player: player)
        
        // Configure player layer
        playerLayer?.videoGravity = .resizeAspectFill
        playerLayer?.frame = contentView.bounds
        playerView.layer.addSublayer(playerLayer!)
        
        // Add observer for video end
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(playerDidFinishPlaying),
                                             name: .AVPlayerItemDidPlayToEndTime,
                                             object: playerItem)
    }
    
    // MARK: - Playback Control
    
    /// Starts video playback
    func startPlayback() {
        player?.play()
    }
    
    /// Pauses video playback
    func pausePlayback() {
        player?.pause()
    }
    
    @objc private func playerDidFinishPlaying() {
        // Loop the video
        player?.seek(to: .zero)
        player?.play()
    }
    
    // MARK: - Memory Management
    
    private func cleanup() {
        // Remove notification observer
        NotificationCenter.default.removeObserver(self)
        
        // Clean up player
        player?.pause()
        player = nil
        
        // Remove player layer
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = contentView.bounds
    }
} 