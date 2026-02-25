// TimelineEngineTests.swift
// Unit tests for the Timeline Engine

import XCTest
import CoreLocation
@testable import FlightTraceCore

@MainActor
final class TimelineEngineTests: XCTestCase {

    // MARK: - Test Data

    func createTestTrack() -> TelemetryTrack {
        let baseTime = Date(timeIntervalSince1970: 1000000)

        // Create 10 points, 1 second apart
        let points = (0..<10).map { i in
            TelemetryPoint(
                timestamp: baseTime.addingTimeInterval(Double(i)),
                coordinate: CLLocationCoordinate2D(
                    latitude: 37.0 + Double(i) * 0.001,
                    longitude: -122.0 + Double(i) * 0.001
                ),
                elevation: 100.0 + Double(i) * 10.0,
                speed: 20.0 + Double(i) * 2.0,
                verticalSpeed: Double(i) * 0.5,
                heading: Double(i) * 30.0
            )
        }

        return TelemetryTrack(
            name: "Test Track",
            points: points
        )
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)

        XCTAssertNotNil(engine.track)
        XCTAssertEqual(engine.duration, 9.0) // 10 points, 1 second apart = 9 seconds duration
        XCTAssertEqual(engine.currentPosition.videoTime, 0.0)
        XCTAssertTrue(engine.isWithinTrack)
    }

    func testInitializationWithOffset() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track, timeOffset: 5.0)

        XCTAssertEqual(engine.timeOffset, 5.0)
    }

    // MARK: - Track Management Tests

    func testLoadTrack() {
        let engine = TimelineEngine()
        XCTAssertNil(engine.track)

        let track = createTestTrack()
        engine.loadTrack(track)

        XCTAssertNotNil(engine.track)
        XCTAssertEqual(engine.track?.name, "Test Track")
    }

    func testClearTrack() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)
        XCTAssertNotNil(engine.track)

        engine.clearTrack()
        XCTAssertNil(engine.track)
    }

    // MARK: - Playhead Control Tests

    func testSeek() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)

        engine.seek(to: 5.0)
        XCTAssertEqual(engine.currentPosition.videoTime, 5.0)

        engine.seek(to: 3.5)
        XCTAssertEqual(engine.currentPosition.videoTime, 3.5)
    }

    func testAdvance() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)

        engine.advance(by: 2.5)
        XCTAssertEqual(engine.currentPosition.videoTime, 2.5)

        engine.advance(by: 1.0)
        XCTAssertEqual(engine.currentPosition.videoTime, 3.5)

        engine.advance(by: -1.0)
        XCTAssertEqual(engine.currentPosition.videoTime, 2.5)
    }

    func testNextFrame() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)

        engine.nextFrame(frameRate: 30.0)
        XCTAssertEqual(engine.currentPosition.videoTime, 1.0 / 30.0, accuracy: 0.0001)

        engine.nextFrame(frameRate: 30.0)
        XCTAssertEqual(engine.currentPosition.videoTime, 2.0 / 30.0, accuracy: 0.0001)
    }

    func testPreviousFrame() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)

        engine.seek(to: 1.0)
        engine.previousFrame(frameRate: 30.0)
        XCTAssertEqual(engine.currentPosition.videoTime, 1.0 - 1.0 / 30.0, accuracy: 0.0001)
    }

    func testJumpToStart() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)

        engine.seek(to: 5.0)
        engine.jumpToStart()
        XCTAssertEqual(engine.currentPosition.videoTime, 0.0)
    }

    func testJumpToEnd() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)

        engine.jumpToEnd()
        XCTAssertEqual(engine.currentPosition.videoTime, engine.duration)
    }

    // MARK: - Time Offset Tests

    func testTimeOffsetPositive() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track, timeOffset: 5.0)

        // With +5s offset, video time 5.0 maps to GPX start
        engine.seek(to: 5.0)

        let gpxStart = track.startTime!
        let expectedGPXTime = gpxStart // Video 5.0 - offset 5.0 = GPX 0.0

        XCTAssertEqual(
            engine.currentPosition.gpxTimestamp.timeIntervalSince1970,
            expectedGPXTime.timeIntervalSince1970,
            accuracy: 0.01
        )
    }

    func testTimeOffsetNegative() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track, timeOffset: -3.0)

        // With -3s offset, video time 0.0 maps to GPX +3s
        engine.seek(to: 0.0)

        let gpxStart = track.startTime!
        let expectedGPXTime = gpxStart.addingTimeInterval(3.0)

        XCTAssertEqual(
            engine.currentPosition.gpxTimestamp.timeIntervalSince1970,
            expectedGPXTime.timeIntervalSince1970,
            accuracy: 0.01
        )
    }

    func testTimeOffsetChange() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)

        engine.seek(to: 2.0)
        let originalGPXTime = engine.currentPosition.gpxTimestamp

        engine.timeOffset = 1.0
        let newGPXTime = engine.currentPosition.gpxTimestamp

        // With offset change, GPX timestamp should change
        XCTAssertNotEqual(
            originalGPXTime.timeIntervalSince1970,
            newGPXTime.timeIntervalSince1970
        )
    }

    // MARK: - Trim Tests

    func testTrimStart() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)

        engine.trimStart = 2.0

        // Seeking before trim start should clamp to trim start
        engine.seek(to: 0.0)
        XCTAssertEqual(engine.currentPosition.videoTime, 2.0)

        engine.seek(to: 1.0)
        XCTAssertEqual(engine.currentPosition.videoTime, 2.0)

        engine.seek(to: 3.0)
        XCTAssertEqual(engine.currentPosition.videoTime, 3.0)
    }

    func testTrimEnd() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)

        engine.trimEnd = 6.0

        // Seeking after trim end should clamp to trim end
        engine.seek(to: 10.0)
        XCTAssertEqual(engine.currentPosition.videoTime, 6.0)

        engine.seek(to: 8.0)
        XCTAssertEqual(engine.currentPosition.videoTime, 6.0)

        engine.seek(to: 4.0)
        XCTAssertEqual(engine.currentPosition.videoTime, 4.0)
    }

    func testTrimBoth() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)

        engine.trimStart = 2.0
        engine.trimEnd = 7.0

        XCTAssertEqual(engine.effectiveDuration, 5.0) // 7 - 2 = 5

        engine.seek(to: 0.0)
        XCTAssertEqual(engine.currentPosition.videoTime, 2.0)

        engine.seek(to: 10.0)
        XCTAssertEqual(engine.currentPosition.videoTime, 7.0)
    }

    // MARK: - Data Access Tests

    func testCurrentPoint() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)

        engine.seek(to: 0.0)
        let point = engine.currentPoint()

        XCTAssertNotNil(point)
        XCTAssertEqual(point?.coordinate.latitude, 37.0, accuracy: 0.0001)
        XCTAssertEqual(point?.elevation, 100.0)
    }

    func testPointAtExactTimestamp() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)

        // Test point at exact video time
        engine.seek(to: 3.0)
        let point = engine.currentPoint()

        XCTAssertNotNil(point)
        XCTAssertEqual(point?.coordinate.latitude, 37.003, accuracy: 0.0001)
        XCTAssertEqual(point?.elevation, 130.0)
        XCTAssertEqual(point?.speed, 26.0)
    }

    func testPointsInRange() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)

        let startTime = track.startTime!.addingTimeInterval(2.0)
        let endTime = track.startTime!.addingTimeInterval(5.0)

        let points = engine.points(from: startTime, to: endTime)

        // Should include points at indices 2, 3, 4, 5
        XCTAssertEqual(points.count, 4)
    }

    func testLastPoints() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)

        engine.seek(to: 5.0)
        let last3 = engine.lastPoints(3)

        XCTAssertEqual(last3.count, 3)
        // Should be points at indices 3, 4, 5 (timestamps 3, 4, 5)
        XCTAssertEqual(last3.last?.coordinate.latitude, 37.005, accuracy: 0.0001)
    }

    // MARK: - Interpolation Tests

    func testInterpolationBetweenPoints() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)

        // Seek to time between point 2 and point 3
        engine.seek(to: 2.5)
        let point = engine.currentPoint()

        XCTAssertNotNil(point)

        // Latitude should be interpolated between 37.002 and 37.003
        let expectedLat = 37.0 + 0.001 * 2.5
        XCTAssertEqual(point?.coordinate.latitude, expectedLat, accuracy: 0.00001)

        // Elevation should be interpolated between 120.0 and 130.0
        let expectedElev = 100.0 + 10.0 * 2.5
        XCTAssertEqual(point?.elevation, expectedElev, accuracy: 0.1)

        // Speed should be interpolated between 24.0 and 26.0
        let expectedSpeed = 20.0 + 2.0 * 2.5
        XCTAssertEqual(point?.speed, expectedSpeed, accuracy: 0.1)
    }

    func testInterpolationSmoothness() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)

        // Test multiple interpolated points
        engine.seek(to: 1.25)
        let point1 = engine.currentPoint()

        engine.seek(to: 1.5)
        let point2 = engine.currentPoint()

        engine.seek(to: 1.75)
        let point3 = engine.currentPoint()

        // All should be valid
        XCTAssertNotNil(point1)
        XCTAssertNotNil(point2)
        XCTAssertNotNil(point3)

        // Should be progressively increasing
        XCTAssertLessThan(point1!.coordinate.latitude, point2!.coordinate.latitude)
        XCTAssertLessThan(point2!.coordinate.latitude, point3!.coordinate.latitude)
    }

    func testHeadingInterpolation() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)

        // Test heading interpolation at 0.5 seconds (between 0° and 30°)
        engine.seek(to: 0.5)
        let point = engine.currentPoint()

        XCTAssertNotNil(point)
        XCTAssertEqual(point?.heading, 15.0, accuracy: 0.1)
    }

    func testHeadingWrapAround() {
        // Create a track with heading wrap-around (350° to 10°)
        let baseTime = Date(timeIntervalSince1970: 1000000)

        let points = [
            TelemetryPoint(
                timestamp: baseTime,
                coordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0),
                heading: 350.0
            ),
            TelemetryPoint(
                timestamp: baseTime.addingTimeInterval(1.0),
                coordinate: CLLocationCoordinate2D(latitude: 37.001, longitude: -122.001),
                heading: 10.0
            )
        ]

        let track = TelemetryTrack(points: points)
        let engine = TimelineEngine(track: track)

        // At 0.5 seconds, heading should be 0° (not 180°)
        engine.seek(to: 0.5)
        let point = engine.currentPoint()

        XCTAssertNotNil(point)
        XCTAssertEqual(point?.heading, 0.0, accuracy: 1.0)
    }

    // MARK: - Time Conversion Tests

    func testVideoTimeToGPXTimestamp() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)

        let gpxTimestamp = engine.videoTimeToGPXTimestamp(3.0)
        let expectedTimestamp = track.startTime!.addingTimeInterval(3.0)

        XCTAssertEqual(
            gpxTimestamp.timeIntervalSince1970,
            expectedTimestamp.timeIntervalSince1970,
            accuracy: 0.01
        )
    }

    func testGPXTimestampToVideoTime() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)

        let gpxTimestamp = track.startTime!.addingTimeInterval(4.5)
        let videoTime = engine.gpxTimestampToVideoTime(gpxTimestamp)

        XCTAssertEqual(videoTime, 4.5, accuracy: 0.01)
    }

    func testTimeConversionWithOffset() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track, timeOffset: 2.0)

        // Video time 2.0 should map to GPX start (due to +2.0 offset)
        let gpxTimestamp = engine.videoTimeToGPXTimestamp(2.0)
        XCTAssertEqual(
            gpxTimestamp.timeIntervalSince1970,
            track.startTime!.timeIntervalSince1970,
            accuracy: 0.01
        )

        // And reverse conversion should work
        let videoTime = engine.gpxTimestampToVideoTime(track.startTime!)
        XCTAssertEqual(videoTime, 2.0, accuracy: 0.01)
    }

    // MARK: - Edge Case Tests

    func testSeekBeforeTrackStart() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track, timeOffset: 5.0)

        // Seek to video time before GPX starts
        engine.seek(to: 2.0)
        let point = engine.currentPoint()

        // Should return first point
        XCTAssertNotNil(point)
        XCTAssertEqual(point?.coordinate.latitude, 37.0, accuracy: 0.0001)
    }

    func testSeekAfterTrackEnd() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)

        // Seek beyond track duration
        engine.seek(to: 100.0)
        let point = engine.currentPoint()

        // Should return last point
        XCTAssertNotNil(point)
        XCTAssertEqual(point?.coordinate.latitude, 37.009, accuracy: 0.0001)
    }

    func testEmptyTrack() {
        let engine = TimelineEngine()

        XCTAssertNil(engine.currentPoint())
        XCTAssertEqual(engine.duration, 0.0)
        XCTAssertFalse(engine.isWithinTrack)
    }

    func testCacheClearing() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)

        // Access some points to populate cache
        engine.seek(to: 2.5)
        _ = engine.currentPoint()
        engine.seek(to: 3.7)
        _ = engine.currentPoint()

        // Clear cache
        engine.clearCache()

        // Should still work correctly after cache clear
        engine.seek(to: 2.5)
        let point = engine.currentPoint()
        XCTAssertNotNil(point)
    }

    // MARK: - Position State Tests

    func testNormalizedPosition() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)

        engine.seek(to: 0.0)
        XCTAssertEqual(engine.currentPosition.normalizedPosition, 0.0, accuracy: 0.01)

        engine.seek(to: 4.5)
        XCTAssertEqual(engine.currentPosition.normalizedPosition, 0.5, accuracy: 0.01)

        engine.seek(to: 9.0)
        XCTAssertEqual(engine.currentPosition.normalizedPosition, 1.0, accuracy: 0.01)
    }

    func testIsWithinTrack() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track, timeOffset: 5.0)

        // Before track starts (video time < offset)
        engine.seek(to: 2.0)
        XCTAssertTrue(engine.currentPosition.isWithinTrack) // Clamped to first point

        // Within track
        engine.seek(to: 7.0)
        XCTAssertTrue(engine.currentPosition.isWithinTrack)

        // After track ends
        engine.seek(to: 100.0)
        XCTAssertTrue(engine.currentPosition.isWithinTrack) // Clamped to last point
    }
}
