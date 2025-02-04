import UIKit
import AVFoundation

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
        loadingIndicator.startAnimating()
        
        // Clean up existing player if any
        cleanup()
        
        // Create new player
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspectFill
        playerLayer?.frame = bounds
        
        // Insert the player layer below all subviews
        layer.insertSublayer(playerLayer!, at: 0)
        
        // Add observers
        setupObservers(for: playerItem)
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
            
            switch status {
            case .readyToPlay:
                loadingIndicator.stopAnimating()
                if isFirstCell {
                    play()
                }
            case .failed:
                print("Failed to load video")
            case .unknown:
                print("Unknown player status")
            @unknown default:
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
} 