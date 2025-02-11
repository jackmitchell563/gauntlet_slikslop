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
    
    /// In-memory cache for images with enhanced statistics tracking
    private let imageCache = NSCache<NSString, UIImage>()
    
    /// Cache statistics
    private var cacheHits = 0
    private var cacheMisses = 0
    private var totalBytesLoaded = 0
    
    /// Download statistics
    private var activeDownloads = 0
    private var totalDownloads = 0
    private var failedDownloads = 0
    private var downloadStartTimes: [String: Date] = [:]
    
    /// Queue for managing asset downloads and state
    private let serialQueue = DispatchQueue(label: "com.slikslop.characterassets.serial")
    
    /// Active download tasks with enhanced tracking
    private var downloadTasks: [String: Task<UIImage, Error>] = [:]
    
    /// Loading state tracking with thread-safe access
    private var loadingStates: [String: Bool] = [:]
    private var loadingCompletionHandlers: [String: [(UIImage?) -> Void]] = [:]
    
    /// Download semaphore to limit concurrent downloads
    private let downloadSemaphore = DispatchSemaphore(value: 3)
    
    private let bannerCache = NSCache<NSString, UIImage>()
    private let profileCache = NSCache<NSString, UIImage>()
    
    private init() {
        setupCache()
    }
    
    // MARK: - Setup
    
    private func setupCache() {
        imageCache.countLimit = 50 // Reduced from 100
        imageCache.totalCostLimit = 1024 * 1024 * 50 // 50 MB
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        print("📱 CharacterAssetService - Cache initialized with \(imageCache.countLimit) item limit and \(imageCache.totalCostLimit / 1024 / 1024)MB total limit")
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
    
    /// Preloads banner images for a list of characters with enhanced optimization
    func preloadBannerImages(for characters: [GameCharacter]) async -> [String: UIImage] {
        print("📱 CharacterAssetService - Starting optimized banner preload for \(characters.count) characters")
        
        var loadedImages: [String: UIImage] = [:]
        let loadedImagesQueue = DispatchQueue(label: "com.slikslop.characterassets.loadedimages")
        
        // First check cache for all characters
        for character in characters {
            if let cachedImage = getCachedImage(for: character.bannerImageURL) {
                loadedImagesQueue.sync {
                    loadedImages[character.id] = cachedImage
                }
            }
        }
        
        // Filter out characters that are already being downloaded
        let remainingCharacters = characters.filter { character in
            loadedImages[character.id] == nil && 
            serialQueue.sync(execute: { downloadTasks[character.bannerImageURL] == nil })
        }
        
        if !remainingCharacters.isEmpty {
            print("📱 CharacterAssetService - Found \(loadedImages.count) cached images, loading \(remainingCharacters.count) remaining")
            
            await withTaskGroup(of: (String, UIImage?).self) { group in
                for character in remainingCharacters {
                    group.addTask {
                        do {
                            let image = try await self.loadBannerImage(for: character)
                            return (character.id, image)
                        } catch {
                            print("❌ CharacterAssetService - Failed to load banner for \(character.id): \(error)")
                            return (character.id, nil)
                        }
                    }
                }
                
                // Collect successful results
                for await (characterId, image) in group {
                    if let image = image {
                        loadedImagesQueue.sync {
                            loadedImages[characterId] = image
                        }
                    }
                }
            }
        } else {
            print("📱 CharacterAssetService - All banners found in cache")
        }
        
        print("📱 CharacterAssetService - Completed banner preload with \(loadedImages.count) images")
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
    
    /// Loads a banner image for a character, either from cache or downloads it
    /// - Parameter character: The character whose banner to load
    /// - Returns: The loaded UIImage
    func loadBannerImage(for character: GameCharacter) async throws -> UIImage {
        // Check cache first using enhanced cache method
        if let cachedImage = getCachedImage(for: character.bannerImageURL) {
            print("📱 CharacterAssetService - Returning cached banner for \(character.id)")
            return cachedImage
        }
        
        return try await loadBannerImageFromNetwork(for: character)
    }
    
    /// Preloads profile images for the given characters
    /// - Parameter characters: Characters whose profile images should be preloaded
    /// - Returns: Dictionary mapping character IDs to their profile images
    func preloadProfileImages(for characters: [GameCharacter]) async -> [String: UIImage] {
        print("📱 CharacterAssetService - Starting profile image preload for \(characters.count) characters")
        var profileImages: [String: UIImage] = [:]
        let loadedImagesQueue = DispatchQueue(label: "com.slikslop.characterassets.loadedimages")
        
        // First check cache for all characters
        for character in characters {
            if let cachedImage = profileCache.object(forKey: character.id as NSString) {
                loadedImagesQueue.sync {
                    profileImages[character.id] = cachedImage
                }
            }
        }
        
        // Filter out characters that are already cached
        let remainingCharacters = characters.filter { character in
            profileImages[character.id] == nil
        }
        
        if !remainingCharacters.isEmpty {
            print("📱 CharacterAssetService - Found \(profileImages.count) cached images, downloading \(remainingCharacters.count) remaining")
            
            await withTaskGroup(of: (String, UIImage?).self) { group in
                for character in remainingCharacters {
                    group.addTask {
                        do {
                            guard let url = URL(string: character.profileImageURL) else {
                                print("❌ CharacterAssetService - Invalid profile URL for character: \(character.id)")
                                return (character.id, nil)
                            }
                            
                            let (data, _) = try await URLSession.shared.data(from: url)
                            if let image = UIImage(data: data) {
                                // Cache the loaded image
                                self.profileCache.setObject(image, forKey: character.id as NSString)
                                print("📱 CharacterAssetService - Successfully loaded profile image for: \(character.id)")
                                return (character.id, image)
                            }
                        } catch {
                            print("❌ CharacterAssetService - Error loading profile image for \(character.id): \(error)")
                        }
                        return (character.id, nil)
                    }
                }
                
                for await (id, image) in group {
                    if let image = image {
                        loadedImagesQueue.sync {
                            profileImages[id] = image
                        }
                    }
                }
            }
        } else {
            print("📱 CharacterAssetService - All profile images found in cache")
        }
        
        print("📱 CharacterAssetService - Completed profile image preload with \(profileImages.count) images")
        return profileImages
    }
    
    /// Warms up assets for a specific character by preloading both banner and profile images
    /// - Parameter character: Character whose assets should be warmed up
    func warmupAssets(for character: GameCharacter) async {
        print("📱 CharacterAssetService - Warming up assets for character: \(character.id)")
        
        await withTaskGroup(of: Void.self) { group in
            // Warm up banner image
            group.addTask {
                do {
                    _ = try await self.loadBannerImage(for: character)
                    print("📱 CharacterAssetService - Successfully warmed up banner for: \(character.id)")
                } catch {
                    print("❌ CharacterAssetService - Error warming up banner for \(character.id): \(error)")
                }
            }
            
            // Warm up profile image
            group.addTask {
                if let image = await self.loadProfileImage(for: character) {
                    print("📱 CharacterAssetService - Successfully warmed up profile for: \(character.id)")
                } else {
                    print("❌ CharacterAssetService - Failed to warm up profile for: \(character.id)")
                }
            }
        }
    }
    
    /// Loads a profile image for a character, using cached version if available
    /// - Parameter character: Character whose profile image should be loaded
    /// - Returns: The loaded profile image, or nil if loading failed
    func loadProfileImage(for character: GameCharacter) async -> UIImage? {
        // Check cache first
        if let cachedImage = profileCache.object(forKey: character.id as NSString) {
            return cachedImage
        }
        
        // Load from asset catalog with proper namespacing
        let imageName = "Characters/Profiles/profile_\(character.id)"
        if let image = UIImage(named: imageName) {
            // Cache the loaded image
            profileCache.setObject(image, forKey: character.id as NSString)
            print("📱 CharacterAssetService - Successfully loaded profile from assets for: \(character.id)")
            return image
        }
        
        print("❌ CharacterAssetService - Failed to load profile from assets for \(character.id)")
        print("📱 CharacterAssetService - Attempted to load image named: \(imageName)")
        return nil
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
    
    // MARK: - Resource Loading Helpers
    
    private func resourceURL(for filename: String, in directory: String) -> URL? {
        // First try the main bundle
        if let url = Bundle.main.url(forResource: filename, withExtension: "png") {
            return url
        }
        
        // Then try with the directory path
        if let resourcePath = Bundle.main.resourcePath {
            let fullPath = (resourcePath as NSString).appendingPathComponent(directory)
            let fileURL = (fullPath as NSString).appendingPathComponent(filename + ".png")
            if FileManager.default.fileExists(atPath: fileURL) {
                return URL(fileURLWithPath: fileURL)
            }
            print("📱 CharacterAssetService - Checked path: \(fileURL)")
        }
        
        return nil
    }
    
    /// Internal method to load a banner image with enhanced download tracking
    private func loadBannerImageFromNetwork(for character: GameCharacter) async throws -> UIImage {
        print("📱 CharacterAssetService - Loading banner for character: \(character.id)")
        
        // Load from asset catalog with proper namespacing
        let imageName = "Characters/Banners/banner_\(character.id)"
        if let image = UIImage(named: imageName) {
            print("📱 CharacterAssetService - Successfully loaded banner from assets for \(character.id)")
            self.cacheImage(image, for: character.bannerImageURL)
            return image
        }
        
        print("❌ CharacterAssetService - Failed to load banner from assets for \(character.id)")
        print("📱 CharacterAssetService - Attempted to load image named: \(imageName)")
        throw AssetError.invalidImageData
    }
    
    /// Preloads assets for all characters from a specific game
    /// - Parameter game: The game whose character assets to preload
    func preloadAssets(for game: GachaGame) async {
        print("📱 CharacterAssetService - Preloading assets for \(game.rawValue)")
        
        do {
            let characters = try await CharacterService.shared.fetchCharacters(game: game)
            
            // Create task group for concurrent loading
            await withTaskGroup(of: Void.self) { group in
                // Add banner preload task
                group.addTask {
                    _ = await self.preloadBannerImages(for: characters)
                }
                
                // Add profile preload task
                group.addTask {
                    _ = await self.preloadProfileImages(for: characters)
                }
                
                // Wait for all loads to complete
                await group.waitForAll()
            }
            
            print("📱 CharacterAssetService - Preloaded assets for \(characters.count) characters")
        } catch {
            print("❌ CharacterAssetService - Error preloading assets: \(error)")
        }
    }
    
    // MARK: - Cache Management
    
    /// Enhanced cache checking method with statistics
    /// - Parameter url: The URL string of the image to check in cache
    /// - Returns: The cached UIImage if found, nil otherwise
    func getCachedImage(for url: String) -> UIImage? {
        if let image = imageCache.object(forKey: url as NSString) {
            serialQueue.sync {
                cacheHits += 1
                print("📱 CharacterAssetService - Cache hit (\(cacheHits) total) for: \(url)")
            }
            return image
        }
        serialQueue.sync {
            cacheMisses += 1
            print("📱 CharacterAssetService - Cache miss (\(cacheMisses) total) for: \(url)")
        }
        return nil
    }
    
    /// Enhanced cache storing method with size tracking
    private func cacheImage(_ image: UIImage, for url: String) {
        let imageSize = Int(image.size.width * image.size.height * 4) // Approximate size in bytes (RGBA)
        serialQueue.sync {
            totalBytesLoaded += imageSize
            print("📱 CharacterAssetService - Caching image for: \(url) (Size: \(imageSize / 1024)KB, Total: \(totalBytesLoaded / 1024 / 1024)MB)")
        }
        imageCache.setObject(image, forKey: url as NSString)
    }
    
    /// Gets cache statistics
    func getCacheStats() -> (hits: Int, misses: Int, hitRate: Double, totalMB: Double) {
        return serialQueue.sync {
            let total = cacheHits + cacheMisses
            let hitRate = total > 0 ? Double(cacheHits) / Double(total) : 0
            return (cacheHits, cacheMisses, hitRate, Double(totalBytesLoaded) / 1024 / 1024)
        }
    }
    
    /// Clears the asset cache with enhanced logging
    @objc func clearCache() {
        serialQueue.sync {
            let stats = getCacheStats()
            print("""
                📱 CharacterAssetService - Clearing asset cache
                Cache Statistics:
                - Hits: \(stats.hits)
                - Misses: \(stats.misses)
                - Hit Rate: \(String(format: "%.2f%%", stats.hitRate * 100))
                - Total Data Loaded: \(String(format: "%.2fMB", stats.totalMB))
                """)
            
            imageCache.removeAllObjects()
            downloadTasks.values.forEach { $0.cancel() }
            downloadTasks.removeAll()
            loadingStates.removeAll()
            loadingCompletionHandlers.removeAll()
            
            // Reset statistics
            cacheHits = 0
            cacheMisses = 0
            totalBytesLoaded = 0
        }
    }
    
    /// Removes specific assets from the cache with enhanced logging
    func removeFromCache(_ urls: [String]) {
        serialQueue.sync {
            print("📱 CharacterAssetService - Removing \(urls.count) assets from cache")
            urls.forEach { url in
                if let image = imageCache.object(forKey: url as NSString) {
                    let imageSize = Int(image.size.width * image.size.height * 4)
                    totalBytesLoaded -= imageSize
                    imageCache.removeObject(forKey: url as NSString)
                    downloadTasks[url]?.cancel()
                    downloadTasks[url] = nil
                    print("📱 CharacterAssetService - Removed image: \(url) (Size: \(imageSize / 1024)KB)")
                }
            }
            print("📱 CharacterAssetService - Current cache size: \(totalBytesLoaded / 1024 / 1024)MB")
        }
    }
    
    // MARK: - Download Management
    
    /// Tracks the start of a download
    private func trackDownloadStart(for url: String) {
        serialQueue.sync {
            activeDownloads += 1
            totalDownloads += 1
            downloadStartTimes[url] = Date()
            print("📱 CharacterAssetService - Starting download (\(activeDownloads) active, \(totalDownloads) total)")
        }
    }
    
    /// Tracks the completion of a download
    private func trackDownloadComplete(for url: String, success: Bool) {
        serialQueue.sync {
            activeDownloads -= 1
            if !success { failedDownloads += 1 }
            
            if let startTime = downloadStartTimes[url] {
                let duration = Date().timeIntervalSince(startTime)
                print("📱 CharacterAssetService - Download completed in \(String(format: "%.2f", duration))s (\(success ? "success" : "failed"))")
                downloadStartTimes[url] = nil
            }
            
            let successRate = totalDownloads > 0 ? 
                Double(totalDownloads - failedDownloads) / Double(totalDownloads) * 100 : 0
            print("📱 CharacterAssetService - Download stats: \(activeDownloads) active, \(totalDownloads) total, \(String(format: "%.1f", successRate))% success rate")
        }
    }
    
    /// Optimized batch download method
    private func downloadBannerImages(for characters: [GameCharacter], batchSize: Int = 3) async -> [String: UIImage] {
        var results: [String: UIImage] = [:]
        let resultsQueue = DispatchQueue(label: "com.slikslop.characterassets.results")
        
        // Create batches
        let batches = stride(from: 0, to: characters.count, by: batchSize).map {
            Array(characters[($0)..<min($0 + batchSize, characters.count)])
        }
        
        for (index, batch) in batches.enumerated() {
            print("📱 CharacterAssetService - Processing batch \(index + 1)/\(batches.count)")
            
            do {
                // Process batch concurrently
                try await withThrowingTaskGroup(of: (String, UIImage?).self) { group in
                    for character in batch {
                        // Skip if we already have a download in progress
                        if serialQueue.sync(execute: { downloadTasks[character.bannerImageURL] != nil }) {
                            print("📱 CharacterAssetService - Download already in progress for \(character.id)")
                            continue
                        }
                        
                        group.addTask {
                            do {
                                let image = try await self.loadBannerImage(for: character)
                                return (character.id, image)
                            } catch {
                                print("❌ CharacterAssetService - Batch download failed for \(character.id): \(error)")
                                return (character.id, nil)
                            }
                        }
                    }
                    
                    // Collect successful results
                    for try await (characterId, image) in group {
                        if let image = image {
                            resultsQueue.sync {
                                results[characterId] = image
                            }
                        }
                    }
                }
            } catch {
                print("❌ CharacterAssetService - Error processing batch \(index + 1): \(error)")
                // Continue with next batch even if this one failed
                continue
            }
            
            // Add delay between batches if not the last batch
            if index < batches.count - 1 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
            }
        }
        
        return results
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
    case timeout
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid asset URL"
        case .invalidImageData:
            return "Invalid image data"
        case .downloadFailed(let error):
            return "Asset download failed: \(error.localizedDescription)"
        case .timeout:
            return "Asset download timed out"
        case .serverError(let code):
            return "Server returned error: \(code)"
        }
    }
} 