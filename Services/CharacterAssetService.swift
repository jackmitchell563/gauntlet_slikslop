import Foundation
import FirebaseStorage
import UIKit

/// Service class for managing character assets (images, banners, etc.)
class CharacterAssetService {
    // MARK: - Properties
    
    /// Shared instance for singleton access
    static let shared = CharacterAssetService()
    
    /// Firebase Storage instance
    private let storage = FirebaseConfig.getStorageInstance()
    
    /// In-memory cache for images
    private let imageCache = NSCache<NSString, UIImage>()
    
    /// Queue for managing asset downloads and state
    private let serialQueue = DispatchQueue(label: "com.slikslop.characterassets.serial")
    
    /// Active download tasks
    private var downloadTasks: [String: Task<UIImage, Error>] = [:]
    
    /// Loading state tracking with thread-safe access
    private var loadingStates: [String: Bool] = [:]
    private var loadingCompletionHandlers: [String: [(UIImage?) -> Void]] = [:]
    
    /// Download semaphore to limit concurrent downloads
    private let downloadSemaphore = DispatchSemaphore(value: 3)
    
    private init() {
        setupCache()
    }
    
    // MARK: - Setup
    
    private func setupCache() {
        imageCache.countLimit = 50 // Reduced from 100
        imageCache.totalCostLimit = 1024 * 1024 * 50 // Reduced to 50 MB
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    // MARK: - Thread-Safe State Access
    
    private func getLoadingState(for id: String) -> Bool {
        serialQueue.sync { loadingStates[id] ?? false }
    }
    
    private func setLoadingState(_ state: Bool, for id: String) {
        serialQueue.sync { loadingStates[id] = state }
    }
    
    private func getCompletionHandlers(for id: String) -> [(UIImage?) -> Void] {
        serialQueue.sync { loadingCompletionHandlers[id] ?? [] }
    }
    
    private func addCompletionHandler(_ handler: @escaping (UIImage?) -> Void, for id: String) {
        serialQueue.sync {
            var handlers = loadingCompletionHandlers[id] ?? []
            handlers.append(handler)
            loadingCompletionHandlers[id] = handlers
        }
    }
    
    private func clearCompletionHandlers(for id: String) {
        serialQueue.sync { loadingCompletionHandlers[id] = nil }
    }
    
    // MARK: - Public Methods
    
    /// Preloads banner images for a list of characters
    /// - Parameter characters: Array of characters whose banners to preload
    /// - Returns: Dictionary mapping character IDs to their loaded banner images
    func preloadBannerImages(for characters: [GameCharacter]) async -> [String: UIImage] {
        print("📱 CharacterAssetService - Preloading banners for \(characters.count) characters")
        
        var loadedImages: [String: UIImage] = [:]
        let loadedImagesQueue = DispatchQueue(label: "com.slikslop.characterassets.loadedimages")
        
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for character in characters {
                group.addTask {
                    do {
                        if let image = try? await self.loadBannerImage(for: character) {
                            return (character.id, image)
                        }
                    } catch {
                        print("❌ CharacterAssetService - Error loading banner for \(character.id): \(error)")
                    }
                    return (character.id, nil)
                }
            }
            
            for await (characterId, image) in group {
                if let image = image {
                    loadedImagesQueue.sync {
                        loadedImages[characterId] = image
                    }
                }
            }
        }
        
        print("📱 CharacterAssetService - Preloaded \(loadedImages.count) banners")
        return loadedImages
    }
    
    /// Gets a banner image for a character, either from cache or loads it
    /// - Parameters:
    ///   - character: The character whose banner to get
    ///   - completion: Completion handler called with the loaded image
    func getBannerImage(for character: GameCharacter, completion: @escaping (UIImage?) -> Void) {
        // Check cache first
        if let cachedImage = imageCache.object(forKey: character.bannerImageURL as NSString) {
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        }
        
        // If already loading, add completion handler to queue
        if getLoadingState(for: character.id) {
            addCompletionHandler(completion, for: character.id)
            return
        }
        
        // Start loading
        setLoadingState(true, for: character.id)
        addCompletionHandler(completion, for: character.id)
        
        Task {
            do {
                let image = try await loadBannerImage(for: character)
                await MainActor.run {
                    self.imageCache.setObject(image, forKey: character.bannerImageURL as NSString)
                    self.completeLoading(for: character.id, with: image)
                }
            } catch {
                print("❌ CharacterAssetService - Error loading banner for \(character.id): \(error)")
                await MainActor.run {
                    self.completeLoading(for: character.id, with: nil)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func completeLoading(for characterId: String, with image: UIImage?) {
        let handlers = getCompletionHandlers(for: characterId)
        setLoadingState(false, for: characterId)
        clearCompletionHandlers(for: characterId)
        
        handlers.forEach { handler in
            DispatchQueue.main.async {
                handler(image)
            }
        }
    }
    
    /// Internal method to load a banner image
    private func loadBannerImage(for character: GameCharacter) async throws -> UIImage {
        // Enforce download limit
        downloadSemaphore.wait()
        defer { downloadSemaphore.signal() }
        
        print("📱 CharacterAssetService - Loading banner for character: \(character.id)")
        
        // Check cache first
        if let cachedImage = imageCache.object(forKey: character.bannerImageURL as NSString) {
            print("📱 CharacterAssetService - Returning cached banner")
            return cachedImage
        }
        
        // Check existing task
        if let existingTask = serialQueue.sync(execute: { downloadTasks[character.bannerImageURL] }) {
            print("📱 CharacterAssetService - Using existing download task")
            return try await existingTask.value
        }
        
        // Create new download task
        let downloadTask = Task<UIImage, Error> {
            print("📱 CharacterAssetService - Starting banner download")
            
            guard let url = URL(string: character.bannerImageURL) else {
                throw AssetError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            request.setValue("*/*", forHTTPHeaderField: "Accept")
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 15 // Add timeout
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // Handle redirect
                if let httpResponse = response as? HTTPURLResponse,
                   (300...399).contains(httpResponse.statusCode),
                   let location = httpResponse.value(forHTTPHeaderField: "Location"),
                   let redirectURL = URL(string: location) {
                    let (redirectData, _) = try await URLSession.shared.data(from: redirectURL)
                    guard let image = UIImage(data: redirectData) else {
                        throw AssetError.invalidImageData
                    }
                    return image
                }
                
                guard let image = UIImage(data: data) else {
                    throw AssetError.invalidImageData
                }
                
                return image
            } catch {
                throw AssetError.downloadFailed(error)
            }
        }
        
        // Store task
        serialQueue.sync { downloadTasks[character.bannerImageURL] = downloadTask }
        
        do {
            let image = try await downloadTask.value
            serialQueue.sync { downloadTasks[character.bannerImageURL] = nil }
            return image
        } catch {
            serialQueue.sync { downloadTasks[character.bannerImageURL] = nil }
            throw error
        }
    }
    
    /// Preloads assets for all characters from a specific game
    /// - Parameter game: The game whose character assets to preload
    func preloadAssets(for game: GachaGame) async {
        print("📱 CharacterAssetService - Preloading assets for \(game.rawValue)")
        
        do {
            let characters = try await CharacterService.shared.fetchCharacters(game: game)
            
            // Create a task group for concurrent downloads
            try await withThrowingTaskGroup(of: Void.self) { group in
                for character in characters {
                    group.addTask {
                        _ = try await self.loadBannerImage(for: character)
                    }
                }
                
                // Wait for all downloads to complete
                try await group.waitForAll()
            }
            
            print("📱 CharacterAssetService - Preloaded assets for \(characters.count) characters")
        } catch {
            print("❌ CharacterAssetService - Error preloading assets: \(error)")
        }
    }
    
    /// Ensures a character's assets are loaded and cached
    /// - Parameter character: The character whose assets to warm up
    func warmupAssets(for character: GameCharacter) async {
        print("📱 CharacterAssetService - Warming up assets for character: \(character.id)")
        
        do {
            _ = try await loadBannerImage(for: character)
            print("📱 CharacterAssetService - Assets warmed up successfully")
        } catch {
            print("❌ CharacterAssetService - Error warming up assets: \(error)")
        }
    }
    
    // MARK: - Cache Management
    
    /// Clears the asset cache
    @objc func clearCache() {
        serialQueue.sync {
            print("📱 CharacterAssetService - Clearing asset cache")
            imageCache.removeAllObjects()
            downloadTasks.values.forEach { $0.cancel() }
            downloadTasks.removeAll()
            loadingStates.removeAll()
            loadingCompletionHandlers.removeAll()
        }
    }
    
    /// Removes specific assets from the cache
    /// - Parameter urls: Array of asset URLs to remove
    func removeFromCache(_ urls: [String]) {
        serialQueue.sync {
            print("📱 CharacterAssetService - Removing \(urls.count) assets from cache")
            urls.forEach { url in
                imageCache.removeObject(forKey: url as NSString)
                downloadTasks[url]?.cancel()
                downloadTasks[url] = nil
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Errors

enum AssetError: LocalizedError {
    case invalidURL
    case invalidImageData
    case downloadFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid asset URL"
        case .invalidImageData:
            return "Invalid image data"
        case .downloadFailed(let error):
            return "Asset download failed: \(error.localizedDescription)"
        }
    }
} 