import UIKit

protocol CharacterSelectionDelegate: AnyObject {
    func characterSelectionViewController(_ viewController: CharacterSelectionViewController, didSelect character: GameCharacter)
}

// MARK: - Mosaic Layout

enum ImageAspectType {
    case tall    // Taller than wide
    case square  // Roughly square
    case wide    // Wider than tall
    
    var columnSpan: Int {
        switch self {
        case .tall: return 1
        case .square: return 2
        case .wide: return 3
        }
    }
    
    static func from(aspectRatio: CGFloat) -> ImageAspectType {
        let ratio = aspectRatio // height/width
        if ratio > 1.2 { return .tall }    // Taller than wide with 20% threshold
        if ratio < 0.8 { return .wide }    // Wider than tall with 20% threshold
        return .square                     // Roughly square (between 0.8 and 1.2)
    }
}

class MosaicLayout: UICollectionViewLayout {
    weak var delegate: MosaicLayoutDelegate?
    private var cache: [UICollectionViewLayoutAttributes] = []
    private var contentHeight: CGFloat = 0
    private let cellPadding: CGFloat = 1
    private let numberOfBaseColumns: CGFloat = 6
    private var contentWidth: CGFloat {
        guard let collectionView = collectionView else { return 0 }
        return collectionView.bounds.width
    }
    
    private var shouldInvalidateCache = true
    private var preferRightSide = false // Flag to alternate Star Rail placement
    
    override var collectionViewContentSize: CGSize {
        return CGSize(width: contentWidth, height: contentHeight)
    }
    
    // Add public method to force layout update
    func invalidateLayoutWithUpdate() {
        shouldInvalidateCache = true
        invalidateLayout()
        shouldInvalidateCache = false
    }
    
    override func invalidateLayout() {
        // Only invalidate if explicitly requested
        if shouldInvalidateCache {
            super.invalidateLayout()
            cache.removeAll()
        }
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        // Only invalidate for width changes
        guard let collectionView = collectionView else { return false }
        return newBounds.width != collectionView.bounds.width
    }
    
    override func prepare() {
        guard let collectionView = collectionView,
              cache.isEmpty else { return }
        
        contentHeight = 0
        let baseColumnWidth = contentWidth / numberOfBaseColumns
        
        // Initialize column tracking
        var columnHeights = Array(repeating: CGFloat(0), count: Int(numberOfBaseColumns))
        
        for item in 0..<collectionView.numberOfItems(inSection: 0) {
            let indexPath = IndexPath(item: item, section: 0)
            
            // Get image dimensions
            let imageHeight = delegate?.collectionView(collectionView, heightForImageAtIndexPath: indexPath) ?? baseColumnWidth * 1.5
            let imageWidth = delegate?.collectionView(collectionView, widthForImageAtIndexPath: indexPath) ?? baseColumnWidth
            let aspectRatio = imageHeight / imageWidth
            let aspectType = ImageAspectType.from(aspectRatio: aspectRatio)
            let columnSpan = aspectType.columnSpan
            let requiredColumns = columnSpan * 2
            
            // Find the shortest valid position
            var bestColumn = 0
            var bestHeight = CGFloat.greatestFiniteMagnitude
            
            // For square images (Star Rail), alternate between left and right sides
            if aspectType == .square {
                let startRange = preferRightSide ? 
                    (2...(Int(numberOfBaseColumns) - requiredColumns)) : // Right side columns
                    (0...2) // Left side columns
                
                // Try columns in the preferred range first
                for startColumn in startRange {
                    let columnRange = startColumn..<(startColumn + requiredColumns)
                    let spanMaxHeight = columnHeights[columnRange].max() ?? 0
                    if spanMaxHeight < bestHeight {
                        bestColumn = startColumn
                        bestHeight = spanMaxHeight
                    }
                }
                
                // If we couldn't find a good spot in the preferred range, try all columns
                if bestHeight == CGFloat.greatestFiniteMagnitude {
                    for startColumn in 0...(Int(numberOfBaseColumns) - requiredColumns) {
                        let columnRange = startColumn..<(startColumn + requiredColumns)
                        let spanMaxHeight = columnHeights[columnRange].max() ?? 0
                        if spanMaxHeight < bestHeight {
                            bestColumn = startColumn
                            bestHeight = spanMaxHeight
                        }
                    }
                }
                
                // Toggle preference for next square image
                preferRightSide.toggle()
            } else {
                // For non-square images, use original placement logic
                for startColumn in 0...(Int(numberOfBaseColumns) - requiredColumns) {
                    let columnRange = startColumn..<(startColumn + requiredColumns)
                    let spanMaxHeight = columnHeights[columnRange].max() ?? 0
                    if spanMaxHeight < bestHeight {
                        bestColumn = startColumn
                        bestHeight = spanMaxHeight
                    }
                }
            }
            
            // Calculate frame
            let xOffset = CGFloat(bestColumn) * baseColumnWidth
            let width = CGFloat(requiredColumns) * baseColumnWidth
            let height = (imageHeight / imageWidth) * width
            let yOffset = bestHeight
            
            let frame = CGRect(x: xOffset,
                             y: yOffset,
                             width: width,
                             height: height + 50) // Add space for labels
            let insetFrame = frame.insetBy(dx: cellPadding, dy: cellPadding)
            
            // Create and cache layout attributes
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.frame = insetFrame
            cache.append(attributes)
            
            // Update heights for all affected columns
            for column in bestColumn..<(bestColumn + requiredColumns) {
                columnHeights[column] = frame.maxY
            }
            contentHeight = max(contentHeight, frame.maxY)
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return cache.filter { $0.frame.intersects(rect) }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return cache[indexPath.item]
    }
    
    // Add method to randomize starting side
    func randomizeStartingSide() {
        preferRightSide = Bool.random()
    }
}

// MARK: - Mosaic Layout Delegate

protocol MosaicLayoutDelegate: AnyObject {
    func collectionView(_ collectionView: UICollectionView, heightForImageAtIndexPath indexPath: IndexPath) -> CGFloat
    func collectionView(_ collectionView: UICollectionView, widthForImageAtIndexPath indexPath: IndexPath) -> CGFloat
}

class CharacterSelectionViewController: UIViewController {
    // MARK: - Properties
    
    weak var delegate: CharacterSelectionDelegate?
    private var characters: [GameCharacter] = []
    private var filteredCharacters: [GameCharacter] = []
    private var selectedGame: GachaGame?
    private var isDataPopulated = false
    private var preloadedImages: [String: UIImage] = [:]
    private var imageHeights: [String: CGFloat] = [:] // Cache for image heights
    
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
        let layout = MosaicLayout()
        layout.delegate = self
        
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
    
    private func interleaveCharacters(_ characters: [GameCharacter]) -> [GameCharacter] {
        // Split and shuffle characters by game
        var starRailChars = characters.filter { $0.game == .honkaiStarRail }.shuffled()
        var genshinChars = characters.filter { $0.game == .genshinImpact }.shuffled()
        var zenlessChars = characters.filter { $0.game == .zenlessZoneZero }.shuffled()
        
        var result: [GameCharacter] = []
        var insertStarRail = true // Toggle to insert Star Rail more frequently
        
        // Keep going until all characters are used
        while !starRailChars.isEmpty || !genshinChars.isEmpty || !zenlessChars.isEmpty {
            // Try to add a Star Rail character (twice as often)
            if insertStarRail && !starRailChars.isEmpty {
                result.append(starRailChars.removeFirst())
                insertStarRail = false
            }
            // Add Genshin or Zenless character
            else if !genshinChars.isEmpty {
                result.append(genshinChars.removeFirst())
                insertStarRail = true
            }
            else if !zenlessChars.isEmpty {
                result.append(zenlessChars.removeFirst())
                insertStarRail = true
            }
            // If we can't add Genshin/Zenless but still have Star Rail, keep adding them
            else if !starRailChars.isEmpty {
                result.append(starRailChars.removeFirst())
            }
        }
        
        return result
    }
    
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
                            // Randomize starting side before loading new data
                            if let layout = self.collectionView.collectionViewLayout as? MosaicLayout {
                                layout.randomizeStartingSide()
                            }
                            self.characters = interleaveCharacters(characters)
                            self.filteredCharacters = self.characters
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
                    // Randomize starting side before loading new data
                    if let layout = self.collectionView.collectionViewLayout as? MosaicLayout {
                        layout.randomizeStartingSide()
                    }
                    self.characters = interleaveCharacters(characters)
                    self.filteredCharacters = self.characters
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

// MARK: - MosaicLayoutDelegate

extension CharacterSelectionViewController: MosaicLayoutDelegate {
    func collectionView(_ collectionView: UICollectionView, heightForImageAtIndexPath indexPath: IndexPath) -> CGFloat {
        let character = filteredCharacters[indexPath.item]
        
        // Return cached height if available
        if let height = imageHeights[character.id] {
            return height
        }
        
        // Calculate height based on image aspect ratio if image is preloaded
        if let image = preloadedImages[character.id] {
            let aspectRatio = image.size.height / image.size.width
            let baseWidth = collectionView.bounds.width / 6 // Use 6 as base columns
            let aspectType = ImageAspectType.from(aspectRatio: aspectRatio)
            let width = baseWidth * CGFloat(aspectType.columnSpan * 2)
            let height = width * aspectRatio
            imageHeights[character.id] = height
            return height
        }
        
        // Default height if image not yet loaded
        return collectionView.bounds.width / 3 * 1.5
    }
    
    func collectionView(_ collectionView: UICollectionView, widthForImageAtIndexPath indexPath: IndexPath) -> CGFloat {
        let character = filteredCharacters[indexPath.item]
        
        if let image = preloadedImages[character.id] {
            let aspectRatio = image.size.height / image.size.width
            let aspectType = ImageAspectType.from(aspectRatio: aspectRatio)
            let baseWidth = collectionView.bounds.width / 6 // Use 6 as base columns
            return baseWidth * CGFloat(aspectType.columnSpan * 2)
        }
        
        return collectionView.bounds.width / 3 // Default width
    }
}

// MARK: - UICollectionView DataSource & Delegate

extension CharacterSelectionViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        print("📱 CharacterSelectionVC - Number of items in section: \(filteredCharacters.count)")
        return filteredCharacters.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CharacterCell", for: indexPath) as! CharacterCell
        let character = filteredCharacters[indexPath.item]
        
        // Track if this is a new configuration or reuse
        if cell.currentCharacterId != character.id {
            print("📱 CharacterSelectionVC - Initial configuration for: \(character.name)")
            let preloadedImage = preloadedImages[character.id]
            cell.configure(with: character, preloadedImage: preloadedImage)
        } else {
            print("📱 CharacterSelectionVC - Reusing cell for: \(character.name)")
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let character = filteredCharacters[indexPath.item]
        
        // Only update layout if we haven't cached this image's height
        if let cell = cell as? CharacterCell, imageHeights[character.id] == nil {
            cell.onImageLoaded = { [weak self] image in
                guard let self = self,
                      self.imageHeights[character.id] == nil else { return }  // Prevent multiple updates
                
                let aspectRatio = image.size.height / image.size.width
                let width = collectionView.bounds.width / 3 - 2
                self.imageHeights[character.id] = width * aspectRatio
                
                // Force one-time layout update using the new method
                if let layout = collectionView.collectionViewLayout as? MosaicLayout {
                    layout.invalidateLayoutWithUpdate()
                }
            }
        }
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
        if let layout = collectionView.collectionViewLayout as? MosaicLayout {
            layout.randomizeStartingSide()
        }
        if searchText.isEmpty {
            filteredCharacters = characters
        } else {
            filteredCharacters = characters
                .filter { character in
                    character.name.localizedCaseInsensitiveContains(searchText)
                }
                .shuffled()
        }
        collectionView.reloadData()
    }
}

// MARK: - Character Cell

private class CharacterCell: UICollectionViewCell {
    // MARK: - Properties
    
    private(set) var currentCharacterId: String?  // Change to private(set) to allow external reading
    private var loadingTask: Task<Void, Never>?
    private var isImageLoaded = false
    
    var onImageLoaded: ((UIImage) -> Void)?
    
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
            imageView.bottomAnchor.constraint(equalTo: nameLabel.topAnchor, constant: -4),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            nameLabel.bottomAnchor.constraint(equalTo: gameLabel.topAnchor, constant: -2),
            
            gameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            gameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            gameLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
        ])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        cancelLoading()
        // Don't reset these properties during reuse
        // currentCharacterId = nil
        // isImageLoaded = false
    }
    
    private func cancelLoading() {
        loadingTask?.cancel()
        loadingTask = nil
        loadingIndicator.stopAnimating()
    }
    
    func configure(with character: GameCharacter, preloadedImage: UIImage?) {
        // Only reconfigure if this is a different character
        if currentCharacterId != character.id {
            currentCharacterId = character.id
            nameLabel.text = character.name
            gameLabel.text = character.game.rawValue
            isImageLoaded = false  // Reset only when we get a new character
            imageView.image = nil  // Clear image only when we get a new character
            
            // Only load image if not already loaded
            if !isImageLoaded {
                if let preloadedImage = preloadedImage {
                    imageView.image = preloadedImage
                    loadingIndicator.stopAnimating()
                    isImageLoaded = true
                    onImageLoaded?(preloadedImage)
                } else {
                    imageView.image = nil
                    loadingIndicator.startAnimating()
                    
                    CharacterAssetService.shared.getBannerImage(for: character) { [weak self] image in
                        guard let self = self,
                              let image = image,
                              !self.isImageLoaded,
                              self.currentCharacterId == character.id else { return }
                        
                        self.imageView.image = image
                        self.loadingIndicator.stopAnimating()
                        self.isImageLoaded = true
                        self.onImageLoaded?(image)
                    }
                }
            }
        }
    }
} 