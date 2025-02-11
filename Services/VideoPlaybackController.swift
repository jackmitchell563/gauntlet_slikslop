import UIKit
import AVFoundation

/// Manages video playback state and coordination across the feed.
/// This controller serves as the single source of truth for video playback state,
/// handling all transitions and ensuring only one video plays at a time.
final class VideoPlaybackController {
    
    // MARK: - Types
    
    /// Represents the possible states of video playback in the feed
    enum PlaybackState: Equatable {
        case idle
        case playing(VideoPlayerCell)
        case paused(VideoPlayerCell)
        case error(Error)
        
        // Custom Equatable implementation since Error doesn't conform to Equatable
        static func == (lhs: PlaybackState, rhs: PlaybackState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle):
                return true
            case let (.playing(cell1), .playing(cell2)):
                return cell1 === cell2
            case let (.paused(cell1), .paused(cell2)):
                return cell1 === cell2
            case (.error, .error):
                return true
            default:
                return false
            }
        }
    }
    
    /// Custom errors that can occur during playback
    enum PlaybackError: Error {
        case invalidStateTransition
        case cellNotVisible
        case playbackFailed
    }
    
    // MARK: - Properties
    
    /// Shared instance for singleton access
    static let shared = VideoPlaybackController()
    
    /// Current state of the playback controller
    private var currentState: PlaybackState = .idle {
        didSet {
            if oldValue != currentState {
                logStateTransition(from: oldValue, to: currentState)
            }
        }
    }
    
    /// Timestamp of last visibility check to prevent too frequent updates
    private var lastVisibilityCheck: TimeInterval = 0
    
    /// Minimum time between visibility checks to optimize performance
    private let visibilityThreshold: TimeInterval = 0.1
    
    /// Whether the feed tab is currently visible
    private var isTabVisible: Bool = true
    
    /// Tracks video progress within a sliding window
    private class VideoProgressTracker {
        private let windowSize: Int = 10  // Number of videos to track on each side
        private var progressMap: [Int: CMTime] = [:]  // Maps index to video progress
        
        /// Updates progress for a video at given index
        func updateProgress(at index: Int, time: CMTime) {
            progressMap[index] = time
        }
        
        /// Gets stored progress for video at index
        func getProgress(at index: Int) -> CMTime? {
            return progressMap[index]
        }
        
        /// Updates the window of tracked videos based on current index
        func updateWindow(currentIndex: Int) {
            let minAllowedIndex = currentIndex - windowSize
            let maxAllowedIndex = currentIndex + windowSize
            
            // Remove progress for videos outside our window
            progressMap = progressMap.filter { index, _ in
                (minAllowedIndex...maxAllowedIndex).contains(index)
            }
        }
        
        /// Checks if an index is within our tracking window
        func isInWindow(index: Int, currentIndex: Int) -> Bool {
            return abs(index - currentIndex) <= windowSize
        }
    }
    
    /// Add to existing properties
    private let progressTracker = VideoProgressTracker()
    private var currentVideoIndex: Int = 0
    
    // MARK: - Initialization
    
    private init() {
        print("📱 VideoPlaybackController - Initialized")
    }
    
    // MARK: - Public Methods
    
    /// Checks if the given cell is currently playing
    /// - Parameter cell: The cell to check
    /// - Returns: True if the cell is currently playing, false otherwise
    func isCurrentlyPlaying(_ cell: VideoPlayerCell) -> Bool {
        print("🔍 VideoPlaybackController - Checking if cell \(cell.tag) is playing")
        if case .playing(let playingCell) = currentState {
            let isPlaying = cell === playingCell
            print("🎥 VideoPlaybackController - Cell \(cell.tag) is \(isPlaying ? "playing" : "not playing")")
            return isPlaying
        }
        print("🎥 VideoPlaybackController - Cell \(cell.tag) is not playing")
        return false
    }
    
    /// Handles when a cell's video is ready for playback
    /// - Parameter cell: The cell that is ready
    func handleCellReady(_ cell: VideoPlayerCell) {
        print("🎮 VideoPlaybackController - Cell \(cell.tag) reported ready")
        
        // If this is the first cell and we're in idle state, start playing
        if cell.tag == 0, case .idle = currentState {
            print("🎮 VideoPlaybackController - First cell ready in idle state, starting playback")
            play(cell)
        }
        // If this cell should be playing according to current state, ensure it's playing
        else if case .playing(let playingCell) = currentState, cell === playingCell {
            print("🎮 VideoPlaybackController - Cell \(cell.tag) should be playing, ensuring playback")
            play(cell)
        }
    }
    
    /// Handles cell reuse events from the collection view
    func handleCellReuse(_ cell: VideoPlayerCell) {
        print("🔄 VideoPlaybackController - Handling reuse for cell \(cell.tag)")
        
        // Only cleanup if outside our window or if this cell was playing
        let isPlaying = { () -> Bool in
            if case .playing(let playingCell) = self.currentState {
                return cell === playingCell
            }
            return false
        }()
        
        if !progressTracker.isInWindow(index: cell.tag, currentIndex: currentVideoIndex) || isPlaying {
            cleanupCell(cell)
        }
    }
    
    /// Updates the playback state based on currently visible cells
    /// - Parameters:
    ///   - visibleCells: Array of currently visible video cells
    ///   - scrolling: Whether the feed is currently scrolling
    func updatePlayback(for visibleCells: [VideoPlayerCell], scrolling: Bool) {
        // Don't update playback if tab is not visible
        guard isTabVisible else {
            print("🎥 VideoPlaybackController - Skipping playback update, tab not visible")
            return
        }
        
        // Throttle visibility checks for performance
        let now = CACurrentMediaTime()
        guard now - lastVisibilityCheck >= visibilityThreshold else {
            print("🎥 VideoPlaybackController - Skipping update due to throttle")
            return
        }
        lastVisibilityCheck = now
        
        print("🎥 VideoPlaybackController - Updating playback, scrolling: \(scrolling)")
        
        // Get most visible cell efficiently
        guard let mostVisibleCell = getMostVisibleCell(from: visibleCells) else {
            print("🎥 VideoPlaybackController - No visible cell found, pausing current")
            pauseCurrentVideo()
            return
        }
        
        // Update current index and progress window
        let newIndex = mostVisibleCell.tag
        if newIndex != currentVideoIndex {
            currentVideoIndex = newIndex
            progressTracker.updateWindow(currentIndex: newIndex)
            
            // Cleanup cells outside our window
            visibleCells.forEach { cell in
                if !progressTracker.isInWindow(index: cell.tag, currentIndex: newIndex) {
                    cleanupCell(cell)
                }
            }
        }
        
        // Handle state transition
        do {
            try handleStateTransition(for: mostVisibleCell, isScrolling: scrolling)
        } catch {
            print("❌ VideoPlaybackController - Error during state transition: \(error)")
            currentState = .error(error)
        }
    }
    
    /// Sets the visibility state of the feed tab
    /// - Parameter isVisible: Whether the feed tab is visible
    func setTabVisibility(_ isVisible: Bool) {
        print("🎥 VideoPlaybackController - Tab visibility changed to: \(isVisible)")
        isTabVisible = isVisible
        if !isVisible {
            pauseAll()
        }
    }
    
    /// Pauses all currently playing videos
    func pauseAll() {
        print("🎥 VideoPlaybackController - Pausing all videos")
        guard case .playing(let cell) = currentState else { return }
        pause(cell)
    }
    
    /// Records current progress for a video
    func recordProgress(for cell: VideoPlayerCell, time: CMTime) {
        progressTracker.updateProgress(at: cell.tag, time: time)
    }
    
    /// Retrieves stored progress for a video
    func getStoredProgress(for cell: VideoPlayerCell) -> CMTime? {
        return progressTracker.getProgress(at: cell.tag)
    }
    
    /// Checks if a cell should maintain its player
    func shouldMaintainPlayer(for cell: VideoPlayerCell) -> Bool {
        return progressTracker.isInWindow(index: cell.tag, currentIndex: currentVideoIndex)
    }
    
    // MARK: - Private Methods
    
    /// Handles state transitions based on the current state and most visible cell
    private func handleStateTransition(for mostVisibleCell: VideoPlayerCell, isScrolling: Bool) throws {
        switch currentState {
        case .idle:
            print("🎥 VideoPlaybackController - Transitioning from idle to playing")
            play(mostVisibleCell)
            
        case .playing(let currentCell):
            if currentCell != mostVisibleCell {
                print("🎥 VideoPlaybackController - Transitioning to new cell")
                transition(from: currentCell, to: mostVisibleCell)
            }
            
        case .paused(let currentCell):
            if !isScrolling {
                if currentCell == mostVisibleCell {
                    // Resume playback of the same cell
                    print("🎥 VideoPlaybackController - Resuming paused cell")
                    play(mostVisibleCell)
                } else {
                    // Switch to playing a different cell
                    print("🎥 VideoPlaybackController - Switching to new cell")
                    play(mostVisibleCell)
                }
            }
            
        case .error:
            print("🎥 VideoPlaybackController - Attempting recovery from error")
            play(mostVisibleCell)
        }
    }
    
    /// Returns the most visible cell from the provided array
    private func getMostVisibleCell(from cells: [VideoPlayerCell]) -> VideoPlayerCell? {
        return cells.max { cell1, cell2 in
            cell1.visibleAreaPercentage < cell2.visibleAreaPercentage
        }
    }
    
    /// Plays the specified cell and updates state
    private func play(_ cell: VideoPlayerCell) {
        print("▶️ VideoPlaybackController - Playing cell at index: \(cell.tag)")
        cell.play()
        currentState = .playing(cell)
    }
    
    /// Pauses the specified cell and updates state
    private func pause(_ cell: VideoPlayerCell) {
        print("⏸️ VideoPlaybackController - Pausing cell at index: \(cell.tag)")
        cell.pause()
        currentState = .paused(cell)
    }
    
    /// Transitions playback from one cell to another
    private func transition(from currentCell: VideoPlayerCell, to newCell: VideoPlayerCell) {
        print("🔄 VideoPlaybackController - Transitioning from cell \(currentCell.tag) to \(newCell.tag)")
        currentCell.pause()
        newCell.play()
        currentState = .playing(newCell)
    }
    
    /// Pauses the currently playing video if any
    private func pauseCurrentVideo() {
        if case .playing(let cell) = currentState {
            pause(cell)
        }
    }
    
    /// Logs state transitions for debugging
    private func logStateTransition(from oldState: PlaybackState, to newState: PlaybackState) {
        let oldStateString = stateDescription(oldState)
        let newStateString = stateDescription(newState)
        print("🔄 VideoPlaybackController - State transition: \(oldStateString) -> \(newStateString)")
    }
    
    /// Converts a PlaybackState to a readable string for logging
    private func stateDescription(_ state: PlaybackState) -> String {
        switch state {
        case .idle:
            return "idle"
        case .playing(let cell):
            return "playing(cell: \(cell.tag))"
        case .paused(let cell):
            return "paused(cell: \(cell.tag))"
        case .error(let error):
            return "error(\(error))"
        }
    }
    
    /// Handles cleanup of a cell's resources
    private func cleanupCell(_ cell: VideoPlayerCell) {
        print("🧹 VideoPlaybackController - Cleaning up cell \(cell.tag)")
        
        // If this was the playing cell, update state to idle
        if case .playing(let playingCell) = currentState, cell === playingCell {
            currentState = .idle
        }
        
        // Store final progress before cleanup if within window
        if progressTracker.isInWindow(index: cell.tag, currentIndex: currentVideoIndex),
           case .playing(let playingCell) = currentState,
           cell === playingCell {
            if let currentTime = cell.getCurrentTime() {
                progressTracker.updateProgress(at: cell.tag, time: currentTime)
            }
        }
        
        cell.cleanup()
    }
} 