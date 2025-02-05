import UIKit

protocol CommentInputViewDelegate: AnyObject {
    func commentInputView(_ view: CommentInputView, didSubmitComment text: String)
}

class CommentInputView: UIView {
    // MARK: - Properties
    
    weak var delegate: CommentInputViewDelegate?
    private let maxHeight: CGFloat = 100
    
    // MARK: - UI Components
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray5
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var textView: UITextView = {
        let tv = UITextView()
        tv.font = .systemFont(ofSize: 16)
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 4)
        tv.textContainer.lineFragmentPadding = 0
        tv.layer.cornerRadius = 16
        tv.layer.borderWidth = 1
        tv.layer.borderColor = UIColor.systemGray5.cgColor
        tv.isScrollEnabled = false
        tv.delegate = self
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()
    
    private lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = "Add comment..."
        label.font = .systemFont(ofSize: 16)
        label.textColor = .systemGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var postButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Post", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.isEnabled = false
        button.addTarget(self, action: #selector(handlePost), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var textViewHeightConstraint: NSLayoutConstraint?
    private var containerHeightConstraint: NSLayoutConstraint?
    
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
        
        addSubview(containerView)
        containerView.addSubview(separatorView)
        containerView.addSubview(textView)
        textView.addSubview(placeholderLabel)
        containerView.addSubview(postButton)
        
        // Create height constraints
        textViewHeightConstraint = textView.heightAnchor.constraint(equalToConstant: 36)
        containerHeightConstraint = containerView.heightAnchor.constraint(equalToConstant: 56)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerHeightConstraint!,
            
            separatorView.topAnchor.constraint(equalTo: containerView.topAnchor),
            separatorView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 1),
            
            textView.topAnchor.constraint(equalTo: separatorView.bottomAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: postButton.leadingAnchor, constant: -8),
            textViewHeightConstraint!,
            
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: textView.textContainerInset.top),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 13),
            
            postButton.centerYAnchor.constraint(equalTo: textView.centerYAnchor),
            postButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            postButton.widthAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - Public Methods
    
    func clear() {
        textView.text = ""
        updatePlaceholderVisibility()
        updatePostButtonState()
        updateTextViewHeight()
    }
    
    // MARK: - Private Methods
    
    private func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !textView.text.isEmpty
    }
    
    private func updatePostButtonState() {
        postButton.isEnabled = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func updateTextViewHeight() {
        let size = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: .infinity))
        let newHeight = min(size.height, maxHeight)
        textViewHeightConstraint?.constant = max(36, newHeight)
        containerHeightConstraint?.constant = max(56, newHeight + 20)
        
        // Enable/disable scrolling based on content size
        textView.isScrollEnabled = size.height > maxHeight
        
        layoutIfNeeded()
    }
    
    // MARK: - Actions
    
    @objc private func handlePost() {
        guard let text = textView.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return }
        
        delegate?.commentInputView(self, didSubmitComment: text)
    }
}

// MARK: - UITextViewDelegate

extension CommentInputView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updatePlaceholderVisibility()
        updatePostButtonState()
        updateTextViewHeight()
    }
} 