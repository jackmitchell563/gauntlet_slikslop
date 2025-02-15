import Foundation

/// Configuration manager for accessing app-wide settings and API keys
struct Configuration {
    /// Shared instance for singleton access
    static let shared = Configuration()
    
    /// Error types for configuration-related issues
    enum ConfigurationError: LocalizedError {
        case missingKey(String)
        
        var errorDescription: String? {
            switch self {
            case .missingKey(let key):
                return "Missing configuration value for key: \(key)"
            }
        }
    }
    
    // MARK: - API Keys
    
    /// OpenAI API key
    var openAIKey: String {
        get throws {
            try getValue(for: "OPENAI_API_KEY")
        }
    }
    
    /// Fish Audio API key
    var fishAudioKey: String {
        get throws {
            try getValue(for: "FISH_AUDIO_API_KEY")
        }
    }
    
    /// Replicate API key
    var replicateKey: String {
        get throws {
            try getValue(for: "REPLICATE_API_KEY")
        }
    }
    
    /// CivitAI API token
    var civitAIToken: String {
        get throws {
            try getValue(for: "CIVITAI_API_TOKEN")
        }
    }
    
    // MARK: - App Configuration
    
    /// App name from configuration
    var appName: String {
        get throws {
            try getValue(for: "APP_NAME")
        }
    }
    
    /// Bundle identifier from configuration
    var bundleIdentifier: String {
        get throws {
            try getValue(for: "PRODUCT_BUNDLE_IDENTIFIER")
        }
    }
    
    // MARK: - Private Methods
    
    /// Gets a configuration value for the specified key
    /// - Parameter key: The configuration key to look up
    /// - Returns: The configuration value
    /// - Throws: ConfigurationError if the value is missing
    private func getValue(for key: String) throws -> String {
        guard let value = Bundle.main.infoDictionary?[key] as? String else {
            throw ConfigurationError.missingKey(key)
        }
        
        // Don't return placeholder values
        if value.contains("your_") || value.contains("_here") {
            throw ConfigurationError.missingKey(key)
        }
        
        return value
    }
    
    private init() {}
} 