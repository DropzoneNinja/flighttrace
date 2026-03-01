import Foundation
import CoreGraphics
import AVFoundation

// Note: We can't import FlightTracePlugins here since it depends on FlightTraceCore
// Instead, we'll use protocols and pass in rendering closures

/// High-level orchestrator for video export process
///
/// The ExportEngine coordinates the entire export pipeline:
/// 1. Prepares the video renderer with configuration
/// 2. Iterates through timeline frames
/// 3. Renders overlays for each frame
/// 4. Reports progress and handles cancellation
/// 5. Finalizes the output video
///
/// ## Usage
/// ```swift
/// let config = ExportConfiguration.preset1080pH264(outputURL: outputURL)
/// let engine = ExportEngine(configuration: config, timeline: timeline)
///
/// // Setup rendering closure that knows how to render instruments
/// engine.setRenderingClosure { context, size, timestamp, frameNumber in
///     // Render all instruments at this timestamp
/// }
///
/// // Export with progress tracking
/// try await engine.export { progress in
///     print("Progress: \(progress.percentComplete)%")
/// }
/// ```
public final class ExportEngine: Sendable {

    // MARK: - Progress Tracking

    /// Progress information during export
    public struct ExportProgress: Sendable {
        /// Current frame number being rendered
        public let currentFrame: Int

        /// Total number of frames to render
        public let totalFrames: Int

        /// Elapsed time since export started
        public let elapsedTime: TimeInterval

        /// Estimated time remaining (in seconds)
        public let estimatedTimeRemaining: TimeInterval?

        public init(
            currentFrame: Int,
            totalFrames: Int,
            elapsedTime: TimeInterval,
            estimatedTimeRemaining: TimeInterval?
        ) {
            self.currentFrame = currentFrame
            self.totalFrames = totalFrames
            self.elapsedTime = elapsedTime
            self.estimatedTimeRemaining = estimatedTimeRemaining
        }

        /// Percentage complete (0-100)
        public var percentComplete: Double {
            guard totalFrames > 0 else { return 0 }
            return (Double(currentFrame) / Double(totalFrames)) * 100.0
        }

        /// Frames per second rendering speed
        public var renderingFPS: Double {
            guard elapsedTime > 0 else { return 0 }
            return Double(currentFrame) / elapsedTime
        }
    }

    // MARK: - Error Types

    public enum ExportError: Error, CustomStringConvertible {
        case noRenderingClosure
        case invalidDuration
        case exportCancelled
        case renderingFailed(frameNumber: Int, underlyingError: Error)

        public var description: String {
            switch self {
            case .noRenderingClosure:
                return "No rendering closure provided. Call setRenderingClosure() before exporting."
            case .invalidDuration:
                return "Invalid timeline duration"
            case .exportCancelled:
                return "Export was cancelled"
            case .renderingFailed(let frame, let error):
                return "Rendering failed at frame \(frame): \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Properties

    private let configuration: ExportConfiguration
    private let duration: TimeInterval
    private let startTime: Date

    // Rendering closure (provided externally since we can't depend on FlightTracePlugins here)
    private let renderingClosureBox: RenderingClosureBox

    // Cancellation support
    private let cancellationToken = CancellationToken()

    // MARK: - Initialization

    /// Create an export engine
    ///
    /// - Parameters:
    ///   - configuration: Export configuration (resolution, codec, etc.)
    ///   - duration: Total duration of the export (in seconds)
    ///   - startTime: The GPX/timeline start time (for timestamp calculation)
    public init(
        configuration: ExportConfiguration,
        duration: TimeInterval,
        startTime: Date = Date()
    ) {
        self.configuration = configuration
        self.duration = duration
        self.startTime = startTime
        self.renderingClosureBox = RenderingClosureBox()
    }

    // MARK: - Setup

    /// Set the rendering closure that will be called for each frame
    ///
    /// The closure receives:
    /// - MetalRenderContext: The Metal render context for this frame
    /// - CGSize: The canvas size
    /// - Date: The current timestamp for this frame
    /// - Int: The frame number
    ///
    /// The closure should render all active instruments for the given timestamp
    public func setRenderingClosure(
        _ closure: @escaping @Sendable (MetalRenderContext, CGSize, Date, Int) -> Void
    ) {
        renderingClosureBox.setClosure(closure)
    }

    // MARK: - Export

    /// Execute the video export
    ///
    /// - Parameter progressCallback: Optional closure called periodically with progress updates
    /// - Throws: ExportError or VideoRendererError if export fails
    public func export(
        progressCallback: (@Sendable (ExportProgress) -> Void)? = nil
    ) async throws {
        guard let renderingClosure = renderingClosureBox.getClosure() else {
            throw ExportError.noRenderingClosure
        }

        guard duration > 0 else {
            throw ExportError.invalidDuration
        }

        // Create video renderer
        let renderer = VideoRenderer(configuration: configuration)
        try renderer.prepare()

        // Calculate total frames
        let totalFrames = renderer.totalFrames(forDuration: duration)
        let frameRate = configuration.frameRate.rawValue
        let frameDuration = 1.0 / Double(frameRate)

        // Track timing for progress estimation
        let exportStartTime = Date()

        // Render each frame
        for frameNumber in 0..<totalFrames {
            // Check for cancellation
            if cancellationToken.isCancelled {
                renderer.cancel()
                throw ExportError.exportCancelled
            }

            // Calculate timestamp for this frame
            let videoTime = Double(frameNumber) * frameDuration
            let timestamp = startTime.addingTimeInterval(videoTime)

            // Calculate presentation time
            let presentationTime = renderer.presentationTime(forFrame: frameNumber)

            // Render this frame
            do {
                try renderer.renderFrame(at: presentationTime) { metalContext in
                    renderingClosure(metalContext, CGSize(width: metalContext.bounds.width, height: metalContext.bounds.height), timestamp, frameNumber)
                }
            } catch {
                throw ExportError.renderingFailed(frameNumber: frameNumber, underlyingError: error)
            }

            // Report progress periodically (every 10 frames or at completion)
            if frameNumber % 10 == 0 || frameNumber == totalFrames - 1 {
                let elapsed = Date().timeIntervalSince(exportStartTime)
                let estimatedRemaining = calculateEstimatedTimeRemaining(
                    currentFrame: frameNumber,
                    totalFrames: totalFrames,
                    elapsed: elapsed
                )

                let progress = ExportProgress(
                    currentFrame: frameNumber + 1,
                    totalFrames: totalFrames,
                    elapsedTime: elapsed,
                    estimatedTimeRemaining: estimatedRemaining
                )

                progressCallback?(progress)
            }
        }

        // Finalize video
        try await renderer.finalize()

        // Report completion
        let finalElapsed = Date().timeIntervalSince(exportStartTime)
        let finalProgress = ExportProgress(
            currentFrame: totalFrames,
            totalFrames: totalFrames,
            elapsedTime: finalElapsed,
            estimatedTimeRemaining: 0
        )
        progressCallback?(finalProgress)
    }

    /// Cancel the ongoing export
    public func cancel() {
        cancellationToken.cancel()
    }

    // MARK: - Progress Estimation

    private func calculateEstimatedTimeRemaining(
        currentFrame: Int,
        totalFrames: Int,
        elapsed: TimeInterval
    ) -> TimeInterval? {
        guard currentFrame > 0, elapsed > 0 else {
            return nil
        }

        let framesRemaining = totalFrames - currentFrame
        let timePerFrame = elapsed / Double(currentFrame)
        return timePerFrame * Double(framesRemaining)
    }
}

// MARK: - Rendering Closure Box

/// Thread-safe box for holding the rendering closure
private final class RenderingClosureBox: @unchecked Sendable {
    private var closure: (@Sendable (MetalRenderContext, CGSize, Date, Int) -> Void)?
    private let lock = NSLock()

    func setClosure(_ newClosure: @escaping @Sendable (MetalRenderContext, CGSize, Date, Int) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        closure = newClosure
    }

    func getClosure() -> (@Sendable (MetalRenderContext, CGSize, Date, Int) -> Void)? {
        lock.lock()
        defer { lock.unlock() }
        return closure
    }
}

// MARK: - Cancellation Token

/// Thread-safe cancellation token
private final class CancellationToken: @unchecked Sendable {
    private var _cancelled = false
    private let lock = NSLock()

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _cancelled
    }

    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        _cancelled = true
    }
}

// MARK: - Convenience Factory Extensions

public extension ExportEngine {
    /// Create an export engine from timeline parameters
    ///
    /// - Parameters:
    ///   - configuration: Export configuration
    ///   - startTime: The start time of the timeline/GPX track
    ///   - endTime: The end time of the timeline/GPX track
    /// - Returns: Configured export engine
    static func fromTimeline(
        configuration: ExportConfiguration,
        startTime: Date,
        endTime: Date
    ) -> ExportEngine {
        let duration = endTime.timeIntervalSince(startTime)
        return ExportEngine(
            configuration: configuration,
            duration: duration,
            startTime: startTime
        )
    }

    /// Create an export engine with a specific duration in seconds
    ///
    /// - Parameters:
    ///   - configuration: Export configuration
    ///   - durationInSeconds: Total duration of the export
    ///   - startTime: Optional start time (defaults to current time)
    /// - Returns: Configured export engine
    static func withDuration(
        configuration: ExportConfiguration,
        durationInSeconds: TimeInterval,
        startTime: Date = Date()
    ) -> ExportEngine {
        ExportEngine(
            configuration: configuration,
            duration: durationInSeconds,
            startTime: startTime
        )
    }
}
