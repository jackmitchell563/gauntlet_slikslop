import UIKit

/// Protocol for handling chat input events
protocol ChatInputViewDelegate: AnyObject {
    func chatInputView(_ view: ChatInputView, didSendMessage text: String)
}

/// Custom input view for chat messages
class ChatInputView: UIView {
    // MARK: - Properties
    
    weak var delegate: ChatInputViewDelegate?
    
    // MARK: - UI Components
    
    private lazy var textView: UITextView = {
        let tv = UITextView()
        tv.font = .systemFont(ofSize: 16)
        tv.isScrollEnabled = false
        tv.layer.cornerRadius = 18
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 36)
        tv.backgroundColor = .secondarySystemBackground
        tv.delegate = self
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()
    
    private lazy var sendButton: UIButton = {
        let button = UIButton()
        let config = UIImage.SymbolConfiguration(pointSize: 24)
        let image = UIImage(systemName: "arrow.up.circle.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .systemBlue
        button.addTarget(self, action: #selector(handleSend), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isEnabled = false
        return button
    }()
    
    private var heightConstraint: NSLayoutConstraint?
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        backgroundColor = .systemBackground
        
        // Add shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: -1)
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 3
        
        // Add subviews
        addSubview(textView)
        addSubview(sendButton)
        
        // Setup constraints
        heightConstraint = heightAnchor.constraint(equalToConstant: 56)
        
        NSLayoutConstraint.activate([
            heightConstraint!,
            
            textView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            
            sendButton.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: -4),
            sendButton.centerYAnchor.constraint(equalTo: textView.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 28),
            sendButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func handleSend() {
        guard let text = textView.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return
        }
        
        delegate?.chatInputView(self, didSendMessage: text)
        textView.text = ""
        updateSendButtonState()
        updateHeight()
    }
    
    // MARK: - Height Management
    
    private func updateHeight() {
        let size = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude))
        let newHeight = min(max(56, size.height + 16), 120)
        
        if heightConstraint?.constant != newHeight {
            heightConstraint?.constant = newHeight
            
            UIView.animate(withDuration: 0.2) {
                self.superview?.layoutIfNeeded()
            }
        }
    }
    
    // MARK: - Public Methods
    
    override func becomeFirstResponder() -> Bool {
        textView.becomeFirstResponder()
    }
    
    override func resignFirstResponder() -> Bool {
        textView.resignFirstResponder()
    }
}

// MARK: - UITextViewDelegate

extension ChatInputView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateHeight()
        updateSendButtonState()
    }
    
    private func updateSendButtonState() {
        let text = textView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        sendButton.isEnabled = !text.isEmpty
        sendButton.tintColor = text.isEmpty ? .systemGray : .systemBlue
    }
} 