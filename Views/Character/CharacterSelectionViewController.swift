import UIKit

protocol CharacterSelectionDelegate: AnyObject {
    func characterSelectionViewController(_ viewController: CharacterSelectionViewController, didSelect character: GameCharacter)
}

class CharacterSelectionViewController: UIViewController {
    // MARK: - Properties
    
    weak var delegate: CharacterSelectionDelegate?
    private var characters: [GameCharacter] = []
    private var filteredCharacters: [GameCharacter] = []
    private var selectedGame: GachaGame?
    private var isDataPopulated = false
    private var preloadedImages: [String: UIImage] = [:]
    
    // MARK: - UI Components
    
    private lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search characters..."
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        return searchBar
    }()
    
    private lazy var gameFilterSegmentedControl: UISegmentedControl = {
        let items = ["All"] + GachaGame.allCases.map { $0.rawValue }
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(handleGameFilterChange), for: .valueChanged)
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 1
        layout.minimumLineSpacing = 1
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .systemBackground
        cv.delegate = self
        cv.dataSource = self
        cv.register(CharacterCell.self, forCellWithReuseIdentifier: "CharacterCell")
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private lazy var emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "Loading characters..."
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 16)
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkDataPopulation()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(searchBar)
        view.addSubview(gameFilterSegmentedControl)
        view.addSubview(collectionView)
        view.addSubview(loadingIndicator)
        view.addSubview(emptyStateLabel)
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            gameFilterSegmentedControl.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            gameFilterSegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            gameFilterSegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            collectionView.topAnchor.constraint(equalTo: gameFilterSegmentedControl.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // MARK: - Data Loading
    
    private func checkDataPopulation() {
        loadingIndicator.startAnimating()
        emptyStateLabel.isHidden = false
        collectionView.isHidden = true
        
        Task {
            var retryCount = 0
            let maxRetries = 5
            
            while !isDataPopulated && retryCount < maxRetries {
                do {
                    let characters = try await CharacterService.shared.fetchCharacters(game: selectedGame)
                    if !characters.isEmpty {
                        // Preload images before showing UI
                        print("📱 CharacterSelectionVC - Preloading banner images")
                        let images = await CharacterAssetService.shared.preloadBannerImages(for: characters)
                        
                        await MainActor.run {
                            self.characters = characters
                            self.filteredCharacters = characters
                            self.preloadedImages = images
                            self.isDataPopulated = true
                            self.loadingIndicator.stopAnimating()
                            self.emptyStateLabel.isHidden = true
                            self.collectionView.isHidden = false
                            self.collectionView.reloadData()
                        }
                        return
                    }
                } catch {
                    print("❌ CharacterSelectionVC - Error loading characters: \(error)")
                }
                
                let delay = pow(2.0, Double(retryCount)) * 0.5
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                retryCount += 1
            }
            
            await MainActor.run {
                self.loadingIndicator.stopAnimating()
                self.emptyStateLabel.text = "Unable to load characters.\nPlease try again later."
                self.emptyStateLabel.isHidden = false
            }
        }
    }
    
    private func loadCharacters() {
        guard isDataPopulated else {
            checkDataPopulation()
            return
        }
        
        loadingIndicator.startAnimating()
        collectionView.isHidden = true
        
        Task {
            do {
                let characters = try await CharacterService.shared.fetchCharacters(game: selectedGame)
                let images = await CharacterAssetService.shared.preloadBannerImages(for: characters)
                
                await MainActor.run {
                    self.characters = characters
                    self.filteredCharacters = characters
                    self.preloadedImages = images
                    self.collectionView.reloadData()
                    self.loadingIndicator.stopAnimating()
                    self.collectionView.isHidden = false
                }
            } catch {
                await MainActor.run {
                    self.loadingIndicator.stopAnimating()
                    self.emptyStateLabel.text = "Error loading characters.\nPlease try again."
                    self.emptyStateLabel.isHidden = false
                }
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func handleGameFilterChange(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            selectedGame = nil
        } else {
            selectedGame = GachaGame.allCases[sender.selectedSegmentIndex - 1]
        }
        loadCharacters()
    }
}

// MARK: - UICollectionView DataSource & Delegate

extension CharacterSelectionViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        print("📱 CharacterSelectionVC - Number of items in section: \(filteredCharacters.count)")
        return filteredCharacters.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        print("📱 CharacterSelectionVC - Configuring cell at index: \(indexPath.item)")
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CharacterCell", for: indexPath) as! CharacterCell
        let character = filteredCharacters[indexPath.item]
        print("📱 CharacterSelectionVC - Character: \(character.name) from \(character.game.rawValue)")
        
        let preloadedImage = preloadedImages[character.id]
        cell.configure(with: character, preloadedImage: preloadedImage)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width - 2) / 3
        return CGSize(width: width, height: width * 1.5)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let character = filteredCharacters[indexPath.item]
        delegate?.characterSelectionViewController(self, didSelect: character)
        dismiss(animated: true)
    }
}

// MARK: - UISearchBarDelegate

extension CharacterSelectionViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredCharacters = characters
        } else {
            filteredCharacters = characters.filter { character in
                character.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        collectionView.reloadData()
    }
}

// MARK: - Character Cell

private class CharacterCell: UICollectionViewCell {
    // MARK: - Properties
    
    private var loadingTask: Task<Void, Never>?
    private var currentCharacterId: String?
    
    // MARK: - UI Components
    
    private lazy var imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .systemGray6
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var gameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(imageView)
        contentView.addSubview(loadingIndicator)
        contentView.addSubview(nameLabel)
        contentView.addSubview(gameLabel)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.7),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            
            nameLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            
            gameLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            gameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            gameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4)
        ])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        cancelLoading()
        imageView.image = nil
        currentCharacterId = nil
    }
    
    private func cancelLoading() {
        loadingTask?.cancel()
        loadingTask = nil
        loadingIndicator.stopAnimating()
    }
    
    func configure(with character: GameCharacter, preloadedImage: UIImage?) {
        print("📱 CharacterCell - Configuring cell for: \(character.name)")
        
        nameLabel.text = character.name
        gameLabel.text = character.game.rawValue
        
        if let preloadedImage = preloadedImage {
            imageView.image = preloadedImage
            loadingIndicator.stopAnimating()
        } else {
            imageView.image = nil
            loadingIndicator.startAnimating()
            
            CharacterAssetService.shared.getBannerImage(for: character) { [weak self] image in
                guard let self = self else { return }
                self.imageView.image = image
                self.loadingIndicator.stopAnimating()
            }
        }
    }
} 