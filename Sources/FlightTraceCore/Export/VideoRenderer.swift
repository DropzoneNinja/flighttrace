import Foundation
import AVFoundation
import CoreGraphics
import CoreVideo
import CoreImage
import VideoToolbox

/// Handles low-level video rendering using AVFoundation
///
/// VideoRenderer manages the AVAssetWriter and provides methods for:
/// - Creating pixel buffers
/// - Rendering overlays into pixel buffers
/// - Appending frames to the video file
/// - Managing background video composition
public final class VideoRenderer: @unchecked Sendable {

    // MARK: - Error Types

    public enum VideoRendererError: Error, CustomStringConvertible {
        case failedToCreateAssetWriter(URL)
        case failedToConfigureAssetWriter
        case assetWriterNotReady
        case failedToCreatePixelBufferPool
        case failedToCreatePixelBuffer
        case failedToAppendFrame(frameNumber: Int)
        case backgroundVideoNotFound(URL)
        case failedToReadBackgroundVideo

        public var description: String {
            switch self {
            case .failedToCreateAssetWriter(let url):
                return "Failed to create asset writer for URL: \(url.path)"
            case .failedToConfigureAssetWriter:
                return "Failed to configure asset writer input"
            case .assetWriterNotReady:
                return "Asset writer is not in ready state"
            case .failedToCreatePixelBufferPool:
                return "Failed to create pixel buffer pool"
            case .failedToCreatePixelBuffer:
                return "Failed to create pixel buffer from pool"
            case .failedToAppendFrame(let frameNumber):
                return "Failed to append frame \(frameNumber)"
            case .backgroundVideoNotFound(let url):
                return "Background video not found at: \(url.path)"
            case .failedToReadBackgroundVideo:
                return "Failed to read frames from background video"
            }
        }
    }

    // MARK: - Properties

    private let configuration: ExportConfiguration
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    // Background video support
    private var backgroundAsset: AVAsset?
    private var backgroundVideoTrack: AVAssetTrack?
    private var backgroundReader: AVAssetReader?
    private var backgroundReaderOutput: AVAssetReaderTrackOutput?

    // Frame tracking
    private var currentFrameNumber: Int = 0
    private let startTime: CMTime = .zero

    // MARK: - Initialization

    public init(configuration: ExportConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Setup

    /// Prepare the video renderer for export
    ///
    /// This creates the AVAssetWriter and configures all necessary inputs
    public func prepare() throws {
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: configuration.outputURL.path) {
            try? FileManager.default.removeItem(at: configuration.outputURL)
        }

        // Create asset writer
        guard let writer = try? AVAssetWriter(outputURL: configuration.outputURL, fileType: .mp4) else {
            throw VideoRendererError.failedToCreateAssetWriter(configuration.outputURL)
        }
        self.assetWriter = writer

        // Configure video input
        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: configuration.videoSettings
        )
        videoInput.expectsMediaDataInRealTime = false

        guard writer.canAdd(videoInput) else {
            throw VideoRendererError.failedToConfigureAssetWriter
        }

        writer.add(videoInput)
        self.videoInput = videoInput

        // Configure pixel buffer adaptor
        let dimensions = configuration.effectiveDimensions
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: dimensions.width,
            kCVPixelBufferHeightKey as String: dimensions.height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )
        self.pixelBufferAdaptor = adaptor

        // Setup background video if specified
        if let backgroundURL = configuration.backgroundVideoURL {
            try setupBackgroundVideo(url: backgroundURL)
        }

        // Start writing session
        guard writer.startWriting() else {
            throw VideoRendererError.assetWriterNotReady
        }
        writer.startSession(atSourceTime: startTime)
    }

    /// Setup background video reader
    private func setupBackgroundVideo(url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw VideoRendererError.backgroundVideoNotFound(url)
        }

        let asset = AVAsset(url: url)
        self.backgroundAsset = asset

        // Note: Using synchronous tracks for now, should be async in production
        let videoTracks = asset.tracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw VideoRendererError.failedToReadBackgroundVideo
        }
        self.backgroundVideoTrack = videoTrack

        // Create reader
        let reader = try AVAssetReader(asset: asset)
        self.backgroundReader = reader

        // Configure output
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB)
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
        reader.add(readerOutput)
        self.backgroundReaderOutput = readerOutput

        // Start reading
        reader.startReading()
    }

    // MARK: - Frame Rendering

    /// Render a single frame with overlay
    ///
    /// - Parameters:
    ///   - presentationTime: The presentation time for this frame
    ///   - renderOverlay: Closure that renders the overlay into the provided CGContext
    /// - Throws: VideoRendererError if frame cannot be rendered
    public func renderFrame(
        at presentationTime: CMTime,
        renderOverlay: (CGContext, CGSize) -> Void
    ) throws {
        guard let adaptor = pixelBufferAdaptor,
              let videoInput = videoInput else {
            throw VideoRendererError.assetWriterNotReady
        }

        // Wait for input to be ready
        while !videoInput.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.01)
        }

        // Get or create pixel buffer
        guard let pixelBuffer = try createPixelBuffer() else {
            throw VideoRendererError.failedToCreatePixelBuffer
        }

        // Lock pixel buffer for drawing
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        // Create graphics context
        let dimensions = configuration.effectiveDimensions
        let width = dimensions.width
        let height = dimensions.height

        guard let context = createGraphicsContext(for: pixelBuffer, width: width, height: height) else {
            throw VideoRendererError.failedToCreatePixelBuffer
        }

        // Render background if available
        if let backgroundBuffer = try? readBackgroundFrame() {
            renderBackground(backgroundBuffer, into: context, size: CGSize(width: width, height: height))
        } else if !configuration.transparentBackground {
            // Fill with black background if no background video and not transparent
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }

        // Render overlay
        renderOverlay(context, CGSize(width: width, height: height))

        // Append pixel buffer to video
        let success = adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
        if !success {
            throw VideoRendererError.failedToAppendFrame(frameNumber: currentFrameNumber)
        }

        currentFrameNumber += 1
    }

    /// Create a pixel buffer for rendering
    private func createPixelBuffer() throws -> CVPixelBuffer? {
        guard let pixelBufferPool = pixelBufferAdaptor?.pixelBufferPool else {
            throw VideoRendererError.failedToCreatePixelBufferPool
        }

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pixelBuffer)

        guard status == kCVReturnSuccess else {
            throw VideoRendererError.failedToCreatePixelBuffer
        }

        return pixelBuffer
    }

    /// Create a Core Graphics context for the pixel buffer
    private func createGraphicsContext(
        for pixelBuffer: CVPixelBuffer,
        width: Int,
        height: Int
    ) -> CGContext? {
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

        let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )

        // Flip coordinate system to match Core Graphics standard (origin at bottom-left)
        context?.translateBy(x: 0, y: CGFloat(height))
        context?.scaleBy(x: 1, y: -1)

        return context
    }

    /// Read the next frame from background video
    private func readBackgroundFrame() throws -> CVPixelBuffer? {
        guard let readerOutput = backgroundReaderOutput else {
            return nil
        }

        guard let sampleBuffer = readerOutput.copyNextSampleBuffer() else {
            return nil
        }

        return CMSampleBufferGetImageBuffer(sampleBuffer)
    }

    /// Render background video frame into context
    private func renderBackground(_ backgroundBuffer: CVPixelBuffer, into context: CGContext, size: CGSize) {
        // Create CIImage from pixel buffer
        let ciImage = CIImage(cvPixelBuffer: backgroundBuffer)

        // Create CIContext for rendering
        let ciContext = CIContext()

        // Render to CGContext
        ciContext.render(ciImage, to: backgroundBuffer, bounds: ciImage.extent, colorSpace: nil)

        // Note: For better performance, this should be optimized
        // For now, we'll render the background as a CGImage
        if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
            context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Finalization

    /// Complete the video export
    ///
    /// This finalizes the video file and performs cleanup
    public func finalize() async throws {
        guard let videoInput = videoInput,
              let writer = assetWriter else {
            throw VideoRendererError.assetWriterNotReady
        }

        // Mark input as finished
        videoInput.markAsFinished()

        // Finish writing
        await writer.finishWriting()

        // Check for errors
        if writer.status == .failed {
            if let error = writer.error {
                throw error
            }
        }

        // Cleanup
        cleanup()
    }

    /// Cancel the export and cleanup
    public func cancel() {
        assetWriter?.cancelWriting()
        cleanup()
    }

    /// Cleanup resources
    private func cleanup() {
        backgroundReader?.cancelReading()
        backgroundReader = nil
        backgroundReaderOutput = nil
        backgroundAsset = nil
        backgroundVideoTrack = nil

        pixelBufferAdaptor = nil
        videoInput = nil
        assetWriter = nil

        currentFrameNumber = 0
    }

    // MARK: - Utility

    /// Calculate presentation time for a given frame number
    public func presentationTime(forFrame frameNumber: Int) -> CMTime {
        let frameRate = configuration.frameRate.rawValue
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        return CMTimeMultiply(frameDuration, multiplier: Int32(frameNumber))
    }

    /// Calculate total number of frames for a given duration
    public func totalFrames(forDuration duration: TimeInterval) -> Int {
        let frameRate = configuration.frameRate.rawValue
        return Int(duration * Double(frameRate))
    }
}
