import UIKit
import AVFoundation

/// A UICollectionViewCell subclass that handles video playback and user interactions
class VideoCell: UICollectionViewCell {
    // MARK: - Properties
    
    private var videoMetadata: VideoMetadata?
    
    // Reuse identifier for the cell
    static let identifier = "VideoCell"
    
    // MARK: - UI Components
    
    private lazy var playerView: VideoPlayerView = {
        let view = VideoPlayerView()
        view.delegate = self
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
        playerView.configure(with: URL(string: metadata.url)!)
        interactionBar.configure(likes: metadata.likes, comments: 0) // TODO: Add comments count to metadata
    }
    
    // MARK: - Playback Control
    
    /// Starts video playback
    func startPlayback() {
        playerView.play()
    }
    
    /// Pauses video playback
    func pausePlayback() {
        playerView.pause()
    }
    
    // MARK: - Memory Management
    
    private func cleanup() {
        playerView.cleanup()
    }
}

// MARK: - VideoPlayerViewDelegate

extension VideoCell: VideoPlayerViewDelegate {
    func videoPlayerViewDidTapToTogglePlayback(_ view: VideoPlayerView) {
        // Additional handling if needed
    }
} 