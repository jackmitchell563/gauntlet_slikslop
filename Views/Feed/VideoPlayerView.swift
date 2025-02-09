import UIKit
import AVFoundation
import Network

protocol VideoPlayerViewDelegate: AnyObject {
    func videoPlayerViewDidTapToTogglePlayback(_ view: VideoPlayerView)
}

class VideoPlayerView: UIView {
    // MARK: - Properties
    
    weak var delegate: VideoPlayerViewDelegate?
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var timeObserver: Any?
    private var isPlaying = false
    private var iconFadeWorkItem: DispatchWorkItem?
    private var isFirstCell = false
    private var originalURL: URL?
    
    /// Quality levels for video playback
    enum VideoQuality {
        case auto    // Automatically determine based on network conditions
        case low     // 480p or lower
        case medium  // 720p
        case high    // Original quality
        
        var maxHeight: Int? {
            switch self {
            case .auto: return nil
            case .low: return 480
            case .medium: return 720
            case .high: return nil
            }
        }
    }
    
    /// Current video quality setting
    private var currentQuality: VideoQuality = .auto {
        didSet {
            if oldValue != currentQuality {
                reloadWithCurrentQuality()
            }
        }
    }
    
    private lazy var tapGesture: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        return gesture
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private lazy var playPauseIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = .white
        imageView.alpha = 0
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var iconBackground: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        view.layer.cornerRadius = 30
        view.alpha = 0
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .black
        addGestureRecognizer(tapGesture)
        
        // Add subviews in order from back to front
        addSubview(loadingIndicator)
        addSubview(iconBackground)
        addSubview(playPauseIcon)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            iconBackground.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconBackground.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconBackground.widthAnchor.constraint(equalToConstant: 60),
            iconBackground.heightAnchor.constraint(equalToConstant: 60),
            
            playPauseIcon.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            playPauseIcon.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            playPauseIcon.widthAnchor.constraint(equalToConstant: 30),
            playPauseIcon.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // Ensure icons are always on top
        iconBackground.layer.zPosition = 999
        playPauseIcon.layer.zPosition = 1000
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
    
    // MARK: - Configuration
    
    func configure(with url: URL, isFirstCell: Bool = false) {
        self.isFirstCell = isFirstCell
        self.originalURL = url
        loadingIndicator.startAnimating()
        
        // Clean up existing player if any
        cleanup()
        
        // Determine initial quality based on network conditions
        determineInitialQuality { [weak self] quality in
            self?.currentQuality = quality
            self?.setupPlayerWithQuality(quality)
        }
    }
    
    private func determineInitialQuality(completion: @escaping (VideoQuality) -> Void) {
        print("📹 VideoPlayerView - Starting quality determination...")
        // Get network conditions using NWPathMonitor
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            monitor.cancel()
            
            DispatchQueue.main.async {
                print("📹 VideoPlayerView - Network status: \(path.status)")
                print("📹 VideoPlayerView - Is expensive: \(path.isExpensive)")
                
                if path.status == .satisfied {
                    switch path.isExpensive {
                    case true:
                        print("📹 VideoPlayerView - Using low quality due to expensive network")
                        completion(.low)
                    case false:
                        print("📹 VideoPlayerView - Using auto quality due to unrestricted network")
                        completion(.auto)
                    }
                } else {
                    print("📹 VideoPlayerView - Using low quality due to poor connectivity")
                    completion(.low)
                }
            }
        }
        monitor.start(queue: .global(qos: .userInitiated))
    }
    
    private func setupPlayerWithQuality(_ quality: VideoQuality) {
        guard let url = originalURL else {
            print("❌ VideoPlayerView - No original URL available")
            return
        }
        
        print("📹 VideoPlayerView - Setting up player with quality: \(quality)")
        
        // Apply quality restrictions if needed
        let finalURL = modifyURLForQuality(url, quality: quality)
        print("📹 VideoPlayerView - Original URL: \(url)")
        print("📹 VideoPlayerView - Modified URL: \(finalURL)")
        
        // Create new player
        let playerItem = AVPlayerItem(url: finalURL)
        player = AVPlayer(playerItem: playerItem)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspectFill
        playerLayer?.frame = bounds
        
        // Insert the player layer below all subviews
        layer.insertSublayer(playerLayer!, at: 0)
        
        // Add observers
        setupObservers(for: playerItem)
    }
    
    private func modifyURLForQuality(_ url: URL, quality: VideoQuality) -> URL {
        guard let maxHeight = quality.maxHeight else {
            return url // Return original URL for auto or high quality
        }
        
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
        
        // Add or modify quality parameter based on URL type
        if url.absoluteString.contains("youtube.com") {
            // YouTube-style quality parameter
            let existingItems = urlComponents?.queryItems ?? []
            let qualityItem = URLQueryItem(name: "quality", value: "hd\(maxHeight)")
            urlComponents?.queryItems = existingItems + [qualityItem]
        } else if url.absoluteString.contains("cloudfront.net") || url.absoluteString.contains("amazonaws.com") {
            // AWS/CloudFront style parameter
            let existingItems = urlComponents?.queryItems ?? []
            let heightItem = URLQueryItem(name: "height", value: String(maxHeight))
            urlComponents?.queryItems = existingItems + [heightItem]
        }
        
        return urlComponents?.url ?? url
    }
    
    private func reloadWithCurrentQuality() {
        guard let url = originalURL else { return }
        
        // Store current playback time
        let currentTime = player?.currentTime()
        
        // Clean up existing player
        cleanup()
        
        // Setup new player with current quality
        setupPlayerWithQuality(currentQuality)
        
        // Restore playback position and state
        if let time = currentTime {
            player?.seek(to: time)
        }
        if isPlaying {
            player?.play()
        }
    }
    
    private func setupObservers(for playerItem: AVPlayerItem) {
        // Observe playback status
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.old, .new], context: nil)
        
        // Observe playback end
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(playerDidFinishPlaying),
                                             name: .AVPlayerItemDidPlayToEndTime,
                                             object: playerItem)
    }
    
    // MARK: - Playback Control
    
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func play() {
        player?.play()
        isPlaying = true
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    private func showPlayPauseIcon(isPlaying: Bool) {
        // Cancel any existing fade out
        iconFadeWorkItem?.cancel()
        
        // Update icon - now showing the action that was just taken
        playPauseIcon.image = UIImage(systemName: isPlaying ? "play.fill" : "pause.fill")?.withRenderingMode(.alwaysTemplate)
        
        // Show icon with animation
        UIView.animate(withDuration: 0.2) {
            self.playPauseIcon.alpha = 1
            self.iconBackground.alpha = 1
        }
        
        // Schedule fade out
        let workItem = DispatchWorkItem { [weak self] in
            UIView.animate(withDuration: 0.2) {
                self?.playPauseIcon.alpha = 0
                self?.iconBackground.alpha = 0
            }
        }
        iconFadeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
    }
    
    // MARK: - Gesture Handling
    
    @objc func handleTap() {
        togglePlayback()
        showPlayPauseIcon(isPlaying: isPlaying)
        delegate?.videoPlayerViewDidTapToTogglePlayback(self)
    }
    
    // MARK: - Observer Handling
    
    override func observeValue(forKeyPath keyPath: String?,
                             of object: Any?,
                             change: [NSKeyValueChangeKey : Any]?,
                             context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }
            
            print("📹 VideoPlayerView - Player status changed to: \(status)")
            
            switch status {
            case .readyToPlay:
                print("📹 VideoPlayerView - Ready to play, isFirstCell: \(isFirstCell)")
                loadingIndicator.stopAnimating()
                if isFirstCell {
                    print("📹 VideoPlayerView - Auto-playing first cell")
                    play()
                }
            case .failed:
                if let error = player?.currentItem?.error {
                    print("❌ VideoPlayerView - Failed to load video: \(error)")
                } else {
                    print("❌ VideoPlayerView - Failed to load video with unknown error")
                }
            case .unknown:
                print("❓ VideoPlayerView - Unknown player status")
            @unknown default:
                print("❓ VideoPlayerView - Unhandled player status")
                break
            }
        }
    }
    
    @objc private func playerDidFinishPlaying() {
        // Loop the video
        player?.seek(to: .zero)
        player?.play()
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        pause()
        playerLayer?.removeFromSuperlayer()
        player = nil
        playerLayer = nil
        iconFadeWorkItem?.cancel()
        iconFadeWorkItem = nil
        
        if let playerItem = player?.currentItem {
            playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        }
        
        NotificationCenter.default.removeObserver(self)
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Quality Control
    
    /// Changes the video quality
    /// - Parameter quality: The desired quality level
    func setQuality(_ quality: VideoQuality) {
        currentQuality = quality
    }
    
    /// Gets the current video quality
    /// - Returns: The current quality setting
    func getCurrentQuality() -> VideoQuality {
        return currentQuality
    }
} 