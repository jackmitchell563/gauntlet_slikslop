import Foundation

/// A disk-based implementation of VideoCacheProviding that manages video caching on disk
final class DiskVideoCache: VideoCacheProviding {
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let queue = DispatchQueue(label: "com.slikslop.videocache")
    private let metadataFile: URL
    
    /// Metadata for cache management
    private var cacheEntries: [String: VideoCacheKey] = [:]
    
    // MARK: - Initialization
    
    init(directory: URL) throws {
        self.cacheDirectory = directory
        self.metadataFile = directory.appendingPathComponent("metadata.json")
        try setupCache()
    }
    
    // MARK: - Private Setup
    
    private func setupCache() throws {
        try fileManager.createDirectory(at: cacheDirectory, 
                                     withIntermediateDirectories: true,
                                     attributes: nil)
        loadMetadata()
    }
    
    private func loadMetadata() {
        guard let data = try? Data(contentsOf: metadataFile),
              let entries = try? JSONDecoder().decode([String: VideoCacheKey].self, from: data) else {
            return
        }
        cacheEntries = entries
    }
    
    private func saveMetadata() {
        guard let data = try? JSONEncoder().encode(cacheEntries) else { return }
        try? data.write(to: metadataFile)
    }
    
    private func cacheURL(for key: String) -> URL {
        return cacheDirectory.appendingPathComponent(key)
    }
    
    // MARK: - VideoCacheProviding
    
    func store(_ data: Data, for key: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let fileURL = self.cacheURL(for: key)
                    try data.write(to: fileURL)
                    self.updateMetadata(for: key, size: data.count)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func retrieve(for key: String) async throws -> Data? {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let fileURL = self.cacheURL(for: key)
                guard self.fileManager.fileExists(atPath: fileURL.path) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                do {
                    let data = try Data(contentsOf: fileURL)
                    self.updateMetadata(for: key, size: data.count)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func remove(for key: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let fileURL = self.cacheURL(for: key)
                    try? self.fileManager.removeItem(at: fileURL)
                    self.cacheEntries.removeValue(forKey: key)
                    self.saveMetadata()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func clear() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try? self.fileManager.removeItem(at: self.cacheDirectory)
                    try self.fileManager.createDirectory(at: self.cacheDirectory,
                                                       withIntermediateDirectories: true,
                                                       attributes: nil)
                    self.cacheEntries.removeAll()
                    self.saveMetadata()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    var totalCacheSize: Int64 {
        get async {
            await withCheckedContinuation { continuation in
                queue.async {
                    let total = Int64(self.cacheEntries.values.reduce(0) { $0 + $1.size })
                    continuation.resume(returning: total)
                }
            }
        }
    }
    
    // MARK: - Cache Entry Access
    
    /// Get cache entries sorted by last access date (oldest first)
    func getSortedEntries() async -> [(key: String, value: VideoCacheKey)] {
        return await withCheckedContinuation { continuation in
            queue.async {
                let sorted = self.cacheEntries.sorted { $0.value.lastAccessDate < $1.value.lastAccessDate }
                continuation.resume(returning: sorted)
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func updateMetadata(for key: String, size: Int) {
        let components = key.components(separatedBy: "_")
        let entry = VideoCacheKey(
            videoId: components.first ?? key,
            quality: VideoQuality(rawValue: components.last ?? "") ?? .auto,
            lastAccessDate: Date(),
            size: size
        )
        cacheEntries[key] = entry
        saveMetadata()
    }
} 