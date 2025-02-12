import UIKit

/// View controller for displaying a character's generated images in a mosaic layout
class CharacterGalleryViewController: UIViewController {
    // MARK: - Properties
    
    private let character: GameCharacter
    private var galleryImages: [CharacterGalleryService.GalleryImage] = []
    private let galleryService = CharacterGalleryService.shared
    
    private lazy var collectionView: UICollectionView = {
        let layout = MosaicLayout()
        layout.delegate = self
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .systemBackground
        cv.delegate = self
        cv.dataSource = self
        cv.register(GalleryImageCell.self, forCellWithReuseIdentifier: "GalleryImageCell")
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()
    
    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No images generated yet"
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 16)
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    
    init(character: GameCharacter) {
        self.character = character
        super.init(nibName: nil, bundle: nil)
        title = "\(character.name)'s Gallery"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadImages()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(collectionView)
        view.addSubview(emptyStateLabel)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // MARK: - Data Loading
    
    private func loadImages() {
        Task {
            do {
                galleryImages = try await galleryService.getImages(for: character)
                await MainActor.run {
                    emptyStateLabel.isHidden = !galleryImages.isEmpty
                    collectionView.reloadData()
                }
            } catch {
                print("❌ CharacterGalleryViewController - Failed to load images: \(error)")
                await MainActor.run {
                    let alert = UIAlertController(
                        title: "Error",
                        message: "Failed to load images",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    present(alert, animated: true)
                }
            }
        }
    }
}

// MARK: - UICollectionViewDataSource

extension CharacterGalleryViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return galleryImages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GalleryImageCell", for: indexPath) as? GalleryImageCell else {
            return UICollectionViewCell()
        }
        
        let galleryImage = galleryImages[indexPath.item]
        cell.configure(with: galleryImage.image)
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension CharacterGalleryViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let images = galleryImages.map { $0.image }
        let fullScreenVC = FullScreenImageViewController(images: images, initialIndex: indexPath.item)
        present(fullScreenVC, animated: true)
    }
    
    // MARK: - Swipe Actions
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let galleryImage = galleryImages[indexPath.item]
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let deleteAction = UIAction(
                title: "Delete",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.deleteImage(at: indexPath)
            }
            
            return UIMenu(title: "", children: [deleteAction])
        }
    }
    
    // MARK: - Private Methods
    
    private func deleteImage(at indexPath: IndexPath) {
        let galleryImage = galleryImages[indexPath.item]
        
        do {
            try galleryService.deleteImage(at: galleryImage.url, for: character)
            
            // Update data source
            galleryImages.remove(at: indexPath.item)
            
            // Update UI
            collectionView.deleteItems(at: [indexPath])
            emptyStateLabel.isHidden = !galleryImages.isEmpty
            
            // Notify parent view controller to update gallery count
            NotificationCenter.default.post(
                name: NSNotification.Name("GalleryImageDeleted"),
                object: nil,
                userInfo: ["character": character]
            )
        } catch {
            print("❌ CharacterGalleryViewController - Failed to delete image: \(error)")
            let alert = UIAlertController(
                title: "Error",
                message: "Failed to delete image",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}

// MARK: - MosaicLayoutDelegate

extension CharacterGalleryViewController: MosaicLayoutDelegate {
    func collectionView(_ collectionView: UICollectionView, widthForImageAtIndexPath indexPath: IndexPath) -> CGFloat {
        return collectionView.bounds.width / 3 - 2 // Account for spacing
    }
    
    func collectionView(_ collectionView: UICollectionView, heightForImageAtIndexPath indexPath: IndexPath) -> CGFloat {
        let image = galleryImages[indexPath.item].image
        let width = collectionView.bounds.width / 3 - 2 // Account for spacing
        let aspectRatio = image.size.height / image.size.width
        return width * aspectRatio
    }
}

// MARK: - GalleryImageCell

private class GalleryImageCell: UICollectionViewCell {
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    func configure(with image: UIImage) {
        imageView.image = image
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }
} 
