// ExportConfigurationTests.swift
// Tests for export configuration resolution and aspect ratio handling

import XCTest
@testable import FlightTraceCore

final class ExportConfigurationTests: XCTestCase {

    // MARK: - Resolution Preset Tests

    func testResolutionPreset480p() throws {
        let resolution = ExportConfiguration.ResolutionPreset.sd480p
        let dims = resolution.dimensions

        XCTAssertEqual(dims.width, 640, "480p width should be 640")
        XCTAssertEqual(dims.height, 480, "480p height should be 480")
        XCTAssertEqual(resolution.displayName, "480p SD")
    }

    func testResolutionPreset720p() throws {
        let resolution = ExportConfiguration.ResolutionPreset.hd720p
        let dims = resolution.dimensions

        XCTAssertEqual(dims.width, 1280, "720p width should be 1280")
        XCTAssertEqual(dims.height, 720, "720p height should be 720")
        XCTAssertEqual(resolution.displayName, "720p HD")
    }

    func testResolutionPreset1080p() throws {
        let resolution = ExportConfiguration.ResolutionPreset.hd1080p
        let dims = resolution.dimensions

        XCTAssertEqual(dims.width, 1920, "1080p width should be 1920")
        XCTAssertEqual(dims.height, 1080, "1080p height should be 1080")
        XCTAssertEqual(resolution.displayName, "1080p Full HD")
    }

    func testResolutionPreset4K() throws {
        let resolution = ExportConfiguration.ResolutionPreset.uhd4K
        let dims = resolution.dimensions

        XCTAssertEqual(dims.width, 3840, "4K width should be 3840")
        XCTAssertEqual(dims.height, 2160, "4K height should be 2160")
        XCTAssertEqual(resolution.displayName, "4K UHD")
    }

    func testResolutionPresetCustom() throws {
        let resolution = ExportConfiguration.ResolutionPreset.custom(width: 2560, height: 1440)
        let dims = resolution.dimensions

        XCTAssertEqual(dims.width, 2560, "Custom width should match")
        XCTAssertEqual(dims.height, 1440, "Custom height should match")
        XCTAssertEqual(resolution.displayName, "2560×1440 Custom")
    }

    // MARK: - Aspect Ratio Tests

    func testAspectRatio16x9() throws {
        let aspectRatio = ExportConfiguration.AspectRatio.ratio16x9
        let ratio = aspectRatio.ratio

        XCTAssertEqual(ratio.width, 16)
        XCTAssertEqual(ratio.height, 9)
        XCTAssertEqual(aspectRatio.displayName, "16:9 Landscape")

        // Test dimension calculation
        let dims = aspectRatio.dimensions(forHeight: 1080)
        XCTAssertEqual(dims.width, 1920, "16:9 @ 1080p should be 1920 wide")
        XCTAssertEqual(dims.height, 1080)
    }

    func testAspectRatio9x16() throws {
        let aspectRatio = ExportConfiguration.AspectRatio.ratio9x16
        let ratio = aspectRatio.ratio

        XCTAssertEqual(ratio.width, 9)
        XCTAssertEqual(ratio.height, 16)
        XCTAssertEqual(aspectRatio.displayName, "9:16 Portrait")

        // Test dimension calculation
        let dims = aspectRatio.dimensions(forHeight: 1920)
        XCTAssertEqual(dims.width, 1080, "9:16 @ 1920p should be 1080 wide")
        XCTAssertEqual(dims.height, 1920)
    }

    func testAspectRatio1x1() throws {
        let aspectRatio = ExportConfiguration.AspectRatio.ratio1x1
        let ratio = aspectRatio.ratio

        XCTAssertEqual(ratio.width, 1)
        XCTAssertEqual(ratio.height, 1)
        XCTAssertEqual(aspectRatio.displayName, "1:1 Square")

        // Test dimension calculation
        let dims = aspectRatio.dimensions(forHeight: 1080)
        XCTAssertEqual(dims.width, 1080, "1:1 @ 1080p should be 1080 wide")
        XCTAssertEqual(dims.height, 1080)
    }

    func testAspectRatio4x3() throws {
        let aspectRatio = ExportConfiguration.AspectRatio.ratio4x3
        let ratio = aspectRatio.ratio

        XCTAssertEqual(ratio.width, 4)
        XCTAssertEqual(ratio.height, 3)
        XCTAssertEqual(aspectRatio.displayName, "4:3 Classic")

        // Test dimension calculation
        let dims = aspectRatio.dimensions(forHeight: 1080)
        XCTAssertEqual(dims.width, 1440, "4:3 @ 1080p should be 1440 wide")
        XCTAssertEqual(dims.height, 1080)
    }

    func testAspectRatioCustom() throws {
        let aspectRatio = ExportConfiguration.AspectRatio.custom(width: 21, height: 9)
        let ratio = aspectRatio.ratio

        XCTAssertEqual(ratio.width, 21)
        XCTAssertEqual(ratio.height, 9)
        XCTAssertEqual(aspectRatio.displayName, "21:9 Custom")
    }

    func testAspectRatioDimensionsForWidth() throws {
        let aspectRatio = ExportConfiguration.AspectRatio.ratio16x9
        let dims = aspectRatio.dimensions(forWidth: 3840)

        XCTAssertEqual(dims.width, 3840)
        XCTAssertEqual(dims.height, 2160, "16:9 @ 3840 wide should be 2160 tall")
    }

    // MARK: - Configuration Tests

    func testConfigurationWithoutAspectRatio() throws {
        let url = URL(fileURLWithPath: "/tmp/test.mp4")
        let config = ExportConfiguration(
            outputURL: url,
            resolution: .hd1080p
        )

        let dims = config.effectiveDimensions
        XCTAssertEqual(dims.width, 1920, "Without aspect ratio override, should use resolution default")
        XCTAssertEqual(dims.height, 1080)

        let canvasSize = config.effectiveCanvasSize
        XCTAssertEqual(canvasSize.width, 1920)
        XCTAssertEqual(canvasSize.height, 1080)
    }

    func testConfigurationWithAspectRatioOverride() throws {
        let url = URL(fileURLWithPath: "/tmp/test.mp4")
        let config = ExportConfiguration(
            outputURL: url,
            resolution: .hd1080p,
            aspectRatio: .ratio9x16  // Portrait override
        )

        let dims = config.effectiveDimensions
        XCTAssertEqual(dims.width, 607, "9:16 aspect ratio @ 1080 height should be 607 wide")
        XCTAssertEqual(dims.height, 1080)

        let canvasSize = config.effectiveCanvasSize
        XCTAssertEqual(canvasSize.width, 607)
        XCTAssertEqual(canvasSize.height, 1080)
    }

    func testConfigurationWith1x1AspectRatio() throws {
        let url = URL(fileURLWithPath: "/tmp/test.mp4")
        let config = ExportConfiguration(
            outputURL: url,
            resolution: .hd1080p,
            aspectRatio: .ratio1x1
        )

        let dims = config.effectiveDimensions
        XCTAssertEqual(dims.width, 1080, "1:1 aspect ratio @ 1080 height should be 1080 wide")
        XCTAssertEqual(dims.height, 1080)
    }

    func testConfiguration4KWith16x9() throws {
        let url = URL(fileURLWithPath: "/tmp/test.mp4")
        let config = ExportConfiguration(
            outputURL: url,
            resolution: .uhd4K,
            aspectRatio: .ratio16x9
        )

        let dims = config.effectiveDimensions
        XCTAssertEqual(dims.width, 3840, "16:9 aspect ratio @ 2160 height should be 3840 wide")
        XCTAssertEqual(dims.height, 2160)
    }

    // MARK: - Video Settings Tests

    func testVideoSettingsUsesEffectiveDimensions() throws {
        let url = URL(fileURLWithPath: "/tmp/test.mp4")
        let config = ExportConfiguration(
            outputURL: url,
            resolution: .hd1080p,
            aspectRatio: .ratio1x1  // Square override
        )

        let settings = config.videoSettings

        XCTAssertEqual(settings[AVVideoWidthKey] as? Int, 1080, "Video width should use effective dimensions")
        XCTAssertEqual(settings[AVVideoHeightKey] as? Int, 1080, "Video height should use effective dimensions")
    }

    // MARK: - Frame Rate Tests

    func testFrameRate24fps() throws {
        let frameRate = ExportConfiguration.FrameRate.fps24
        XCTAssertEqual(frameRate.rawValue, 24)
        XCTAssertEqual(frameRate.displayName, "24 fps")
    }

    func testFrameRate30fps() throws {
        let frameRate = ExportConfiguration.FrameRate.fps30
        XCTAssertEqual(frameRate.rawValue, 30)
        XCTAssertEqual(frameRate.displayName, "30 fps")
    }

    func testFrameRate60fps() throws {
        let frameRate = ExportConfiguration.FrameRate.fps60
        XCTAssertEqual(frameRate.rawValue, 60)
        XCTAssertEqual(frameRate.displayName, "60 fps")
    }

    // MARK: - Codec Tests

    func testCodecH264() throws {
        let codec = ExportConfiguration.Codec.h264
        XCTAssertEqual(codec.rawValue, "H.264")
        XCTAssertEqual(codec.avCodecKey, .h264)
    }

    func testCodecHEVC() throws {
        let codec = ExportConfiguration.Codec.hevc
        XCTAssertEqual(codec.rawValue, "HEVC/H.265")
        XCTAssertEqual(codec.avCodecKey, .hevc)
    }

    // MARK: - Quality Preset Tests

    func testQualityPresetBitrates() throws {
        let resolution = ExportConfiguration.ResolutionPreset.hd1080p

        let lowBitrate = ExportConfiguration.QualityPreset.low.bitrate(for: resolution)
        let mediumBitrate = ExportConfiguration.QualityPreset.medium.bitrate(for: resolution)
        let highBitrate = ExportConfiguration.QualityPreset.high.bitrate(for: resolution)

        XCTAssertEqual(lowBitrate, 2_000_000, "Low quality @ 1080p should be 2 Mbps")
        XCTAssertEqual(mediumBitrate, 5_000_000, "Medium quality @ 1080p should be 5 Mbps")
        XCTAssertEqual(highBitrate, 10_000_000, "High quality @ 1080p should be 10 Mbps")
    }

    func testQualityPresetScaling() throws {
        let resolution4K = ExportConfiguration.ResolutionPreset.uhd4K
        let resolution720p = ExportConfiguration.ResolutionPreset.hd720p

        let bitrate4K = ExportConfiguration.QualityPreset.medium.bitrate(for: resolution4K)
        let bitrate720p = ExportConfiguration.QualityPreset.medium.bitrate(for: resolution720p)

        // 4K should have ~4x the bitrate of 1080p (4x the pixels)
        // 720p should have ~0.44x the bitrate of 1080p
        XCTAssertGreaterThan(bitrate4K, 15_000_000, "4K should have higher bitrate")
        XCTAssertLessThan(bitrate720p, 3_000_000, "720p should have lower bitrate")
    }

    func testQualityPresetCustom() throws {
        let customBitrate = 8_000_000
        let quality = ExportConfiguration.QualityPreset.custom(bitrate: customBitrate)
        let resolution = ExportConfiguration.ResolutionPreset.hd1080p

        XCTAssertEqual(quality.bitrate(for: resolution), customBitrate)
        XCTAssertEqual(quality.displayName, "Custom (8.0 Mbps)")
    }
}
