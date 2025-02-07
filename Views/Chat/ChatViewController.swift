import UIKit

/// View controller for character chat interactions
class ChatViewController: UIViewController {
    // MARK: - Properties
    
    private let character: GameCharacter
    private var messages: [ChatMessage] = []
    private let chatService = CharacterChatService.shared
    
    // Loading state
    private var isLoading = false {
        didSet {
            updateLoadingState()
        }
    }
    
    // MARK: - UI Components
    
    private lazy var bannerView: CharacterBannerView = {
        let view = CharacterBannerView(character: character)
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
        loadChatHistory()
        
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
        view.addSubview(typingIndicator)
        view.addSubview(chatInputView)
        
        let bottomConstraint = chatInputView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        self.bottomConstraint = bottomConstraint
        
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bannerView.heightAnchor.constraint(equalToConstant: 200),
            
            collectionView.topAnchor.constraint(equalTo: bannerView.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: typingIndicator.topAnchor),
            
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
        
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func handleKeyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        bottomConstraint?.constant = 0
        
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
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
                // TODO: Show error to user
            }
        }
    }
    
    private func addMessage(_ message: ChatMessage) {
        messages.append(message)
        
        let indexPath = IndexPath(item: messages.count - 1, section: 0)
        collectionView.insertItems(at: [indexPath])
        scrollToBottom()
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
}

// MARK: - UICollectionView DataSource & Delegate

extension ChatViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ChatBubbleCell.identifier, for: indexPath) as! ChatBubbleCell
        let message = messages[indexPath.item]
        cell.configure(with: message)
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
        
        let message = ChatMessage(
            id: UUID().uuidString,
            text: text,
            sender: .user,
            timestamp: Date()
        )
        addMessage(message)
        
        isLoading = true
        
        Task {
            do {
                let response = try await chatService.sendMessage(text: text, to: character)
                await MainActor.run {
                    addMessage(response)
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