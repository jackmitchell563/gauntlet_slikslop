import UIKit

class PinnedCommentCell: CommentCell {
    override class var reuseIdentifier: String { return "PinnedCommentCell" }
    
    // MARK: - UI Components
    
    private lazy var pinnedContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var pinnedIconImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "pin.fill")
        iv.tintColor = .systemGray
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private lazy var pinnedLabel: UILabel = {
        let label = UILabel()
        label.text = "Pinned"
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .systemGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupPinnedUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupPinnedUI() {
        contentView.insertSubview(pinnedContainer, at: 0)
        pinnedContainer.addSubview(pinnedIconImageView)
        pinnedContainer.addSubview(pinnedLabel)
        
        NSLayoutConstraint.activate([
            pinnedContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            pinnedContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            pinnedContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            pinnedContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            pinnedIconImageView.topAnchor.constraint(equalTo: pinnedContainer.topAnchor, constant: 8),
            pinnedIconImageView.leadingAnchor.constraint(equalTo: pinnedContainer.leadingAnchor, constant: 16),
            pinnedIconImageView.widthAnchor.constraint(equalToConstant: 12),
            pinnedIconImageView.heightAnchor.constraint(equalToConstant: 12),
            
            pinnedLabel.centerYAnchor.constraint(equalTo: pinnedIconImageView.centerYAnchor),
            pinnedLabel.leadingAnchor.constraint(equalTo: pinnedIconImageView.trailingAnchor, constant: 4)
        ])
    }
} 