import UIKit
import FirebaseFirestore

protocol CommentCellDelegate: AnyObject {
    func commentCell(_ cell: CommentCell, didTapLike comment: Comment)
    func commentCell(_ cell: CommentCell, didTapReply comment: Comment)
}

class CommentCell: UITableViewCell {
    class var reuseIdentifier: String { return "CommentCell" }
    
    // MARK: - Properties
    
    weak var delegate: CommentCellDelegate?
    private var comment: Comment?
    private var isCreator = false
    
    // MARK: - UI Components
    
    private lazy var avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .systemGray5
        iv.layer.cornerRadius = 16
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private lazy var usernameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var creatorBadge: UILabel = {
        let label = UILabel()
        label.text = "Creator"
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .systemBlue
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var commentLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var timestampLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .systemGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var likeButton: UIButton = {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.contentInsets = .zero
        button.configuration = config
        button.setImage(UIImage(systemName: "heart"), for: .normal)
        button.tintColor = .systemGray
        button.addTarget(self, action: #selector(handleLike), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var likeCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .systemGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var replyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Reply", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 12)
        button.tintColor = .systemGray
        button.addTarget(self, action: #selector(handleReply), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var likedByCreatorLabel: UILabel = {
        let label = UILabel()
        label.text = "Liked by creator"
        label.font = .systemFont(ofSize: 12)
        label.textColor = .systemGray
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .systemBackground
        
        contentView.addSubview(avatarImageView)
        contentView.addSubview(usernameLabel)
        contentView.addSubview(creatorBadge)
        contentView.addSubview(commentLabel)
        contentView.addSubview(timestampLabel)
        contentView.addSubview(likeButton)
        contentView.addSubview(likeCountLabel)
        contentView.addSubview(replyButton)
        contentView.addSubview(likedByCreatorLabel)
        
        // Add width constraint to ensure consistent button size
        likeButton.setContentHuggingPriority(.required, for: .horizontal)
        likeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        NSLayoutConstraint.activate([
            avatarImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarImageView.widthAnchor.constraint(equalToConstant: 32),
            avatarImageView.heightAnchor.constraint(equalToConstant: 32),
            
            usernameLabel.topAnchor.constraint(equalTo: avatarImageView.topAnchor),
            usernameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 8),
            
            creatorBadge.centerYAnchor.constraint(equalTo: usernameLabel.centerYAnchor),
            creatorBadge.leadingAnchor.constraint(equalTo: usernameLabel.trailingAnchor, constant: 4),
            
            commentLabel.topAnchor.constraint(equalTo: usernameLabel.bottomAnchor, constant: 2),
            commentLabel.leadingAnchor.constraint(equalTo: usernameLabel.leadingAnchor),
            commentLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            timestampLabel.topAnchor.constraint(equalTo: commentLabel.bottomAnchor, constant: 4),
            timestampLabel.leadingAnchor.constraint(equalTo: usernameLabel.leadingAnchor),
            
            likeButton.centerYAnchor.constraint(equalTo: timestampLabel.centerYAnchor),
            likeButton.leadingAnchor.constraint(equalTo: timestampLabel.trailingAnchor, constant: 16),
            likeButton.widthAnchor.constraint(equalToConstant: 24), // Fixed width for the button
            
            likeCountLabel.centerYAnchor.constraint(equalTo: likeButton.centerYAnchor),
            likeCountLabel.leadingAnchor.constraint(equalTo: likeButton.trailingAnchor, constant: -2), // Negative constant to overlap slightly if needed
            
            replyButton.centerYAnchor.constraint(equalTo: likeButton.centerYAnchor),
            replyButton.leadingAnchor.constraint(equalTo: likeCountLabel.trailingAnchor, constant: 12),
            
            likedByCreatorLabel.topAnchor.constraint(equalTo: timestampLabel.bottomAnchor, constant: 4),
            likedByCreatorLabel.leadingAnchor.constraint(equalTo: usernameLabel.leadingAnchor),
            likedByCreatorLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    // MARK: - Configuration
    
    func configure(with comment: Comment, creatorId: String) {
        self.comment = comment
        self.isCreator = comment.userId == creatorId
        
        // TODO: Load user profile to get username and avatar
        usernameLabel.text = "username" // Temporary
        commentLabel.text = comment.content
        timestampLabel.text = formatTimestamp(comment.createdAt)
        likeCountLabel.text = "0" // TODO: Add likes to Comment model
        creatorBadge.isHidden = !isCreator
    }
    
    private func formatTimestamp(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: - Actions
    
    @objc private func handleLike() {
        guard let comment = comment else { return }
        delegate?.commentCell(self, didTapLike: comment)
    }
    
    @objc private func handleReply() {
        guard let comment = comment else { return }
        delegate?.commentCell(self, didTapReply: comment)
    }
} 