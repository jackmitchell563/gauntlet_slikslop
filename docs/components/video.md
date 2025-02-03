# Video Service

## Overview

The `VideoService.swift` file handles all video-related operations including upload, processing (using AVFoundation), and AI-driven video generation. It manages both user-uploaded content and AI-generated nature videos.

## Core Functions

### uploadVideo(url:metadata:)
- **Purpose**: Uploads video to Firebase Cloud Storage
- **Usage**: Called for both user uploads and AI-generated content
- **Parameters**:
  - url: Local video file URL
  - metadata: Video information and tags
- **Returns**: Storage download URL
- **Example**:
```swift
class VideoService {
    static let shared = VideoService()
    private let storage = FirebaseConfig.getStorageInstance()
    private let dbService = DatabaseService.shared
    
    func uploadVideo(url: URL, metadata: VideoMetadata) async throws -> String {
        // Compress video before upload
        let compressedURL = try await compressVideo(url)
        
        // Generate unique path
        let videoPath = "videos/\(UUID().uuidString).mp4"
        let storageRef = storage.reference().child(videoPath)
        
        // Upload with metadata
        let storageMetadata = StorageMetadata()
        storageMetadata.contentType = "video/mp4"
        storageMetadata.customMetadata = [
            "creatorId": metadata.creatorId,
            "title": metadata.title
        ]
        
        _ = try await storageRef.putFileAsync(from: compressedURL, metadata: storageMetadata)
        return try await storageRef.downloadURL().absoluteString
    }
    
    private func compressVideo(_ url: URL) async throws -> URL {
        let asset = AVAsset(url: url)
        let preset = AVAssetExportPreset1280x720
        
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw VideoError.compressionFailed
        }
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        
        await session.export()
        guard session.status == .completed else {
            throw VideoError.compressionFailed
        }
        
        return outputURL
    }
}
```

### processVideo(url:effects:)
- **Purpose**: Processes video using AVFoundation
- **Usage**: Called after upload for enhancements
- **Parameters**:
  - url: Video URL
  - effects: Processing instructions
- **Returns**: Processed video URL
- **Example**:
```swift
extension VideoService {
    func processVideo(url: URL, effects: VideoEffects) async throws -> URL {
        let asset = AVAsset(url: url)
        let composition = AVMutableComposition()
        let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        
        // Apply video effects
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(
            assetTrack: videoTrack!
        )
        
        // Apply effects based on parameters
        if effects.shouldEnhanceNature {
            layerInstruction.setColorParameters(
                brightness: 0.1,
                contrast: 1.1,
                saturation: 1.2
            )
        }
        
        // Export processed video
        let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        )
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        exportSession?.outputURL = outputURL
        exportSession?.outputFileType = .mp4
        await exportSession?.export()
        
        return outputURL
    }
}

struct VideoEffects: Codable {
    let shouldEnhanceNature: Bool
    let transitions: [TransitionType]
    let filters: [FilterType]
}

enum TransitionType: String, Codable {
    case fade
    case crossDissolve
    case pushLeft
}

enum FilterType: String, Codable {
    case nature
    case wildlife
    case enhance
}
```

### generateAIVideo(profile:)
- **Purpose**: Creates AI-generated nature content
- **Usage**: Called for AI user accounts
- **Parameters**:
  - profile: AI profile preferences
- **Returns**: Generated video metadata
- **Example**:
```swift
extension VideoService {
    func generateAIVideo(profile: AIProfile) async throws -> VideoMetadata {
        let functions = FirebaseConfig.getFunctionsInstance()
        
        // Call Cloud Function for video generation
        let data: [String: Any] = [
            "profile": try profile.asDictionary(),
            "model": "gpt-4o-mini",
            "maxDuration": 60
        ]
        
        let result = try await functions
            .httpsCallable("generateAIVideo")
            .call(data)
        
        // Download generated video
        guard let videoData = result.data as? [String: Any],
              let videoUrl = videoData["url"] as? String else {
            throw VideoError.generationFailed
        }
        
        // Process and upload the video
        let downloadedUrl = try await downloadAndProcessVideo(videoUrl)
        let metadata = VideoMetadata(
            id: UUID().uuidString,
            creatorId: profile.id,
            url: downloadedUrl,
            thumbnail: try await generateThumbnail(from: downloadedUrl),
            title: videoData["title"] as? String ?? "",
            description: videoData["description"] as? String ?? "",
            tags: videoData["tags"] as? [String] ?? [],
            likes: 0,
            views: 0,
            createdAt: Timestamp(date: Date())
        )
        
        return metadata
    }
    
    private func generateThumbnail(from url: String) async throws -> String {
        let asset = AVAsset(url: URL(string: url)!)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 0, preferredTimescale: 1)
        let cgImage = try await generator.image(at: time).image
        let thumbnail = UIImage(cgImage: cgImage)
        
        // Upload thumbnail to storage
        let thumbnailData = thumbnail.jpegData(compressionQuality: 0.8)!
        let thumbnailPath = "thumbnails/\(UUID().uuidString).jpg"
        let thumbnailRef = storage.reference().child(thumbnailPath)
        
        _ = try await thumbnailRef.putDataAsync(thumbnailData)
        return try await thumbnailRef.downloadURL().absoluteString
    }
}

struct AIProfile: Codable {
    let id: String
    let type: String
    let focusArea: String
    let preferences: [String: Any]
    
    func asDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }
}

enum VideoError: Error {
    case compressionFailed
    case processingFailed
    case generationFailed
    case thumbnailGenerationFailed
}

## Best Practices

1. **Memory Management**
   - Use proper resource cleanup
   - Implement proper cache management
   - Handle large video files efficiently
   - Monitor memory usage

2. **Performance**
   - Process videos in background
   - Use appropriate compression
   - Implement proper progress tracking
   - Cache processed results

3. **Error Handling**
   - Handle device storage limits
   - Manage network interruptions
   - Provide progress updates
   - Implement retry logic

4. **Video Quality**
   - Balance size and quality
   - Use appropriate codecs
   - Optimize for mobile playback
   - Validate output quality

## Integration Example

```swift
class VideoViewController: UIViewController {
    private let videoService = VideoService.shared
    
    func handleVideoUpload(_ videoURL: URL) {
        Task {
            do {
                let metadata = VideoMetadata(
                    id: UUID().uuidString,
                    creatorId: currentUserId,
                    url: "",
                    thumbnail: "",
                    title: "Nature Video",
                    description: "Beautiful nature scene",
                    tags: ["nature", "wildlife"],
                    likes: 0,
                    views: 0,
                    createdAt: Timestamp(date: Date())
                )
                
                // Upload video
                let url = try await videoService.uploadVideo(url: videoURL, metadata: metadata)
                
                // Process with effects
                let effects = VideoEffects(
                    shouldEnhanceNature: true,
                    transitions: [.fade],
                    filters: [.nature, .enhance]
                )
                
                let processedUrl = try await videoService.processVideo(
                    url: URL(string: url)!,
                    effects: effects
                )
                
                // Update metadata with processed URL
                var updatedMetadata = metadata
                updatedMetadata.url = processedUrl.absoluteString
                
                // Save to database
                _ = try await DatabaseService.shared.createDocument(
                    collection: "videos",
                    data: updatedMetadata.asDictionary()
                )
            } catch {
                handleError(error)
            }
        }
    }
}
```

## Common Issues and Solutions

1. **Memory Management**
   - Problem: High memory usage during processing
   - Solution: Implement proper resource cleanup and streaming

2. **Processing Performance**
   - Problem: Slow video processing
   - Solution: Use appropriate quality settings and background processing

3. **Upload Reliability**
   - Problem: Failed uploads for large videos
   - Solution: Implement chunked upload with resume capability

4. **Quality Control**
   - Problem: Inconsistent video quality
   - Solution: Implement quality validation and adjustment 