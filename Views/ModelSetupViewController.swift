import UIKit

/// View controller for handling model setup and downloading
class ModelSetupViewController: UIViewController {
    // MARK: - Properties
    
    private let stableDiffusion = StableDiffusionService.shared
    private var isDownloading = false
    
    // MARK: - UI Components
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Model Setup Required"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "To enable image generation, we need to download the required model files. This may take a few minutes."
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var progressView: UIProgressView = {
        let view = UIProgressView(progressViewStyle: .default)
        view.progress = 0
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var downloadButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Download Models", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(handleDownload), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkModelStatus()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descriptionLabel)
        containerView.addSubview(progressView)
        containerView.addSubview(downloadButton)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            progressView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 24),
            progressView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            progressView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            downloadButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 24),
            downloadButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            downloadButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            downloadButton.heightAnchor.constraint(equalToConstant: 48),
            downloadButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func handleDownload() {
        guard !isDownloading else { return }
        
        isDownloading = true
        updateUI(isDownloading: true)
        
        Task {
            do {
                try await stableDiffusion.downloadModelFilesIfNeeded { progress in
                    DispatchQueue.main.async {
                        self.progressView.progress = Float(progress)
                    }
                }
                
                await MainActor.run {
                    handleDownloadSuccess()
                }
            } catch {
                await MainActor.run {
                    handleDownloadError(error)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func checkModelStatus() {
        if stableDiffusion.areModelFilesAvailable() {
            dismiss(animated: true)
        }
    }
    
    private func updateUI(isDownloading: Bool) {
        downloadButton.isEnabled = !isDownloading
        progressView.isHidden = !isDownloading
        downloadButton.setTitle(isDownloading ? "Downloading..." : "Download Models", for: .normal)
    }
    
    private func handleDownloadSuccess() {
        isDownloading = false
        dismiss(animated: true)
    }
    
    private func handleDownloadError(_ error: Error) {
        isDownloading = false
        updateUI(isDownloading: false)
        
        let alert = UIAlertController(
            title: "Download Failed",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
} 