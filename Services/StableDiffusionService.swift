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
        setupModelDirectory()
    }
    
    // MARK: - Setup
    
    /// Sets up the directory for storing model files
    private func setupModelDirectory() {
        do {
            try FileManager.default.createDirectory(
                at: getModelDirectoryURL(),
                withIntermediateDirectories: true
            )
        } catch {
            print("❌ StableDiffusionService - Error creating model directory: \(error)")
        }
    }
    
    // MARK: - Model Management
    
    /// Gets the URL for the model directory
    private func getModelDirectoryURL() -> URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return applicationSupport.appendingPathComponent("StableDiffusion", isDirectory: true)
    }
    
    /// Gets the URL for the CoreML model
    private func getModelURL() throws -> URL {
        let modelDir = getModelDirectoryURL()
        let modelURL = modelDir.appendingPathComponent("CoreMLModel", isDirectory: true)
        
        // Check if model exists
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: modelURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw StableDiffusionError.modelFilesNotFound
        }
        
        return modelURL
    }
    
    /// Gets the URL for the LoRA weights
    private func getLoRAURL() throws -> URL {
        let modelDir = getModelDirectoryURL()
        let loraURL = modelDir.appendingPathComponent("lora.safetensors")
        
        // Check if LoRA file exists
        guard FileManager.default.fileExists(atPath: loraURL.path) else {
            throw StableDiffusionError.modelFilesNotFound
        }
        
        return loraURL
    }
    
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
        
        // Create model directory if needed
        let modelDir = getModelDirectoryURL()
        try FileManager.default.createDirectory(
            at: modelDir,
            withIntermediateDirectories: true
        )
        
        // Get bundle URL for CoreML model
        guard let bundleModelURL = Bundle.main.url(
            forResource: "CoreMLModel",
            withExtension: nil,
            subdirectory: "Resources"
        ) else {
            throw StableDiffusionError.modelFilesNotFound
        }
        
        // Copy CoreML model from bundle
        let modelURL = modelDir.appendingPathComponent("CoreMLModel", isDirectory: true)
        try FileManager.default.copyItem(at: bundleModelURL, to: modelURL)
        progress?(0.8) // CoreML model is 80% of total progress
        
        // For now, we're not using LoRA weights
        progress?(1.0)
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
            config.computeUnits = .cpuAndGPU
            
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
        guard device?.supportsFamily(.apple7) == true else {
            throw StableDiffusionError.deviceNotSupported
        }
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