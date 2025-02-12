import Foundation
import CoreML
import StableDiffusion
import Metal
import UIKit

/// Service for handling local stable diffusion image generation
class StableDiffusionService {
    // MARK: - Properties
    
    /// Shared instance for singleton access
    static let shared = StableDiffusionService()
    
    /// CoreML pipeline for image generation
    private var pipeline: StableDiffusionPipeline?
    
    /// LoRA weights for model customization
    private var loraWeights: MLModel?
    
    /// Queue for background processing
    private let processingQueue = DispatchQueue(label: "com.slikslop.stablediffusion", qos: .userInitiated)
    
    /// Operation queue for managing concurrent image generations
    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.slikslop.stablediffusion.operations"
        queue.maxConcurrentOperationCount = 1  // Process one image at a time
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
    /// Whether models are currently loaded
    private var isModelLoaded = false
    
    /// Timer for unloading models after inactivity
    private var unloadTimer: Timer?
    
    /// Time interval before unloading models (5 minutes)
    private let unloadInterval: TimeInterval = 300
    
    /// Whether a model load is in progress
    private var isLoadingModel = false
    
    /// Queue of pending image generation requests
    private var pendingRequests: [(String, String, CheckedContinuation<UIImage, Error>)] = []
    
    // MARK: - Types
    
    enum StableDiffusionError: LocalizedError {
        case modelNotLoaded
        case pipelineError(String)
        case resourceConstraint(String)
        case deviceNotSupported
        case modelFilesNotFound
        case modelDirectoryCreationFailed
        
        var errorDescription: String? {
            switch self {
            case .modelNotLoaded:
                return "Stable diffusion models not loaded"
            case .pipelineError(let message):
                return "Pipeline error: \(message)"
            case .resourceConstraint(let resource):
                return "Resource constraint: \(resource)"
            case .deviceNotSupported:
                return "Device does not support required GPU features"
            case .modelFilesNotFound:
                return "Required model files not found"
            case .modelDirectoryCreationFailed:
                return "Failed to create model directory"
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Debug: Print all resources in bundle
        if let resourcePath = Bundle.main.resourcePath {
            print("📱 StableDiffusionService - Bundle resources:")
            let files = try? FileManager.default.contentsOfDirectory(atPath: resourcePath)
            files?.forEach { print("  - \($0)") }
        }
    }
    
    // MARK: - Setup
    
    /// Checks if required model files are available
    func areModelFilesAvailable() -> Bool {
        do {
            _ = try getModelURL()
            return true
        } catch {
            return false
        }
    }
    
    /// Downloads required model files if needed
    /// - Parameter progress: Closure to report download progress
    func downloadModelFilesIfNeeded(progress: ((Double) -> Void)? = nil) async throws {
        // Check if files already exist
        if areModelFilesAvailable() {
            progress?(1.0)
            return
        }
        
        // If files don't exist in the bundle, we can't download them
        // They must be included in the app bundle
        throw StableDiffusionError.modelFilesNotFound
    }
    
    /// Gets the URL for the CoreML model
    private func getModelURL() throws -> URL {
        // Print bundle URL for debugging
        if let bundleURL = Bundle.main.resourceURL {
            print("📱 StableDiffusionService - Bundle URL: \(bundleURL)")
            
            // Print all subdirectories and files
            print("📱 StableDiffusionService - Bundle contents:")
            if let enumerator = FileManager.default.enumerator(at: bundleURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    let indent = String(repeating: "  ", count: fileURL.pathComponents.count - bundleURL.pathComponents.count)
                    print("\(indent)- \(isDirectory ? "📁" : "📄") \(fileURL.lastPathComponent)")
                }
            }
        }
        
        // Look for CoreMLModel directory directly in the bundle
        guard let bundleURL = Bundle.main.resourceURL else {
            print("❌ StableDiffusionService - Bundle URL not found")
            throw StableDiffusionError.modelFilesNotFound
        }
        
        let modelURL = bundleURL.appendingPathComponent("CoreMLModel")
        
        // Check if model exists and is a directory
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: modelURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            print("❌ StableDiffusionService - CoreMLModel exists: \(FileManager.default.fileExists(atPath: modelURL.path)), isDirectory: \(isDirectory.boolValue)")
            print("❌ StableDiffusionService - Attempted path: \(modelURL.path)")
            throw StableDiffusionError.modelFilesNotFound
        }
        
        // Verify all required components are present
        let requiredComponents = [
            "TextEncoder.mlmodelc",
            "Unet.mlmodelc",
            "VAEDecoder.mlmodelc",
            "VAEEncoder.mlmodelc",
            "vocab.json",
            "merges.txt"
        ]
        
        print("📱 StableDiffusionService - Verifying model components:")
        for component in requiredComponents {
            let componentURL = modelURL.appendingPathComponent(component)
            let exists = FileManager.default.fileExists(atPath: componentURL.path)
            print("  - \(component): \(exists ? "✅" : "❌")")
            
            if !exists {
                print("❌ StableDiffusionService - Missing required component: \(component)")
                throw StableDiffusionError.modelFilesNotFound
            }
            
            // If this is TextEncoder.mlmodelc, check its coremldata.bin
            if component == "TextEncoder.mlmodelc" {
                let binURL = componentURL.appendingPathComponent("coremldata.bin")
                if let data = try? Data(contentsOf: binURL, options: .mappedIfSafe) {
                    print("📱 StableDiffusionService - TextEncoder coremldata.bin size: \(data.count) bytes")
                    if data.count >= 4 {
                        let firstFourBytes = data.prefix(4)
                        print("📱 StableDiffusionService - First 4 bytes: \(Array(firstFourBytes))")
                        // Convert to hex for better visibility
                        let hexString = firstFourBytes.map { String(format: "%02X", $0) }.joined()
                        print("📱 StableDiffusionService - First 4 bytes (hex): 0x\(hexString)")
                    }
                } else {
                    print("❌ StableDiffusionService - Could not read TextEncoder coremldata.bin")
                }
            }
        }
        
        print("📱 StableDiffusionService - Found CoreMLModel with all components at: \(modelURL.path)")
        return modelURL
    }
    
    /// Gets the URL for the LoRA weights
    private func getLoRAURL() throws -> URL {
        // Look directly in the bundle
        guard let loraURL = Bundle.main.url(
            forResource: "GachaSplash4",
            withExtension: "safetensors"
        ) else {
            print("❌ StableDiffusionService - GachaSplash4.safetensors not found in bundle")
            throw StableDiffusionError.modelFilesNotFound
        }
        
        print("📱 StableDiffusionService - Found LoRA weights at: \(loraURL.path)")
        return loraURL
    }
    
    /// Loads the StableDiffusion pipeline
    private func loadPipeline() async throws {
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            throw StableDiffusionError.deviceNotSupported
        }
        
        let modelURL = try getModelURL()
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuAndGPU
        
        pipeline = try StableDiffusionPipeline(
            resourcesAt: modelURL,
            controlNet: [],  // Empty array since we're not using ControlNet
            configuration: configuration,
            disableSafety: false,
            reduceMemory: true
        )
        
        try pipeline?.loadResources()
        isModelLoaded = true
        
        // Start unload timer
        resetUnloadTimer()
    }
    
    /// Resets the timer for unloading models
    private func resetUnloadTimer() {
        unloadTimer?.invalidate()
        unloadTimer = Timer.scheduledTimer(
            withTimeInterval: unloadInterval,
            repeats: false
        ) { [weak self] _ in
            self?.unloadModels()
        }
    }
    
    /// Unloads the models to free up memory
    private func unloadModels() {
        pipeline = nil
        isModelLoaded = false
        unloadTimer?.invalidate()
        unloadTimer = nil
    }
    
    // MARK: - Public Methods
    
    /// Loads the stable diffusion models
    /// - Throws: StableDiffusionError if loading fails
    func loadModels() async throws {
        // Return if models are already loaded
        guard !isModelLoaded else { return }
        
        // Return if load is in progress
        guard !isLoadingModel else {
            // Wait for current load to complete
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                processingQueue.async { [weak self] in
                    guard let self = self else {
                        continuation.resume(throwing: StableDiffusionError.modelNotLoaded)
                        return
                    }
                    
                    if self.isModelLoaded {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: StableDiffusionError.modelNotLoaded)
                    }
                }
            }
            return
        }
        
        isLoadingModel = true
        
        print("📱 StableDiffusionService - Loading models")
        
        do {
            // Check device capabilities
            try checkDeviceSupport()
            
            // Configure pipeline
            let config = MLModelConfiguration()
            #if targetEnvironment(simulator)
            // Force CPU-only computation in simulator
            config.computeUnits = .cpuOnly
            print("📱 StableDiffusionService - Configuring for CPU-only computation in simulator")
            #else
            config.computeUnits = .cpuAndGPU
            #endif
            
            // Initialize pipeline
            pipeline = try StableDiffusionPipeline(
                resourcesAt: try getModelURL(),
                controlNet: [],  // Empty array since we're not using ControlNet
                configuration: config,
                disableSafety: false,
                reduceMemory: true
            )
            
            // TODO: Implement LoRA support when available
            // Currently, CoreML Stable Diffusion doesn't directly support LoRA weights
            // We'll need to either:
            // 1. Use a pre-merged model that includes LoRA weights
            // 2. Wait for official LoRA support in the framework
            // 3. Implement custom weight merging
            
            try optimizeForDevice()
            isModelLoaded = true
            isLoadingModel = false
            
            // Reset unload timer
            resetUnloadTimer()
            
            // Process any pending requests
            processPendingRequests()
            
            print("📱 StableDiffusionService - Models loaded successfully")
            
        } catch {
            isLoadingModel = false
            print("❌ StableDiffusionService - Error loading models: \(error)")
            throw StableDiffusionError.pipelineError(error.localizedDescription)
        }
    }
    
    /// Generates an image using stable diffusion
    /// - Parameters:
    ///   - positivePrompt: What to include in the image
    ///   - negativePrompt: What to exclude from the image
    /// - Returns: The generated image
    /// - Throws: StableDiffusionError if generation fails
    func generateImage(positivePrompt: String, negativePrompt: String) async throws -> UIImage {
        print("📱 StableDiffusionService - Generating image")
        print("📱 Positive prompt: \(positivePrompt)")
        print("📱 Negative prompt: \(negativePrompt)")
        
        // Reset unload timer since we're using the models
        resetUnloadTimer()
        
        return try await withCheckedThrowingContinuation { continuation in
            // Add request to queue
            pendingRequests.append((positivePrompt, negativePrompt, continuation))
            
            // Try to process requests
            processPendingRequests()
        }
    }
    
    // MARK: - Image Storage
    
    /// Gets the URL for the local image storage directory
    private func getImageStorageURL() throws -> URL {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw StableDiffusionError.modelDirectoryCreationFailed
        }
        
        let imageDirectory = documentsDirectory.appendingPathComponent("GeneratedImages", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: imageDirectory.path) {
            try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        }
        
        return imageDirectory
    }
    
    /// Saves an image to local storage
    /// - Parameters:
    ///   - image: The image to save
    ///   - messageId: The ID of the associated message
    /// - Returns: The local URL where the image is stored
    func saveImageLocally(_ image: UIImage, messageId: String) throws -> URL {
        let imageDirectory = try getImageStorageURL()
        let imageURL = imageDirectory.appendingPathComponent("\(messageId).jpg")
        
        // Convert image to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw StableDiffusionError.pipelineError("Failed to convert image to JPEG")
        }
        
        // Save to disk
        try imageData.write(to: imageURL)
        print("📱 StableDiffusionService - Saved image to: \(imageURL.path)")
        
        return imageURL
    }
    
    /// Loads an image from local storage
    /// - Parameter messageId: The ID of the message associated with the image
    /// - Returns: The loaded image, if it exists
    func loadImageFromStorage(messageId: String) throws -> UIImage? {
        let imageDirectory = try getImageStorageURL()
        let imageURL = imageDirectory.appendingPathComponent("\(messageId).jpg")
        
        guard FileManager.default.fileExists(atPath: imageURL.path),
              let imageData = try? Data(contentsOf: imageURL),
              let image = UIImage(data: imageData) else {
            return nil
        }
        
        return image
    }
    
    // MARK: - Private Methods
    
    /// Processes any pending image generation requests
    private func processPendingRequests() {
        guard !pendingRequests.isEmpty else { return }
        
        // Ensure models are loaded
        guard isModelLoaded else {
            Task {
                do {
                    try await loadModels()
                    processPendingRequests()
                } catch {
                    // Fail all pending requests
                    for (_, _, continuation) in pendingRequests {
                        continuation.resume(throwing: error)
                    }
                    pendingRequests.removeAll()
                }
            }
            return
        }
        
        // Get next request
        let (positivePrompt, negativePrompt, continuation) = pendingRequests.removeFirst()
        
        // Create operation for image generation
        let operation = BlockOperation { [weak self] in
            guard let self = self,
                  let pipeline = self.pipeline else {
                continuation.resume(throwing: StableDiffusionError.modelNotLoaded)
                return
            }
            
            do {
                // Configure generation parameters
                var parameters = StableDiffusionPipeline.Configuration(prompt: positivePrompt)
                parameters.negativePrompt = negativePrompt
                parameters.stepCount = 20
                parameters.seed = UInt32.random(in: 0...UInt32.max)
                parameters.guidanceScale = 7.5
                parameters.disableSafety = false
                
                // Generate image using the documented method
                let images = try pipeline.generateImages(configuration: parameters)
                
                guard let cgImage = images.first else {
                    throw StableDiffusionError.pipelineError("Failed to generate image")
                }
                
                let image = UIImage(cgImage: cgImage!)
                print("📱 StableDiffusionService - Image generated successfully")
                continuation.resume(returning: image)
                
            } catch {
                print("❌ StableDiffusionService - Error generating image: \(error)")
                continuation.resume(throwing: StableDiffusionError.pipelineError(error.localizedDescription))
            }
        }
        
        // Add operation to queue
        operationQueue.addOperation(operation)
    }
    
    /// Checks if the device supports required GPU features
    private func checkDeviceSupport() throws {
        let device = MTLCreateSystemDefaultDevice()
        
        #if targetEnvironment(simulator)
        // In simulator, we'll allow the code to proceed but with CPU-only computation
        // This ensures development can continue in simulator while maintaining safety checks for real devices
        print("📱 StableDiffusionService - Running in simulator mode with CPU-only computation")
        return
        #else
        // On physical devices, we maintain our GPU family requirement
        guard device?.supportsFamily(.apple7) == true else {
            throw StableDiffusionError.deviceNotSupported
        }
        #endif
    }
    
    /// Optimizes the pipeline for the current device
    private func optimizeForDevice() throws {
        guard let pipeline = pipeline else {
            throw StableDiffusionError.modelNotLoaded
        }
        
        // Get available memory
        let memoryInfo = ProcessInfo.processInfo.physicalMemory
        let availableMemoryGB = Double(memoryInfo) / 1_000_000_000.0
        
        // Adjust parameters based on available memory
        if availableMemoryGB < 4 {
            throw StableDiffusionError.resourceConstraint("Insufficient memory")
        }
    }
} 