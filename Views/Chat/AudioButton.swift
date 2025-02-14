import UIKit
import AVFoundation

/// Custom button for audio playback with visual feedback
class AudioButton: UIButton {
    // MARK: - Properties
    
    private var audioPlayer: AVAudioPlayer?
    private let playImage = UIImage(systemName: "speaker.wave.2")
    private let stopImage = UIImage(systemName: "speaker.slash")
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    
    private var isLoading: Bool = false {
        didSet {
            isLoading ? loadingIndicator.startAnimating() : loadingIndicator.stopAnimating()
            imageView?.isHidden = isLoading
        }
    }
    
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
        setImage(playImage, for: .normal)
        tintColor = .label
        backgroundColor = .clear
        
        // Add loading indicator
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    // MARK: - Audio Control
    
    /// Plays audio from a URL
    /// - Parameter url: The URL of the audio file to play
    func playAudio(url: URL) {
        print("📱 AudioButton - Playing audio from: \(url.lastPathComponent)")
        
        if audioPlayer?.isPlaying == true {
            stopAudio()
            return
        }
        
        isLoading = true
        
        // Load and play audio in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.delegate = self
                
                DispatchQueue.main.async {
                    self?.audioPlayer = player
                    self?.isLoading = false
                    self?.setImage(self?.stopImage, for: .normal)
                    player.play()
                }
            } catch {
                print("❌ AudioButton - Failed to play audio: \(error)")
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.setImage(self?.playImage, for: .normal)
                }
            }
        }
    }
    
    /// Stops audio playback
    func stopAudio() {
        print("📱 AudioButton - Stopping audio playback")
        audioPlayer?.stop()
        audioPlayer = nil
        setImage(playImage, for: .normal)
    }
    
    // MARK: - Cleanup
    
    override func removeFromSuperview() {
        stopAudio()
        super.removeFromSuperview()
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioButton: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.setImage(self?.playImage, for: .normal)
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ AudioButton - Audio decode error: \(error?.localizedDescription ?? "unknown error")")
        DispatchQueue.main.async { [weak self] in
            self?.setImage(self?.playImage, for: .normal)
        }
    }
} 