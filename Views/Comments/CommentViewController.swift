import UIKit
import FirebaseFirestore

/// View controller for displaying and managing video comments
class CommentViewController: UIViewController {
    // MARK: - Properties
    
    private let videoId: String
    private let creatorId: String
    private var comments: [Comment] = []
    private var pinnedComment: Comment?
    private var lastCommentTimestamp: Timestamp?
    private var isLoading = false
    private let commentService = CommentService.shared
    
    // MARK: - UI Components
    
    private lazy var headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .label
        button.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.delegate = self
        tv.dataSource = self
        tv.separatorStyle = .none
        tv.backgroundColor = .systemBackground
        tv.keyboardDismissMode = .interactive
        tv.register(CommentCell.self, forCellReuseIdentifier: CommentCell.reuseIdentifier)
        tv.register(PinnedCommentCell.self, forCellReuseIdentifier: PinnedCommentCell.reuseIdentifier)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()
    
    private lazy var commentInputView: CommentInputView = {
        let view = CommentInputView()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // MARK: - Initialization
    
    init(videoId: String, creatorId: String) {
        self.videoId = videoId
        self.creatorId = creatorId
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadComments()
        
        // Observe keyboard
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardChange),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add subviews
        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(closeButton)
        view.addSubview(tableView)
        view.addSubview(commentInputView)
        view.addSubview(loadingIndicator)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 44),
            
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            
            commentInputView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            commentInputView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            commentInputView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: commentInputView.topAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Set initial content inset for tableView
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 8, right: 0)
    }
    
    // MARK: - Data Loading
    
    private func loadComments() {
        guard !isLoading else { return }
        isLoading = true
        loadingIndicator.startAnimating()
        
        Task {
            do {
                let fetchedComments = try await commentService.fetchComments(
                    videoId: videoId,
                    lastCommentTimestamp: lastCommentTimestamp
                )
                
                await MainActor.run {
                    if self.comments.isEmpty {
                        // First load
                        self.comments = fetchedComments
                    } else {
                        // Pagination
                        self.comments.append(contentsOf: fetchedComments)
                    }
                    
                    self.lastCommentTimestamp = fetchedComments.last?.createdAt
                    self.updateUI()
                    self.isLoading = false
                    self.loadingIndicator.stopAnimating()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.loadingIndicator.stopAnimating()
                    // TODO: Show error
                    print("Error loading comments: \(error)")
                }
            }
        }
    }
    
    private func updateUI() {
        titleLabel.text = "\(comments.count) comments"
        tableView.reloadData()
    }
    
    // MARK: - Actions
    
    @objc private func handleClose() {
        dismiss(animated: true)
    }
    
    @objc private func handleKeyboardChange(notification: NSNotification) {
        // No need to handle keyboard changes manually since we're using keyboardLayoutGuide
    }
}

// MARK: - UITableViewDelegate & DataSource

extension CommentViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return pinnedComment == nil ? 1 : 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 && pinnedComment != nil {
            return 1
        }
        return comments.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 && pinnedComment != nil {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: PinnedCommentCell.reuseIdentifier,
                for: indexPath
            ) as! PinnedCommentCell
            cell.configure(with: pinnedComment!, creatorId: creatorId)
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(
            withIdentifier: CommentCell.reuseIdentifier,
            for: indexPath
        ) as! CommentCell
        let comment = comments[indexPath.row]
        cell.configure(with: comment, creatorId: creatorId)
        return cell
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let position = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let scrollViewHeight = scrollView.bounds.height
        
        // Load more when near bottom
        if position > contentHeight - scrollViewHeight - 100 {
            loadComments()
        }
    }
}

// MARK: - CommentInputViewDelegate

extension CommentViewController: CommentInputViewDelegate {
    func commentInputView(_ view: CommentInputView, didSubmitComment text: String) {
        guard !text.isEmpty else { return }
        
        Task {
            do {
                guard let userId = AuthService.shared.currentUserId else {
                    // TODO: Show auth required message
                    return
                }
                
                let comment = try await commentService.createComment(
                    videoId: videoId,
                    userId: userId,
                    content: text
                )
                
                await MainActor.run {
                    self.comments.insert(comment, at: 0)
                    self.updateUI()
                    view.clear()
                }
            } catch {
                // TODO: Show error
                print("Error creating comment: \(error)")
            }
        }
    }
} 