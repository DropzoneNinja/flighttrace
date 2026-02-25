import Foundation
import AVFoundation

/// Configuration settings for video export
public struct ExportConfiguration: Sendable {
    /// Video codec type
    public enum Codec: String, Sendable, CaseIterable {
        case h264 = "H.264"
        case hevc = "HEVC/H.265"

        public var avCodecKey: AVVideoCodecType {
            switch self {
            case .h264:
                return .h264
            case .hevc:
                return .hevc
            }
        }
    }

    /// Video resolution preset
    public enum ResolutionPreset: Sendable, Hashable {
        case sd480p      // 640×480
        case hd720p      // 1280×720
        case hd1080p     // 1920×1080
        case uhd4K       // 3840×2160
        case custom(width: Int, height: Int)

        /// Common preset cases (excluding custom)
        public static let presets: [ResolutionPreset] = [
            .sd480p,
            .hd720p,
            .hd1080p,
            .uhd4K
        ]

        public var dimensions: (width: Int, height: Int) {
            switch self {
            case .sd480p:
                return (640, 480)
            case .hd720p:
                return (1280, 720)
            case .hd1080p:
                return (1920, 1080)
            case .uhd4K:
                return (3840, 2160)
            case .custom(let width, let height):
                return (width, height)
            }
        }

        public var displayName: String {
            switch self {
            case .sd480p:
                return "480p SD"
            case .hd720p:
                return "720p HD"
            case .hd1080p:
                return "1080p Full HD"
            case .uhd4K:
                return "4K UHD"
            case .custom(let width, let height):
                return "\(width)×\(height) Custom"
            }
        }
    }

    /// Aspect ratio presets
    public enum AspectRatio: Sendable, Hashable {
        case ratio16x9      // 16:9 landscape
        case ratio9x16      // 9:16 portrait
        case ratio1x1       // 1:1 square
        case ratio4x3       // 4:3 classic
        case custom(width: Int, height: Int)

        /// Common preset cases (excluding custom)
        public static let presets: [AspectRatio] = [
            .ratio16x9,
            .ratio9x16,
            .ratio1x1,
            .ratio4x3
        ]

        public var ratio: (width: Int, height: Int) {
            switch self {
            case .ratio16x9:
                return (16, 9)
            case .ratio9x16:
                return (9, 16)
            case .ratio1x1:
                return (1, 1)
            case .ratio4x3:
                return (4, 3)
            case .custom(let width, let height):
                return (width, height)
            }
        }

        public var displayName: String {
            switch self {
            case .ratio16x9:
                return "16:9 Landscape"
            case .ratio9x16:
                return "9:16 Portrait"
            case .ratio1x1:
                return "1:1 Square"
            case .ratio4x3:
                return "4:3 Classic"
            case .custom(let width, let height):
                return "\(width):\(height) Custom"
            }
        }

        /// Calculate dimensions for a given height while maintaining aspect ratio
        public func dimensions(forHeight height: Int) -> (width: Int, height: Int) {
            let ratio = self.ratio
            let width = (height * ratio.width) / ratio.height
            return (width, height)
        }

        /// Calculate dimensions for a given width while maintaining aspect ratio
        public func dimensions(forWidth width: Int) -> (width: Int, height: Int) {
            let ratio = self.ratio
            let height = (width * ratio.height) / ratio.width
            return (width, height)
        }
    }

    /// Frame rate options
    public enum FrameRate: Int, Sendable, CaseIterable {
        case fps24 = 24
        case fps30 = 30
        case fps60 = 60

        public var displayName: String {
            "\(rawValue) fps"
        }
    }

    /// Video quality/bitrate preset
    public enum QualityPreset: Sendable, Hashable {
        case low        // Faster export, lower quality
        case medium     // Balanced
        case high       // Slower export, higher quality
        case custom(bitrate: Int)  // Bits per second

        public func bitrate(for resolution: ResolutionPreset) -> Int {
            switch self {
            case .low:
                // Low quality: ~2 Mbps for 1080p
                let baseRate = 2_000_000
                return scaleBitrate(baseRate, for: resolution)
            case .medium:
                // Medium quality: ~5 Mbps for 1080p
                let baseRate = 5_000_000
                return scaleBitrate(baseRate, for: resolution)
            case .high:
                // High quality: ~10 Mbps for 1080p
                let baseRate = 10_000_000
                return scaleBitrate(baseRate, for: resolution)
            case .custom(let bitrate):
                return bitrate
            }
        }

        private func scaleBitrate(_ baseBitrate: Int, for resolution: ResolutionPreset) -> Int {
            let dims = resolution.dimensions
            let pixels = dims.width * dims.height
            let base1080pPixels = 1920 * 1080
            let scale = Double(pixels) / Double(base1080pPixels)
            return Int(Double(baseBitrate) * scale)
        }

        public var displayName: String {
            switch self {
            case .low:
                return "Low (Fast)"
            case .medium:
                return "Medium (Balanced)"
            case .high:
                return "High (Best)"
            case .custom(let bitrate):
                let mbps = Double(bitrate) / 1_000_000.0
                return String(format: "Custom (%.1f Mbps)", mbps)
            }
        }
    }

    // MARK: - Configuration Properties

    /// Output file URL
    public let outputURL: URL

    /// Video codec to use
    public let codec: Codec

    /// Video resolution
    public let resolution: ResolutionPreset

    /// Aspect ratio (optional, overrides resolution aspect if provided)
    public let aspectRatio: AspectRatio?

    /// Frame rate
    public let frameRate: FrameRate

    /// Quality/bitrate preset
    public let quality: QualityPreset

    /// Whether to include a background video
    public let backgroundVideoURL: URL?

    /// Whether to export with transparent background (if no background video)
    /// Note: Requires codec that supports alpha (HEVC with alpha, ProRes 4444)
    public let transparentBackground: Bool

    /// Canvas size for rendering overlays
    /// If nil, uses resolution dimensions
    public let canvasSize: CGSize?

    // MARK: - Initialization

    public init(
        outputURL: URL,
        codec: Codec = .h264,
        resolution: ResolutionPreset = .hd1080p,
        aspectRatio: AspectRatio? = nil,
        frameRate: FrameRate = .fps30,
        quality: QualityPreset = .medium,
        backgroundVideoURL: URL? = nil,
        transparentBackground: Bool = false,
        canvasSize: CGSize? = nil
    ) {
        self.outputURL = outputURL
        self.codec = codec
        self.resolution = resolution
        self.aspectRatio = aspectRatio
        self.frameRate = frameRate
        self.quality = quality
        self.backgroundVideoURL = backgroundVideoURL
        self.transparentBackground = transparentBackground
        self.canvasSize = canvasSize
    }

    // MARK: - Computed Properties

    /// Actual dimensions to use for export (considering aspect ratio override)
    public var effectiveDimensions: (width: Int, height: Int) {
        if let aspectRatio = aspectRatio {
            // Use resolution's height and calculate width from aspect ratio
            let baseHeight = resolution.dimensions.height
            return aspectRatio.dimensions(forHeight: baseHeight)
        } else {
            // Use resolution's default dimensions
            return resolution.dimensions
        }
    }

    /// Actual canvas size to use for rendering
    public var effectiveCanvasSize: CGSize {
        if let canvasSize = canvasSize {
            return canvasSize
        }
        let dims = effectiveDimensions
        return CGSize(width: dims.width, height: dims.height)
    }

    /// Bitrate in bits per second
    public var bitrate: Int {
        quality.bitrate(for: resolution)
    }

    /// AVFoundation video settings dictionary
    public var videoSettings: [String: Any] {
        let dims = effectiveDimensions

        var settings: [String: Any] = [
            AVVideoCodecKey: codec.avCodecKey,
            AVVideoWidthKey: dims.width,
            AVVideoHeightKey: dims.height,
        ]

        // Compression properties
        var compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: bitrate,
            AVVideoExpectedSourceFrameRateKey: frameRate.rawValue,
            AVVideoMaxKeyFrameIntervalKey: frameRate.rawValue * 2, // Keyframe every 2 seconds
        ]

        // Profile level (H.264 specific)
        if codec == .h264 {
            compressionProperties[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
        }

        settings[AVVideoCompressionPropertiesKey] = compressionProperties

        return settings
    }
}

// MARK: - Preset Factories

extension ExportConfiguration {
    /// Quick preset: 1080p H.264 export
    public static func preset1080pH264(outputURL: URL) -> ExportConfiguration {
        ExportConfiguration(
            outputURL: outputURL,
            codec: .h264,
            resolution: .hd1080p,
            frameRate: .fps30,
            quality: .medium
        )
    }

    /// Quick preset: 4K HEVC export
    public static func preset4KHEVC(outputURL: URL) -> ExportConfiguration {
        ExportConfiguration(
            outputURL: outputURL,
            codec: .hevc,
            resolution: .uhd4K,
            frameRate: .fps30,
            quality: .high
        )
    }

    /// Quick preset: 720p for faster export
    public static func preset720pFast(outputURL: URL) -> ExportConfiguration {
        ExportConfiguration(
            outputURL: outputURL,
            codec: .h264,
            resolution: .hd720p,
            frameRate: .fps30,
            quality: .low
        )
    }
}
