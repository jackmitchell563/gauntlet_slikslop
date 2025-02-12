import UIKit
import FirebaseFirestore

/// View controller for character chat interactions
class ChatViewController: UIViewController {
    // MARK: - Properties
    
    private let character: GameCharacter
    private var messages: [ChatMessage] = []
    private let chatService = CharacterChatService.shared
    private var relationshipStatus: Int = 0
    private let db = Firestore.firestore()  // Add Firestore database reference
    private let galleryService = CharacterGalleryService.shared
    
    // Loading state
    private var isLoading = false {
        didSet {
            updateLoadingState()
        }
    }
    
    // MARK: - UI Components
    
    private lazy var bannerView: CharacterBannerView = {
        let view = CharacterBannerView(character: character)
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var imageOverlayView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.alpha = 0
        view.isUserInteractionEnabled = false // Allow interaction pass-through
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let layout = ChatCollectionViewLayout()
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .systemBackground
        cv.delegate = self
        cv.dataSource = self
        cv.register(ChatBubbleCell.self, forCellWithReuseIdentifier: ChatBubbleCell.identifier)
        cv.alwaysBounceVertical = true
        cv.keyboardDismissMode = .interactive
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()
    
    private lazy var chatInputView: ChatInputView = {
        let view = ChatInputView()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var typingIndicator: TypingIndicatorView = {
        let view = TypingIndicatorView()
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var bottomConstraint: NSLayoutConstraint?
    private var keyboardHeight: CGFloat = 0
    
    // MARK: - Initialization
    
    init(character: GameCharacter) {
        self.character = character
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardObservers()
        setupGalleryObservers()
        loadChatHistory()
        loadRelationshipStatus()
        updateGalleryCount()
        
        // Configure sheet presentation behavior
        if let sheet = sheetPresentationController {
            sheet.largestUndimmedDetentIdentifier = .large
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        warmupAssets()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        chatInputView.becomeFirstResponder()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        chatInputView.resignFirstResponder()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(bannerView)
        view.addSubview(collectionView)
        view.addSubview(imageOverlayView)  // Add overlay view
        view.addSubview(typingIndicator)
        view.addSubview(chatInputView)
        
        let bottomConstraint = chatInputView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        self.bottomConstraint = bottomConstraint
        
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bannerView.heightAnchor.constraint(equalToConstant: 250),
            
            collectionView.topAnchor.constraint(equalTo: bannerView.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: typingIndicator.topAnchor),
            
            // Add overlay view constraints
            imageOverlayView.topAnchor.constraint(equalTo: bannerView.bottomAnchor),
            imageOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageOverlayView.bottomAnchor.constraint(equalTo: typingIndicator.topAnchor),
            
            typingIndicator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            typingIndicator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            typingIndicator.bottomAnchor.constraint(equalTo: chatInputView.topAnchor),
            typingIndicator.heightAnchor.constraint(equalToConstant: 30),
            
            chatInputView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chatInputView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomConstraint
        ])
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    private func setupGalleryObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGalleryImageDeleted(_:)),
            name: NSNotification.Name("GalleryImageDeleted"),
            object: nil
        )
    }
    
    // MARK: - Asset Management
    
    private func warmupAssets() {
        Task {
            await CharacterAssetService.shared.warmupAssets(for: character)
        }
    }
    
    // MARK: - Keyboard Handling
    
    @objc private func handleKeyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height
        self.keyboardHeight = keyboardHeight
        
        bottomConstraint?.constant = -keyboardHeight
        
        // Enable compact mode for banner when keyboard shows
        bannerView.setCompactMode(true, animated: true)
        
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func handleKeyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        bottomConstraint?.constant = 0
        
        // Restore banner to full size when keyboard hides
        bannerView.setCompactMode(false, animated: true)
        
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }
    
    // MARK: - Relationship Status
    
    private func loadRelationshipStatus() {
        Task {
            do {
                relationshipStatus = try await chatService.getRelationshipStatus(
                    userId: AuthService.shared.currentUserId ?? "",
                    characterId: character.id
                )
                print("📱 ChatViewController - Loaded relationship status: \(relationshipStatus)")
                await MainActor.run {
                    updateRelationshipUI()
                }
            } catch {
                print("❌ ChatViewController - Error loading relationship status: \(error)")
            }
        }
    }
    
    private func updateRelationshipUI() {
        print("📱 ChatViewController - Updating UI with relationship status: \(relationshipStatus)")
        DispatchQueue.main.async {
            self.bannerView.updateRelationshipStatus(self.relationshipStatus)
        }
    }
    
    // MARK: - Message Handling
    
    private func loadChatHistory() {
        Task {
            do {
                let history = try await chatService.loadChatHistory(for: character)
                await MainActor.run {
                    messages = history
                    collectionView.reloadData()
                    scrollToBottom()
                }
            } catch {
                print("❌ ChatViewController - Error loading chat history: \(error)")
                handleError(error)
            }
        }
    }
    
    private func addMessage(_ message: ChatMessage) {
        messages.append(message)
        let indexPath = IndexPath(item: messages.count - 1, section: 0)
        
        // If this is an image message, we need to observe its status changes
        if message.type == .textWithImage {
            observeImageStatus(for: message)
        }
        
        collectionView.insertItems(at: [indexPath])
        scrollToBottom()
    }
    
    /// Observes image generation status changes for a message
    private func observeImageStatus(for message: ChatMessage) {
        // Create a reference to the message document
        let chatId = chatService.getChatId(for: character)
        let messageRef = db.collection("chats")
            .document(chatId)
            .collection("messages")
            .document(message.id)
        
        // Listen for real-time updates
        messageRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self,
                  let data = snapshot?.data(),
                  let statusString = data["imageGenerationStatus"] as? String else {
                return
            }
            
            // Update message status
            var updatedMessage = message
            switch statusString {
            case "queued":
                updatedMessage.imageGenerationStatus = .queued
            case "generating":
                updatedMessage.imageGenerationStatus = .generating
            case "completed":
                updatedMessage.imageGenerationStatus = .completed
                // If we have an ephemeral image, display it with animation
                if let image = updatedMessage.ephemeralImage {
                    DispatchQueue.main.async {
                        self.displayGeneratedImage(image)
                    }
                }
            case "failed":
                let errorMessage = data["imageGenerationError"] as? String ?? "Unknown error"
                updatedMessage.imageGenerationStatus = .failed(
                    NSError(domain: "ImageGeneration",
                           code: -1,
                           userInfo: [NSLocalizedDescriptionKey: errorMessage])
                )
            default:
                break
            }
            
            // Update UI
            if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                self.messages[index] = updatedMessage
                self.collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
            }
        }
    }
    
    private func scrollToBottom() {
        guard !messages.isEmpty else { return }
        let indexPath = IndexPath(item: messages.count - 1, section: 0)
        collectionView.scrollToItem(at: indexPath, at: .bottom, animated: true)
    }
    
    private func updateLoadingState() {
        if isLoading {
            showTypingIndicator()
        } else {
            hideTypingIndicator()
        }
    }
    
    private func showTypingIndicator() {
        typingIndicator.isHidden = false
        typingIndicator.startAnimating()
    }
    
    private func hideTypingIndicator() {
        typingIndicator.isHidden = true
        typingIndicator.stopAnimating()
    }
    
    private func handleError(_ error: Error) {
        let alert = UIAlertController(
            title: "Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Image Display
    
    /// Displays a generated image with fade in/out animation
    /// - Parameter image: The image to display
    private func displayGeneratedImage(_ image: UIImage) {
        // Configure the image
        imageOverlayView.image = image
        
        // Fade in animation (1 second)
        UIView.animate(withDuration: 1.0, animations: {
            self.imageOverlayView.alpha = 1
        }) { _ in
            // Wait 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // Fade out animation (1 second)
                UIView.animate(withDuration: 1.0) {
                    self.imageOverlayView.alpha = 0
                } completion: { _ in
                    // Clear the image after animation
                    self.imageOverlayView.image = nil
                    // Update gallery count after new image is generated
                    self.updateGalleryCount()
                }
            }
        }
    }
    
    // MARK: - Gallery Support
    
    private func updateGalleryCount() {
        Task {
            do {
                let count = try galleryService.getImageCount(for: character)
                await MainActor.run {
                    bannerView.updateGalleryCount(count)
                }
            } catch {
                print("❌ ChatViewController - Failed to get gallery count: \(error)")
            }
        }
    }
    
    @objc private func handleGalleryImageDeleted(_ notification: Notification) {
        guard let notificationCharacter = notification.userInfo?["character"] as? GameCharacter,
              notificationCharacter.id == character.id else {
            return
        }
        updateGalleryCount()
    }
}

// MARK: - UICollectionView DataSource & Delegate

extension ChatViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ChatBubbleCell.identifier, for: indexPath) as! ChatBubbleCell
        let message = messages[indexPath.item]
        
        // Pass character's profile image URL for character messages
        if message.sender == .character {
            cell.configure(with: message, profileImageURL: character.profileImageURL)
        } else {
            cell.configure(with: message)
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let message = messages[indexPath.item]
        return ChatBubbleCell.size(for: message, width: collectionView.bounds.width - 32)
    }
}

// MARK: - ChatInputViewDelegate

extension ChatViewController: ChatInputViewDelegate {
    func chatInputView(_ view: ChatInputView, didSendMessage text: String) {
        guard !isLoading else { return }
        
        // Calculate next sequence number based on last message
        let nextSequence = (messages.last?.sequence ?? 0) + 1
        
        let message = ChatMessage(
            id: UUID().uuidString,
            text: text,
            sender: .user,
            timestamp: Date(),
            sequence: nextSequence
        )
        addMessage(message)
        
        isLoading = true
        
        Task {
            do {
                let response = try await chatService.sendMessage(text: text, to: character)
                await MainActor.run {
                    addMessage(response)
                    loadRelationshipStatus() // Refresh relationship status after response
                    isLoading = false
                }
            } catch {
                print("❌ ChatViewController - Error sending message: \(error)")
                await MainActor.run {
                    isLoading = false
                    handleError(error)
                }
            }
        }
    }
}

// MARK: - CharacterBannerViewDelegate

extension ChatViewController: CharacterBannerViewDelegate {
    func characterBannerViewDidTapGallery(_ bannerView: CharacterBannerView) {
        let galleryVC = CharacterGalleryViewController(character: character)
        let nav = UINavigationController(rootViewController: galleryVC)
        present(nav, animated: true)
    }
} 