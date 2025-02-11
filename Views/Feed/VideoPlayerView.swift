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
    private var iconFadeWorkItem: DispatchWorkItem?
    private var isFirstCell = false
    private var originalURL: URL?
    
    /// Quality levels for video playback
    // Remove internal VideoQuality enum and use the shared one
    
    /// Video loading states
    private enum VideoLoadingState: Equatable {
        case initial
        case loading
        case playing
        case paused
        case error(Error)
        
        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }
        
        var isError: Bool {
            if case .error = self { return true }
            return false
        }
        
        // Implement Equatable manually since Error doesn't conform to Equatable
        static func == (lhs: VideoLoadingState, rhs: VideoLoadingState) -> Bool {
            switch (lhs, rhs) {
            case (.initial, .initial):
                return true
            case (.loading, .loading):
                return true
            case (.playing, .playing):
                return true
            case (.paused, .paused):
                return true
            case (.error, .error):
                // Consider errors equal for comparison purposes
                return true
            default:
                return false
            }
        }
    }
    
    /// Current loading state
    private var loadingState: VideoLoadingState = .initial {
        didSet {
            updateUIForLoadingState()
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
    
    // MARK: - UI Components
    
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
    
    private lazy var errorView: UIView = {
        let view = UIView()
        view.isHidden = true
        view.backgroundColor = .black.withAlphaComponent(0.7)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Retry", for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(handleRetry), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
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
        addSubview(errorView)
        
        errorView.addSubview(errorLabel)
        errorView.addSubview(retryButton)
        
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
            playPauseIcon.heightAnchor.constraint(equalToConstant: 30),
            
            errorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            errorView.topAnchor.constraint(equalTo: topAnchor),
            errorView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            errorLabel.centerXAnchor.constraint(equalTo: errorView.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: errorView.centerYAnchor, constant: -20),
            errorLabel.leadingAnchor.constraint(equalTo: errorView.leadingAnchor, constant: 20),
            errorLabel.trailingAnchor.constraint(equalTo: errorView.trailingAnchor, constant: -20),
            
            retryButton.centerXAnchor.constraint(equalTo: errorView.centerXAnchor),
            retryButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 16)
        ])
        
        // Ensure icons are always on top
        iconBackground.layer.zPosition = 999
        playPauseIcon.layer.zPosition = 1000
        errorView.layer.zPosition = 998
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
    
    // MARK: - Configuration
    
    func configure(with url: URL, isFirstCell: Bool = false) {
        print("📹 VideoPlayerView - Configuring with URL: \(url)")
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
            loadingState = .error(NSError(domain: "VideoPlayerView", code: -1, userInfo: [NSLocalizedDescriptionKey: "No URL available"]))
            return
        }
        
        // Check if we should maintain this player
        guard let cell = findParentCell(),
              VideoPlaybackController.shared.shouldMaintainPlayer(for: cell) else {
            print("📹 VideoPlayerView - Cell outside tracking window, skipping player setup")
            return
        }
        
        print("📹 VideoPlayerView - Setting up player with quality: \(quality)")
        
        // Create cache key for this video
        let videoId = url.lastPathComponent
        let cacheKey = VideoCacheKey(videoId: videoId, quality: quality)
        
        // Update loading state
        loadingState = .loading
        loadingIndicator.startAnimating()
        
        // Attempt to load from cache or download
        Task {
            do {
                let playerItem = try await loadVideoFromCacheOrDownload(with: cacheKey, url: url)
                
                await MainActor.run {
                    // Create new player with the item
                    player = AVPlayer(playerItem: playerItem)
                    playerLayer = AVPlayerLayer(player: player)
                    playerLayer?.videoGravity = .resizeAspectFill
                    playerLayer?.frame = bounds
                    
                    // Insert the player layer below all subviews
                    layer.insertSublayer(playerLayer!, at: 0)
                    
                    // Add observers
                    setupObservers(for: playerItem)
                    
                    // Restore previous progress if available
                    if let cell = findParentCell(),
                       let storedProgress = VideoPlaybackController.shared.getStoredProgress(for: cell) {
                        player?.seek(to: storedProgress)
                    }
                    
                    // Set initial state to paused and let VideoPlaybackController handle playback
                    loadingState = .paused
                    loadingIndicator.stopAnimating()
                    
                    // Notify VideoPlaybackController that this cell is ready
                    if let cell = findParentCell() {
                        print("📹 VideoPlayerView - Cell \(cell.tag) ready for playback control")
                        VideoPlaybackController.shared.handleCellReady(cell)
                    }
                }
            } catch {
                print("❌ VideoPlayerView - Failed to setup player: \(error)")
                await MainActor.run {
                    loadingState = .error(error)
                    loadingIndicator.stopAnimating()
                    handleVideoLoadError(error)
                }
            }
        }
    }
    
    private func loadVideoFromCacheOrDownload(
        with key: VideoCacheKey,
        url: URL
    ) async throws -> AVPlayerItem {
        print("📹 VideoPlayerView - Attempting to load video")
        
        do {
            let playerItem = try await VideoCacheService.shared.downloadAndCacheVideo(from: url, for: key)
            print("✅ VideoPlayerView - Successfully loaded video")
            return playerItem
        } catch {
            print("❌ VideoPlayerView - Error loading video: \(error)")
            throw error
        }
    }
    
    private func handleVideoLoadError(_ error: Error) {
        print("❌ VideoPlayerView - Error loading video: \(error)")
        
        let errorMessage: String
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                errorMessage = "No internet connection"
            case .timedOut:
                errorMessage = "Connection timed out"
            default:
                errorMessage = "Failed to load video"
            }
        } else {
            errorMessage = "Failed to load video"
        }
        
        errorLabel.text = errorMessage
        errorView.isHidden = false
        loadingIndicator.stopAnimating()
    }
    
    private func reloadWithCurrentQuality() {
        guard let url = originalURL else { return }
        
        // Store current playback time
        let currentTime = player?.currentTime()
        
        // Store current playback state by checking with controller
        guard let parentCell = findParentCell() else {
            print("❌ VideoPlayerView - Could not find parent cell for quality reload")
            return
        }
        let wasPlaying = VideoPlaybackController.shared.isCurrentlyPlaying(parentCell)
        print("📹 VideoPlayerView - Storing playback state before quality change: \(wasPlaying ? "playing" : "paused")")
        
        // Clean up existing player
        cleanup()
        
        // Setup new player with current quality
        setupPlayerWithQuality(currentQuality)
        
        // Restore playback position and state
        if let time = currentTime {
            player?.seek(to: time)
        }
        if wasPlaying {
            player?.play()
        }
    }
    
    // Helper method to find parent VideoPlayerCell
    private func findParentCell() -> VideoPlayerCell? {
        var current: UIView? = self
        while let view = current {
            if let cell = view as? VideoPlayerCell {
                return cell
            }
            current = view.superview
        }
        return nil
    }
    
    private func setupObservers(for playerItem: AVPlayerItem) {
        // Observe playback status
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.old, .new], context: nil)
        
        // Observe playback end
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(playerDidFinishPlaying),
                                             name: .AVPlayerItemDidPlayToEndTime,
                                             object: playerItem)
        
        // Add periodic time observer to track progress
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, let cell = self.findParentCell() else { return }
            VideoPlaybackController.shared.recordProgress(for: cell, time: time)
        }
    }
    
    // MARK: - Playback Control
    
    /// Gets the current playback time
    func getCurrentTime() -> CMTime? {
        return player?.currentTime()
    }
    
    /// Plays the video
    func play() {
        print("▶️ VideoPlayerView - Playing video")
        // Allow playing from both paused and loading states
        guard case let state = loadingState, state == .paused || state == .loading else {
            print("❌ VideoPlayerView - Cannot play video in current state: \(loadingState)")
            return
        }
        
        // If we're loading, just mark that we should play when ready
        if case .loading = loadingState {
            print("📹 VideoPlayerView - Deferring play until loading completes")
            return
        }
        
        player?.play()
        loadingState = .playing
        showPlayPauseIcon()
    }
    
    /// Pauses the video
    func pause() {
        print("⏸️ VideoPlayerView - Pausing video")
        guard case .playing = loadingState else {
            print("❌ VideoPlayerView - Cannot pause video in current state: \(loadingState)")
            return
        }
        player?.pause()
        loadingState = .paused
        showPlayPauseIcon()
    }
    
    // MARK: - User Interaction
    
    @objc func handleTap() {
        print("👆 VideoPlayerView - Tap detected")
        delegate?.videoPlayerViewDidTapToTogglePlayback(self)
    }
    
    @objc private func handleRetry() {
        print("🔄 VideoPlayerView - Retrying video load")
        errorView.isHidden = true
        
        guard let url = originalURL else {
            print("❌ VideoPlayerView - No URL available for retry")
            return
        }
        
        // Reconfigure with current quality
        setupPlayerWithQuality(currentQuality)
    }
    
    // MARK: - Private Methods
    
    private func updatePlayPauseIcon() {
        guard let parentCell = findParentCell() else {
            print("❌ VideoPlayerView - Could not find parent cell for icon update")
            return
        }
        let isPlaying = VideoPlaybackController.shared.isCurrentlyPlaying(parentCell)
        print("📹 VideoPlayerView - Updating play/pause icon, current state: \(isPlaying ? "playing" : "paused")")
        playPauseIcon.image = UIImage(systemName: isPlaying ? "pause.fill" : "play.fill")?.withRenderingMode(.alwaysTemplate)
    }
    
    private func showPlayPauseIcon() {
        updatePlayPauseIcon()
        
        // Show both the icon and background with animation
        playPauseIcon.alpha = 1.0
        iconBackground.alpha = 1.0
        
        // Hide both the icon and background after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            UIView.animate(withDuration: 0.3) {
                self?.playPauseIcon.alpha = 0.0
                self?.iconBackground.alpha = 0.0
            }
        }
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
                print("📹 VideoPlayerView - Ready to play")
                loadingIndicator.stopAnimating()
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
        print("🔄 VideoPlayerView - Video finished, looping")
        player?.seek(to: .zero)
        player?.play()
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        print("🧹 VideoPlayerView - Cleaning up resources")
        
        // Store final progress before cleanup if within window
        if let cell = findParentCell(),
           VideoPlaybackController.shared.shouldMaintainPlayer(for: cell),
           let currentTime = player?.currentTime() {
            VideoPlaybackController.shared.recordProgress(for: cell, time: currentTime)
        }
        
        // Remove time observer
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        player = nil
        playerLayer = nil
        iconFadeWorkItem?.cancel()
        iconFadeWorkItem = nil
        loadingState = .initial
        
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
    
    private func updateUIForLoadingState() {
        print("📹 VideoPlayerView - State updated to: \(loadingState)")
        switch loadingState {
        case .initial:
            loadingIndicator.stopAnimating()
            errorView.isHidden = true
            
        case .loading:
            loadingIndicator.startAnimating()
            errorView.isHidden = true
            
        case .playing, .paused:
            loadingIndicator.stopAnimating()
            errorView.isHidden = true
            
        case .error(let error):
            handleVideoLoadError(error)
        }
    }
} 