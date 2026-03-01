@preconcurrency import AVFoundation
import CoreGraphics
import CoreImage
import CoreVideo
import Foundation
import Metal
import VideoToolbox

// MARK: - Errors

public enum VideoRendererError: Error {
    case failedToCreateAssetWriter(URL)
    case failedToConfigureAssetWriter
    case assetWriterNotReady
    case failedToCreatePixelBufferPool
    case failedToCreatePixelBuffer
    case failedToAppendFrame(frameNumber: Int)
    case backgroundVideoNotFound(URL)
    case failedToReadBackgroundVideo
}

// MARK: - VideoRenderer

public final class VideoRenderer: @unchecked Sendable {

    // MARK: Properties

    private let configuration: ExportConfiguration

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var backgroundReader: AVAssetReader?
    private var backgroundReaderOutput: AVAssetReaderTrackOutput?

    private var currentFrameNumber: Int = 0
    private let startTime: CMTime = .zero

    private let metalDevice: MTLDevice
    private let metalCommandQueue: MTLCommandQueue
    private var metalTextureCache: CVMetalTextureCache?
    private let metalCIContext: CIContext

    // MARK: Init

    public init(configuration: ExportConfiguration) {
        self.configuration = configuration
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            fatalError("Metal is required but no compatible device was found.")
        }
        self.metalDevice = device
        self.metalCommandQueue = queue
        self.metalCIContext = CIContext(mtlDevice: device)
    }

    // MARK: Setup

    public func prepare() throws {
        if FileManager.default.fileExists(atPath: configuration.outputURL.path) {
            try? FileManager.default.removeItem(at: configuration.outputURL)
        }

        guard
            let writer = try? AVAssetWriter(
                outputURL: configuration.outputURL,
                fileType: .mp4
            )
        else {
            throw VideoRendererError.failedToCreateAssetWriter(configuration.outputURL)
        }

        assetWriter = writer

        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: configuration.videoSettings
        )
        input.expectsMediaDataInRealTime = false

        guard writer.canAdd(input) else {
            throw VideoRendererError.failedToConfigureAssetWriter
        }

        writer.add(input)
        videoInput = input

        let size = configuration.effectiveDimensions
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String:
                Int(kCVPixelFormatType_32BGRA),  // ✅ FIXED
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ]

        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: attributes
        )

        CVMetalTextureCacheCreate(nil, nil, metalDevice, nil, &metalTextureCache)

        if let bgURL = configuration.backgroundVideoURL {
            try setupBackgroundVideo(url: bgURL)
        }

        guard writer.startWriting() else {
            throw VideoRendererError.assetWriterNotReady
        }

        writer.startSession(atSourceTime: startTime)
    }

    // MARK: Background Video (macOS 13 safe)

    private func setupBackgroundVideo(url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw VideoRendererError.backgroundVideoNotFound(url)
        }

        let asset = AVURLAsset(url: url)

        let semaphore = DispatchSemaphore(value: 0)
        var videoTrack: AVAssetTrack?
        var loadError: Error?

        asset.loadTracks(withMediaType: .video) { tracks, error in
            videoTrack = tracks?.first
            loadError = error
            semaphore.signal()
        }

        semaphore.wait()

        if let error = loadError {
            throw error
        }

        guard let track = videoTrack else {
            throw VideoRendererError.failedToReadBackgroundVideo
        }

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String:
                    Int(kCVPixelFormatType_32BGRA)  // ✅ FIXED
            ]
        )

        reader.add(output)
        reader.startReading()

        backgroundReader = reader
        backgroundReaderOutput = output
    }

    // MARK: Frame Rendering

    public func renderFrame(
        at presentationTime: CMTime,
        renderOverlay: (MetalRenderContext) -> Void
    ) throws {

        guard let adaptor = pixelBufferAdaptor,
            let input = videoInput
        else {
            throw VideoRendererError.assetWriterNotReady
        }

        while !input.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.005)
        }

        guard let pixelBuffer = try createPixelBuffer() else {
            throw VideoRendererError.failedToCreatePixelBuffer
        }

        let size = configuration.effectiveDimensions
        guard let commandBuffer = metalCommandQueue.makeCommandBuffer() else {
            throw VideoRendererError.failedToCreatePixelBuffer
        }

        guard let targetTexture = makeMetalTexture(from: pixelBuffer, width: size.width, height: size.height) else {
            throw VideoRendererError.failedToCreatePixelBuffer
        }

        var didRenderBackground = false
        if let bgBuffer = readBackgroundFrame() {
            let ciImage = CIImage(cvPixelBuffer: bgBuffer)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            metalCIContext.render(
                ciImage,
                to: targetTexture,
                commandBuffer: commandBuffer,
                bounds: CGRect(origin: .zero, size: CGSize(width: size.width, height: size.height)),
                colorSpace: colorSpace
            )
            didRenderBackground = true
        }

        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture = targetTexture
        passDescriptor.colorAttachments[0].storeAction = .store
        passDescriptor.colorAttachments[0].loadAction = didRenderBackground ? .load : .clear
        passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
            throw VideoRendererError.failedToCreatePixelBuffer
        }

        let renderContext = MetalRenderContext(
            bounds: CGRect(origin: .zero, size: CGSize(width: size.width, height: size.height)),
            viewportSize: CGSize(width: size.width, height: size.height),
            scale: 1.0,
            currentTime: Date(),
            isPreview: false,
            frameRate: Double(configuration.frameRate.rawValue),
            frameNumber: currentFrameNumber,
            safeAreaInsets: .zero,
            device: metalDevice,
            commandBuffer: commandBuffer,
            renderEncoder: encoder
        )

        renderOverlay(renderContext)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if !adaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
            throw VideoRendererError.failedToAppendFrame(frameNumber: currentFrameNumber)
        }

        currentFrameNumber += 1
    }

    // MARK: Pixel Buffers

    private func createPixelBuffer() throws -> CVPixelBuffer? {
        guard let pool = pixelBufferAdaptor?.pixelBufferPool else {
            throw VideoRendererError.failedToCreatePixelBufferPool
        }

        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        return buffer
    }

    private func makeMetalTexture(from pixelBuffer: CVPixelBuffer, width: Int, height: Int) -> MTLTexture? {
        guard let cache = metalTextureCache else { return nil }
        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            nil,
            cache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )
        guard status == kCVReturnSuccess, let texture = cvTexture else {
            return nil
        }
        return CVMetalTextureGetTexture(texture)
    }

    // MARK: Background Rendering

    private func readBackgroundFrame() -> CVPixelBuffer? {
        guard let output = backgroundReaderOutput,
            let sample = output.copyNextSampleBuffer()
        else {
            return nil
        }
        return CMSampleBufferGetImageBuffer(sample)
    }

    // MARK: Finalization

    public func finalize() async throws {
        guard let input = videoInput,
            let writer = assetWriter
        else {
            throw VideoRendererError.assetWriterNotReady
        }

        input.markAsFinished()
        await writer.finishWriting()

        if writer.status == .failed {
            if let error = writer.error {
                throw error
            }
        }

        cleanup()
    }

    public func cancel() {
        assetWriter?.cancelWriting()
        cleanup()
    }

    private func cleanup() {
        backgroundReader?.cancelReading()
        backgroundReader = nil
        backgroundReaderOutput = nil

        pixelBufferAdaptor = nil
        videoInput = nil
        assetWriter = nil

        currentFrameNumber = 0
    }

    // MARK: Timing Utilities

    public func presentationTime(forFrame frameNumber: Int) -> CMTime {
        let fps = configuration.frameRate.rawValue
        let duration = CMTime(value: 1, timescale: CMTimeScale(fps))
        return CMTimeMultiply(duration, multiplier: Int32(frameNumber))
    }

    public func totalFrames(forDuration duration: TimeInterval) -> Int {
        let fps = configuration.frameRate.rawValue
        return Int(duration * Double(fps))
    }
}
