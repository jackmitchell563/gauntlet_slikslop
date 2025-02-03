# AI Engine

## Overview

The `AIEngine.swift` file centralizes AI-driven functionalities for the SlikSlop platform, handling personalized feed generation, content analysis, and video generation. It integrates with OpenAI's GPT-4 for intelligent content processing and user behavior analysis, specifically tailored for nature and animal content.

## Core Functions

### AIEngine

### analyzeUserBehavior(userId:)
- **Purpose**: Analyzes user interaction patterns
- **Usage**: Called to generate personalized recommendations
- **Parameters**:
  - userId: User identifier
- **Returns**: UserBehaviorAnalysis object
- **Example**:
```swift
class AIEngine {
    static let shared = AIEngine()
    private let openAI = OpenAIService.shared
    private let dbService = DatabaseService.shared
    
    func analyzeUserBehavior(userId: String) async throws -> UserBehaviorAnalysis {
        let interactions = try await dbService.queryCollection(collection: "interactions") { query in
            query
                .whereField("userId", isEqualTo: userId)
                .order(by: "timestamp", descending: true)
                .limit(to: 100)
        }
        
        let prompt = createAnalysisPrompt(from: interactions)
        let analysis = try await openAI.complete(
            model: "gpt-4o-mini",
            prompt: prompt,
            maxTokens: 500
        )
        
        return try JSONDecoder().decode(UserBehaviorAnalysis.self, from: analysis.data)
    }
    
    private func createAnalysisPrompt(from interactions: [Interaction]) -> String {
        // Format user interactions into a structured prompt
        return """
        Analyze the following user interactions with nature and animal content:
        \(interactions.map { "- \($0.type) on \($0.contentType): \($0.duration)s" }.joined(separator: "\n"))
        Identify patterns in:
        1. Preferred animal types
        2. Content duration preferences
        3. Interaction patterns
        4. Time-of-day patterns
        """
    }
}
```

### generatePersonalizedFeed(from:)
- **Purpose**: Creates personalized video recommendations
- **Usage**: Called when generating FYP content
- **Parameters**:
  - behavior: UserBehaviorAnalysis object
- **Returns**: Array of VideoMetadata
- **Example**:
```swift
extension AIEngine {
    func generatePersonalizedFeed(from behavior: UserBehaviorAnalysis) async throws -> [VideoMetadata] {
        let prompt = createRecommendationPrompt(from: behavior)
        let recommendations = try await openAI.complete(
            model: "gpt-4o-mini",
            prompt: prompt,
            maxTokens: 1000
        )
        
        let recommendedTags = try JSONDecoder().decode([String].self, from: recommendations.data)
        return try await fetchVideosMatchingTags(recommendedTags)
    }
    
    private func fetchVideosMatchingTags(_ tags: [String]) async throws -> [VideoMetadata] {
        return try await dbService.queryCollection(collection: "videos") { query in
            query
                .whereField("tags", arrayContainsAny: tags)
                .order(by: "engagement", descending: true)
                .limit(to: 20)
        }
    }
}
```

### suggestAIVideoEffects(videoMetadata:)
- **Purpose**: Suggests video processing effects
- **Usage**: Called during video upload/processing
- **Parameters**:
  - videoMetadata: Video information and analysis
- **Returns**: Array of VideoEffect
- **Example**:
```swift
extension AIEngine {
    func suggestAIVideoEffects(videoMetadata: VideoMetadata) async throws -> [VideoEffect] {
        let prompt = createEffectsPrompt(from: videoMetadata)
        let suggestions = try await openAI.complete(
            model: "gpt-4o-mini",
            prompt: prompt,
            maxTokens: 300
        )
        
        return try JSONDecoder().decode([VideoEffect].self, from: suggestions.data)
    }
    
    private func createEffectsPrompt(from metadata: VideoMetadata) -> String {
        return """
        Suggest video effects for nature content with:
        - Subject: \(metadata.subject)
        - Duration: \(metadata.duration)
        - Environment: \(metadata.environment)
        - Lighting: \(metadata.lighting)
        Focus on enhancing natural beauty while maintaining authenticity.
        """
    }
}
```

### evaluateTrendingPatterns()
- **Purpose**: Analyzes global engagement patterns
- **Usage**: Called periodically to update trending content
- **Returns**: TrendingAnalysis object
- **Example**:
```swift
extension AIEngine {
    func evaluateTrendingPatterns() async throws -> TrendingAnalysis {
        let recentVideos = try await dbService.queryCollection(collection: "videos") { query in
            query
                .whereField("createdAt", isGreaterThan: Date().addingTimeInterval(-24*60*60))
                .order(by: "engagement", descending: true)
        }
        
        let prompt = createTrendingAnalysisPrompt(from: recentVideos)
        let analysis = try await openAI.complete(
            model: "gpt-4o-mini",
            prompt: prompt,
            maxTokens: 800
        )
        
        return try JSONDecoder().decode(TrendingAnalysis.self, from: analysis.data)
    }
}
```

## AI Components

### 1. Content Analysis
- Video subject detection
- Scene classification
- Quality assessment
- Content moderation

### 2. User Behavior Analysis
- Viewing patterns
- Interaction preferences
- Time-based patterns
- Content affinity

### 3. Content Generation
- Video effect suggestions
- Caption generation
- Hashtag recommendations
- Thumbnail optimization

### 4. Feed Personalization
- Content scoring
- User interest mapping
- Engagement prediction
- Diversity management

## Best Practices

1. **Model Usage**
   - Cache model responses
   - Batch similar requests
   - Implement retry logic
   - Monitor token usage

2. **Content Quality**
   - Validate AI suggestions
   - Maintain content diversity
   - Respect user preferences
   - Ensure ethical content

3. **Performance**
   - Optimize prompt length
   - Cache frequent analyses
   - Use appropriate models
   - Implement timeouts

4. **User Experience**
   - Provide loading states
   - Handle AI failures gracefully
   - Maintain response times
   - Allow user feedback

## Integration Example

```swift
// AI-driven video processing example
class VideoProcessor {
    private let aiEngine = AIEngine.shared
    private let videoService = VideoService.shared
    
    func processUploadedVideo(url: URL, metadata: VideoMetadata) async throws -> ProcessedVideo {
        async let effects = aiEngine.suggestAIVideoEffects(videoMetadata: metadata)
        async let analysis = aiEngine.analyzeContent(url: url)
        
        let (suggestedEffects, contentAnalysis) = try await (effects, analysis)
        
        // Apply AI-suggested effects
        let processedURL = try await videoService.applyEffects(
            to: url,
            effects: suggestedEffects,
            quality: contentAnalysis.recommendedQuality
        )
        
        // Generate AI-enhanced metadata
        let enhancedMetadata = try await generateEnhancedMetadata(
            original: metadata,
            analysis: contentAnalysis
        )
        
        return ProcessedVideo(url: processedURL, metadata: enhancedMetadata)
    }
    
    private func generateEnhancedMetadata(
        original: VideoMetadata,
        analysis: ContentAnalysis
    ) async throws -> VideoMetadata {
        let prompt = """
        Enhance video metadata for:
        Original Title: \(original.title)
        Subject: \(analysis.subject)
        Scene: \(analysis.scene)
        Key Moments: \(analysis.keyMoments.joined(separator: ", "))
        """
        
        let enhancement = try await aiEngine.complete(
            model: "gpt-4o-mini",
            prompt: prompt,
            maxTokens: 200
        )
        
        return try JSONDecoder().decode(VideoMetadata.self, from: enhancement.data)
    }
}
```

## Common Issues and Solutions

1. **Model Performance**
   - Problem: Slow response times
   - Solution: Implement caching and batch processing

2. **Content Quality**
   - Problem: Inconsistent AI suggestions
   - Solution: Implement validation and fallback options

3. **Resource Usage**
   - Problem: High API costs
   - Solution: Optimize prompts and cache responses

4. **Error Handling**
   - Problem: AI service failures
   - Solution: Implement robust retry and fallback logic

## Model Configuration

### OpenAI Settings
```swift
struct OpenAIConfig {
    static let defaultSettings = OpenAIConfig(
        model: "gpt-4o-mini",
        temperature: 0.7,
        maxTokens: 500,
        topP: 0.9,
        frequencyPenalty: 0.0,
        presencePenalty: 0.0
    )
    
    let model: String
    let temperature: Float
    let maxTokens: Int
    let topP: Float
    let frequencyPenalty: Float
    let presencePenalty: Float
}
```

### Performance Settings
```swift
struct AIPerformanceConfig {
    static let defaultSettings = AIPerformanceConfig(
        cacheTimeout: 3600,  // 1 hour
        maxRetries: 3,
        requestTimeout: 30.0,
        batchSize: 10
    )
    
    let cacheTimeout: TimeInterval
    let maxRetries: Int
    let requestTimeout: TimeInterval
    let batchSize: Int
}
```

### Monitoring Metrics
```swift
struct AIMetrics {
    var tokenUsage: Int
    var responseTime: TimeInterval
    var errorRate: Float
    var cacheHitRate: Float
    var costPerRequest: Float
    
    static func track(
        operation: String,
        duration: TimeInterval,
        tokens: Int
    ) {
        // Log metrics to monitoring service
    }
}
``` 