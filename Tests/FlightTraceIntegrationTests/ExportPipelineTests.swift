// ExportPipelineTests.swift
// Integration tests for the export pipeline

import XCTest
import AVFoundation
import CoreGraphics
@testable import FlightTraceCore
@testable import FlightTracePlugins
@testable import FlightTraceUI

/// Integration tests for the complete export pipeline
///
/// These tests verify:
/// - Export produces valid video files
/// - Frame accuracy over duration
/// - Overlay rendering works correctly
/// - Progress tracking functions
/// - Cancellation works properly
final class ExportPipelineTests: XCTestCase {

    var tempDirectory: URL!

    override func setUp() async throws {
        // Create temporary directory for test outputs
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlightTraceExportTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        // Clean up temporary files
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    // MARK: - Basic Export Tests

    /// Test that export produces a valid MP4 file
    func testExportProducesValidMP4() async throws {
        let outputURL = tempDirectory.appendingPathComponent("test_output.mp4")

        // Create a simple 5-second export configuration
        let config = ExportConfiguration(
            outputURL: outputURL,
            codec: .h264,
            resolution: .hd720p,
            frameRate: .fps30,
            quality: .low // Use low quality for faster test
        )

        // Create export engine with 5-second duration
        let engine = ExportEngine(
            configuration: config,
            duration: 5.0,
            startTime: Date()
        )

        // Setup simple rendering (black background with white rectangle)
        engine.setRenderingClosure { context, size, timestamp, frameNumber in
            // Draw black background
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(CGRect(origin: .zero, size: size))

            // Draw white rectangle that moves across the screen
            let progress = Double(frameNumber) / 150.0 // 5 seconds * 30 fps
            let x = size.width * progress
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(CGRect(x: x, y: size.height / 2 - 25, width: 50, height: 50))
        }

        // Execute export
        var progressUpdates: [ExportEngine.ExportProgress] = []
        try await engine.export { progress in
            progressUpdates.append(progress)
        }

        // Verify file was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path),
                     "Output video file should exist")

        // Verify file is a valid video
        let asset = AVAsset(url: outputURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        XCTAssertGreaterThan(durationSeconds, 4.9, "Video duration should be approximately 5 seconds")
        XCTAssertLessThan(durationSeconds, 5.1, "Video duration should be approximately 5 seconds")

        // Verify video has correct dimensions
        let tracks = try await asset.load(.tracks)
        let videoTracks = tracks.filter { $0.mediaType == .video }
        XCTAssertEqual(videoTracks.count, 1, "Should have exactly one video track")

        if let videoTrack = videoTracks.first {
            let naturalSize = try await videoTrack.load(.naturalSize)
            XCTAssertEqual(naturalSize.width, 1280, "Video width should be 1280 (720p)")
            XCTAssertEqual(naturalSize.height, 720, "Video height should be 720 (720p)")
        }

        // Verify progress updates were received
        XCTAssertFalse(progressUpdates.isEmpty, "Should receive progress updates")
        XCTAssertEqual(progressUpdates.last?.percentComplete ?? 0, 100, "Final progress should be 100%")
    }

    /// Test frame accuracy - verify no drift over time
    func testFrameAccuracy() async throws {
        let outputURL = tempDirectory.appendingPathComponent("test_frame_accuracy.mp4")

        let config = ExportConfiguration(
            outputURL: outputURL,
            codec: .h264,
            resolution: .sd480p, // Use lower resolution for faster test
            frameRate: .fps30,
            quality: .low
        )

        // Create 60-second export (longer duration to test for drift)
        let engine = ExportEngine(
            configuration: config,
            duration: 60.0,
            startTime: Date()
        )

        var renderedFrameCount = 0

        // Setup rendering closure that counts frames
        engine.setRenderingClosure { context, size, timestamp, frameNumber in
            renderedFrameCount += 1

            // Draw frame number as visual verification
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(CGRect(origin: .zero, size: size))

            // Draw frame number text
            let frameText = "Frame \(frameNumber)"
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 24)
            ]
            let attributedString = NSAttributedString(string: frameText, attributes: attributes)
            let line = CTLineCreateWithAttributedString(attributedString)

            context.textPosition = CGPoint(x: 20, y: size.height - 50)
            CTLineDraw(line, context)
        }

        try await engine.export()

        // Verify frame count
        let expectedFrames = 60 * 30 // 60 seconds * 30 fps
        XCTAssertEqual(renderedFrameCount, expectedFrames,
                      "Should render exactly \(expectedFrames) frames for 60 seconds at 30fps")

        // Verify video duration
        let asset = AVAsset(url: outputURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        // Allow small tolerance for encoding
        XCTAssertGreaterThan(durationSeconds, 59.5, "Video should be approximately 60 seconds")
        XCTAssertLessThan(durationSeconds, 60.5, "Video should be approximately 60 seconds")

        // Calculate drift
        let drift = abs(durationSeconds - 60.0)
        XCTAssertLessThan(drift, 0.1, "Drift should be less than 0.1 seconds over 1 minute")
    }

    // MARK: - Plugin Integration Tests

    /// Test export with actual instrument plugins
    @MainActor
    func testExportWithInstruments() async throws {
        // Register plugins
        try PluginHost.shared.register(SpeedGaugePlugin.self)

        let outputURL = tempDirectory.appendingPathComponent("test_with_instruments.mp4")

        // Create sample GPX data
        let track = createSampleTrack()

        // Create timeline
        let timeline = TimelineEngine(track: track)

        // Create instrument instance
        let speedGauge = InstrumentInstance(
            pluginID: "com.flighttrace.speed-gauge",
            name: "Speed",
            position: CGPoint(x: 50, y: 50),
            size: CGSize(width: 200, height: 80)
        )

        // Create export configuration
        let config = ExportConfiguration(
            outputURL: outputURL,
            codec: .h264,
            resolution: .hd720p,
            frameRate: .fps30,
            quality: .low
        )

        // Create orchestrator
        let orchestrator = ExportOrchestrator(
            instruments: [speedGauge],
            timeline: timeline,
            configuration: config
        )

        // Export
        try await orchestrator.export()

        // Verify output
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path),
                     "Output file should exist")

        let asset = AVAsset(url: outputURL)
        let tracks = try await asset.load(.tracks)
        XCTAssertEqual(tracks.filter { $0.mediaType == .video }.count, 1,
                      "Should have one video track")
    }

    // MARK: - Progress and Cancellation Tests

    /// Test that progress callbacks are invoked correctly
    func testProgressCallbacks() async throws {
        let outputURL = tempDirectory.appendingPathComponent("test_progress.mp4")

        let config = ExportConfiguration(
            outputURL: outputURL,
            codec: .h264,
            resolution: .sd480p,
            frameRate: .fps24,
            quality: .low
        )

        let engine = ExportEngine(
            configuration: config,
            duration: 2.0, // Short duration for fast test
            startTime: Date()
        )

        engine.setRenderingClosure { context, size, _, _ in
            context.setFillColor(CGColor(gray: 0.5, alpha: 1))
            context.fill(CGRect(origin: .zero, size: size))
        }

        var progressValues: [Double] = []

        try await engine.export { progress in
            progressValues.append(progress.percentComplete)
        }

        // Verify progress increased monotonically
        for i in 1..<progressValues.count {
            XCTAssertGreaterThanOrEqual(progressValues[i], progressValues[i-1],
                                       "Progress should increase monotonically")
        }

        // Verify final progress is 100%
        XCTAssertEqual(progressValues.last, 100.0, "Final progress should be 100%")
    }

    /// Test that cancellation stops the export
    func testCancellation() async throws {
        let outputURL = tempDirectory.appendingPathComponent("test_cancelled.mp4")

        let config = ExportConfiguration(
            outputURL: outputURL,
            codec: .h264,
            resolution: .hd720p,
            frameRate: .fps30,
            quality: .low
        )

        let engine = ExportEngine(
            configuration: config,
            duration: 30.0, // Longer duration so we can cancel
            startTime: Date()
        )

        engine.setRenderingClosure { context, size, _, _ in
            context.setFillColor(CGColor(gray: 0.5, alpha: 1))
            context.fill(CGRect(origin: .zero, size: size))
        }

        // Start export in a task
        let exportTask = Task {
            try await engine.export { progress in
                // Cancel after 10% progress
                if progress.percentComplete > 10 {
                    engine.cancel()
                }
            }
        }

        do {
            try await exportTask.value
            XCTFail("Export should have been cancelled")
        } catch {
            // Expect cancellation error
            XCTAssertTrue(error is ExportEngine.ExportError,
                         "Should throw ExportError")
        }
    }

    // MARK: - Configuration Tests

    /// Test different resolution presets
    func testResolutionPresets() async throws {
        let resolutions: [ExportConfiguration.ResolutionPreset] = [
            .sd480p,
            .hd720p,
            .hd1080p
        ]

        for resolution in resolutions {
            let outputURL = tempDirectory.appendingPathComponent("test_\(resolution.displayName).mp4")

            let config = ExportConfiguration(
                outputURL: outputURL,
                codec: .h264,
                resolution: resolution,
                frameRate: .fps30,
                quality: .low
            )

            let engine = ExportEngine(
                configuration: config,
                duration: 1.0, // Very short for speed
                startTime: Date()
            )

            engine.setRenderingClosure { context, size, _, _ in
                context.setFillColor(CGColor(gray: 0.5, alpha: 1))
                context.fill(CGRect(origin: .zero, size: size))
            }

            try await engine.export()

            // Verify dimensions
            let asset = AVAsset(url: outputURL)
            let tracks = try await asset.load(.tracks)
            let videoTrack = tracks.first(where: { $0.mediaType == .video })

            if let track = videoTrack {
                let naturalSize = try await track.load(.naturalSize)
                let expected = resolution.dimensions
                XCTAssertEqual(Int(naturalSize.width), expected.width,
                              "Width should match for \(resolution.displayName)")
                XCTAssertEqual(Int(naturalSize.height), expected.height,
                              "Height should match for \(resolution.displayName)")
            }
        }
    }

    // MARK: - Helper Methods

    /// Create a sample telemetry track for testing
    private func createSampleTrack() -> TelemetryTrack {
        let startTime = Date()
        var points: [TelemetryPoint] = []

        // Create 60 seconds of sample data at 1Hz
        for i in 0..<60 {
            let timestamp = startTime.addingTimeInterval(Double(i))
            let lat = 37.7749 + Double(i) * 0.0001 // Move slightly north
            let lon = -122.4194 + Double(i) * 0.0001 // Move slightly east
            let alt = 100.0 + Double(i) * 0.5 // Gradually climb

            let point = TelemetryPoint(
                latitude: lat,
                longitude: lon,
                altitude: alt,
                timestamp: timestamp,
                speed: 30.0, // 30 m/s
                course: nil,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 10.0
            )
            points.append(point)
        }

        return TelemetryTrack(
            name: "Test Track",
            points: points,
            segments: [[TelemetryPoint](points)]
        )
    }
}

// MARK: - Test Utilities

extension ExportPipelineTests {
    /// Verify video file metadata
    func verifyVideoMetadata(
        url: URL,
        expectedDuration: TimeInterval,
        expectedWidth: Int,
        expectedHeight: Int,
        file: StaticString = #file,
        line: UInt = #line
    ) async throws {
        let asset = AVAsset(url: url)

        // Check duration
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        XCTAssertEqual(durationSeconds, expectedDuration, accuracy: 0.1,
                      "Duration mismatch", file: file, line: line)

        // Check dimensions
        let tracks = try await asset.load(.tracks)
        let videoTrack = tracks.first(where: { $0.mediaType == .video })
        XCTAssertNotNil(videoTrack, "Should have video track", file: file, line: line)

        if let track = videoTrack {
            let naturalSize = try await track.load(.naturalSize)
            XCTAssertEqual(Int(naturalSize.width), expectedWidth,
                          "Width mismatch", file: file, line: line)
            XCTAssertEqual(Int(naturalSize.height), expectedHeight,
                          "Height mismatch", file: file, line: line)
        }
    }
}
