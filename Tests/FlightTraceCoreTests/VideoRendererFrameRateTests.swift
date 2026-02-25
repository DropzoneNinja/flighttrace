// VideoRendererFrameRateTests.swift
// Tests for frame rate accuracy in video rendering

import XCTest
import CoreMedia
@testable import FlightTraceCore

final class VideoRendererFrameRateTests: XCTestCase {

    // MARK: - Frame Count Tests

    func testTotalFramesAt24fps() throws {
        let config = ExportConfiguration(
            outputURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            frameRate: .fps24
        )
        let renderer = VideoRenderer(configuration: config)

        // Test 1 second
        let frames1s = renderer.totalFrames(forDuration: 1.0)
        XCTAssertEqual(frames1s, 24, "1 second @ 24fps should be 24 frames")

        // Test 10 seconds
        let frames10s = renderer.totalFrames(forDuration: 10.0)
        XCTAssertEqual(frames10s, 240, "10 seconds @ 24fps should be 240 frames")

        // Test 1 minute
        let frames60s = renderer.totalFrames(forDuration: 60.0)
        XCTAssertEqual(frames60s, 1440, "60 seconds @ 24fps should be 1440 frames")
    }

    func testTotalFramesAt30fps() throws {
        let config = ExportConfiguration(
            outputURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            frameRate: .fps30
        )
        let renderer = VideoRenderer(configuration: config)

        // Test 1 second
        let frames1s = renderer.totalFrames(forDuration: 1.0)
        XCTAssertEqual(frames1s, 30, "1 second @ 30fps should be 30 frames")

        // Test 10 seconds
        let frames10s = renderer.totalFrames(forDuration: 10.0)
        XCTAssertEqual(frames10s, 300, "10 seconds @ 30fps should be 300 frames")

        // Test 1 minute
        let frames60s = renderer.totalFrames(forDuration: 60.0)
        XCTAssertEqual(frames60s, 1800, "60 seconds @ 30fps should be 1800 frames")
    }

    func testTotalFramesAt60fps() throws {
        let config = ExportConfiguration(
            outputURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            frameRate: .fps60
        )
        let renderer = VideoRenderer(configuration: config)

        // Test 1 second
        let frames1s = renderer.totalFrames(forDuration: 1.0)
        XCTAssertEqual(frames1s, 60, "1 second @ 60fps should be 60 frames")

        // Test 10 seconds
        let frames10s = renderer.totalFrames(forDuration: 10.0)
        XCTAssertEqual(frames10s, 600, "10 seconds @ 60fps should be 600 frames")

        // Test 1 minute
        let frames60s = renderer.totalFrames(forDuration: 60.0)
        XCTAssertEqual(frames60s, 3600, "60 seconds @ 60fps should be 3600 frames")
    }

    // MARK: - Presentation Time Tests

    func testPresentationTimeAt24fps() throws {
        let config = ExportConfiguration(
            outputURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            frameRate: .fps24
        )
        let renderer = VideoRenderer(configuration: config)

        // Frame 0 should be at time 0
        let time0 = renderer.presentationTime(forFrame: 0)
        XCTAssertEqual(CMTimeGetSeconds(time0), 0.0, accuracy: 0.001)

        // Frame 24 should be at time 1.0 second (24 frames @ 24fps = 1 second)
        let time24 = renderer.presentationTime(forFrame: 24)
        XCTAssertEqual(CMTimeGetSeconds(time24), 1.0, accuracy: 0.001)

        // Frame 240 should be at time 10.0 seconds
        let time240 = renderer.presentationTime(forFrame: 240)
        XCTAssertEqual(CMTimeGetSeconds(time240), 10.0, accuracy: 0.001)
    }

    func testPresentationTimeAt30fps() throws {
        let config = ExportConfiguration(
            outputURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            frameRate: .fps30
        )
        let renderer = VideoRenderer(configuration: config)

        // Frame 0 should be at time 0
        let time0 = renderer.presentationTime(forFrame: 0)
        XCTAssertEqual(CMTimeGetSeconds(time0), 0.0, accuracy: 0.001)

        // Frame 30 should be at time 1.0 second
        let time30 = renderer.presentationTime(forFrame: 30)
        XCTAssertEqual(CMTimeGetSeconds(time30), 1.0, accuracy: 0.001)

        // Frame 300 should be at time 10.0 seconds
        let time300 = renderer.presentationTime(forFrame: 300)
        XCTAssertEqual(CMTimeGetSeconds(time300), 10.0, accuracy: 0.001)
    }

    func testPresentationTimeAt60fps() throws {
        let config = ExportConfiguration(
            outputURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            frameRate: .fps60
        )
        let renderer = VideoRenderer(configuration: config)

        // Frame 0 should be at time 0
        let time0 = renderer.presentationTime(forFrame: 0)
        XCTAssertEqual(CMTimeGetSeconds(time0), 0.0, accuracy: 0.001)

        // Frame 60 should be at time 1.0 second
        let time60 = renderer.presentationTime(forFrame: 60)
        XCTAssertEqual(CMTimeGetSeconds(time60), 1.0, accuracy: 0.001)

        // Frame 600 should be at time 10.0 seconds
        let time600 = renderer.presentationTime(forFrame: 600)
        XCTAssertEqual(CMTimeGetSeconds(time600), 10.0, accuracy: 0.001)

        // Frame 3600 should be at time 60.0 seconds
        let time3600 = renderer.presentationTime(forFrame: 3600)
        XCTAssertEqual(CMTimeGetSeconds(time3600), 60.0, accuracy: 0.001)
    }

    // MARK: - Frame Duration Consistency Tests

    func testFrameDurationConsistency24fps() throws {
        let config = ExportConfiguration(
            outputURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            frameRate: .fps24
        )
        let renderer = VideoRenderer(configuration: config)

        let expectedFrameDuration = 1.0 / 24.0

        for frameNumber in 0..<100 {
            let currentTime = renderer.presentationTime(forFrame: frameNumber)
            let nextTime = renderer.presentationTime(forFrame: frameNumber + 1)

            let frameDuration = CMTimeGetSeconds(nextTime) - CMTimeGetSeconds(currentTime)
            XCTAssertEqual(
                frameDuration,
                expectedFrameDuration,
                accuracy: 0.0001,
                "Frame duration should be consistent at \(expectedFrameDuration)s"
            )
        }
    }

    func testFrameDurationConsistency30fps() throws {
        let config = ExportConfiguration(
            outputURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            frameRate: .fps30
        )
        let renderer = VideoRenderer(configuration: config)

        let expectedFrameDuration = 1.0 / 30.0

        for frameNumber in 0..<100 {
            let currentTime = renderer.presentationTime(forFrame: frameNumber)
            let nextTime = renderer.presentationTime(forFrame: frameNumber + 1)

            let frameDuration = CMTimeGetSeconds(nextTime) - CMTimeGetSeconds(currentTime)
            XCTAssertEqual(
                frameDuration,
                expectedFrameDuration,
                accuracy: 0.0001,
                "Frame duration should be consistent at \(expectedFrameDuration)s"
            )
        }
    }

    func testFrameDurationConsistency60fps() throws {
        let config = ExportConfiguration(
            outputURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            frameRate: .fps60
        )
        let renderer = VideoRenderer(configuration: config)

        let expectedFrameDuration = 1.0 / 60.0

        for frameNumber in 0..<100 {
            let currentTime = renderer.presentationTime(forFrame: frameNumber)
            let nextTime = renderer.presentationTime(forFrame: frameNumber + 1)

            let frameDuration = CMTimeGetSeconds(nextTime) - CMTimeGetSeconds(currentTime)
            XCTAssertEqual(
                frameDuration,
                expectedFrameDuration,
                accuracy: 0.0001,
                "Frame duration should be consistent at \(expectedFrameDuration)s"
            )
        }
    }

    // MARK: - Long Duration Tests

    func testLongDurationFrameCount() throws {
        // Test that long videos (e.g., 1 hour) calculate correct frame counts
        let config = ExportConfiguration(
            outputURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            frameRate: .fps30
        )
        let renderer = VideoRenderer(configuration: config)

        // 1 hour = 3600 seconds @ 30fps = 108000 frames
        let framesIn1Hour = renderer.totalFrames(forDuration: 3600.0)
        XCTAssertEqual(framesIn1Hour, 108000, "1 hour @ 30fps should be 108000 frames")
    }

    func testLongDurationPresentationTime() throws {
        let config = ExportConfiguration(
            outputURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            frameRate: .fps60
        )
        let renderer = VideoRenderer(configuration: config)

        // Test that presentation time is accurate even for large frame numbers
        let frame3600 = 3600  // Frame at 60 seconds
        let time = renderer.presentationTime(forFrame: frame3600)
        XCTAssertEqual(CMTimeGetSeconds(time), 60.0, accuracy: 0.001, "Frame 3600 @ 60fps should be at 60s")

        // Test at 10 minutes (36000 frames @ 60fps)
        let frame36000 = 36000
        let time10min = renderer.presentationTime(forFrame: frame36000)
        XCTAssertEqual(CMTimeGetSeconds(time10min), 600.0, accuracy: 0.001, "Frame 36000 @ 60fps should be at 600s")
    }

    // MARK: - Edge Cases

    func testZeroDuration() throws {
        let config = ExportConfiguration(
            outputURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            frameRate: .fps30
        )
        let renderer = VideoRenderer(configuration: config)

        let frames = renderer.totalFrames(forDuration: 0.0)
        XCTAssertEqual(frames, 0, "Zero duration should produce 0 frames")
    }

    func testFractionalSecond() throws {
        let config = ExportConfiguration(
            outputURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            frameRate: .fps30
        )
        let renderer = VideoRenderer(configuration: config)

        // 0.5 seconds @ 30fps should be 15 frames
        let frames = renderer.totalFrames(forDuration: 0.5)
        XCTAssertEqual(frames, 15, "0.5 seconds @ 30fps should be 15 frames")
    }

    func testVeryShortDuration() throws {
        let config = ExportConfiguration(
            outputURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            frameRate: .fps60
        )
        let renderer = VideoRenderer(configuration: config)

        // 1/60th of a second should be 1 frame
        let frames = renderer.totalFrames(forDuration: 1.0 / 60.0)
        XCTAssertEqual(frames, 1, "1/60th second @ 60fps should be 1 frame")
    }

    // MARK: - Frame Rate Accuracy Integration Test

    func testFrameRateAccuracyRoundTrip() throws {
        // This test ensures that duration -> frames -> presentation time -> duration is consistent
        let frameRates: [ExportConfiguration.FrameRate] = [.fps24, .fps30, .fps60]
        let testDuration = 10.0  // 10 seconds

        for frameRate in frameRates {
            let config = ExportConfiguration(
                outputURL: URL(fileURLWithPath: "/tmp/test.mp4"),
                frameRate: frameRate
            )
            let renderer = VideoRenderer(configuration: config)

            // Convert duration to frame count
            let totalFrames = renderer.totalFrames(forDuration: testDuration)

            // Get presentation time of last frame
            let lastFrameTime = renderer.presentationTime(forFrame: totalFrames - 1)
            let lastFrameSeconds = CMTimeGetSeconds(lastFrameTime)

            // Last frame should be just before the end of the duration
            let frameDuration = 1.0 / Double(frameRate.rawValue)
            let expectedLastFrameTime = testDuration - frameDuration

            XCTAssertEqual(
                lastFrameSeconds,
                expectedLastFrameTime,
                accuracy: 0.001,
                "Last frame @ \(frameRate.displayName) should be at \(expectedLastFrameTime)s"
            )
        }
    }
}
