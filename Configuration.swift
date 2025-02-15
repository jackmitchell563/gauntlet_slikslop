import Foundation

/// Configuration manager for accessing app-wide settings and API keys
struct Configuration {
    /// Shared instance for singleton access
    static let shared = Configuration()
    
    /// Error types for configuration-related issues
    enum ConfigurationError: LocalizedError {
        case missingKey(String)
        case configFileNotFound
        
        var errorDescription: String? {
            switch self {
            case .missingKey(let key):
                return "Missing configuration value for key: \(key)"
            case .configFileNotFound:
                return "Config.xcconfig file not found"
            }
        }
    }
    
    // MARK: - Properties
    
    private let configurationDictionary: [String: String]
    
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
    
    private init() {
        // Try to load configuration from xcconfig file
        if let configURL = Bundle.main.url(forResource: "Config", withExtension: "xcconfig") {
            do {
                let contents = try String(contentsOf: configURL, encoding: .utf8)
                var dict = [String: String]()
                
                // Parse xcconfig file
                contents.components(separatedBy: .newlines).forEach { line in
                    let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                    // Skip comments and empty lines
                    guard !trimmedLine.isEmpty,
                          !trimmedLine.hasPrefix("//"),
                          !trimmedLine.hasPrefix("/*") else {
                        return
                    }
                    
                    // Split on first = sign
                    let components = trimmedLine.split(separator: "=", maxSplits: 1)
                    if components.count == 2 {
                        let key = String(components[0]).trimmingCharacters(in: .whitespaces)
                        let value = String(components[1]).trimmingCharacters(in: .whitespaces)
                        dict[key] = value
                    }
                }
                
                configurationDictionary = dict
                print("📱 Configuration - Loaded \(dict.count) values from Config.xcconfig")
            } catch {
                print("❌ Configuration - Error reading Config.xcconfig: \(error)")
                configurationDictionary = [:]
            }
        } else {
            print("❌ Configuration - Config.xcconfig not found in bundle")
            configurationDictionary = [:]
        }
    }
    
    /// Gets a configuration value for the specified key
    /// - Parameter key: The configuration key to look up
    /// - Returns: The configuration value
    /// - Throws: ConfigurationError if the value is missing
    private func getValue(for key: String) throws -> String {
        print("📱 Configuration - Looking up key: \(key)")
        
        // First try xcconfig dictionary
        if let value = configurationDictionary[key] {
            print("📱 Configuration - Found value in Config.xcconfig for '\(key)'")
            return value
        }
        
        // Fall back to Info.plist
        guard let value = Bundle.main.infoDictionary?[key] as? String else {
            print("❌ Configuration - Key '\(key)' not found in Config.xcconfig or Info.plist")
            throw ConfigurationError.missingKey(key)
        }
        
        print("📱 Configuration - Found value in Info.plist for '\(key)'")
        
        // Don't return placeholder values
        if value.contains("your_") || value.contains("_here") {
            print("❌ Configuration - Value for '\(key)' appears to be a placeholder")
            throw ConfigurationError.missingKey(key)
        }
        
        return value
    }
} 