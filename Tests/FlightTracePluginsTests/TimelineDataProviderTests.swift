// TimelineDataProviderTests.swift
// Tests for the TimelineDataProvider adapter

import XCTest
import CoreLocation
@testable import FlightTracePlugins
@testable import FlightTraceCore

@MainActor
final class TimelineDataProviderTests: XCTestCase {

    // MARK: - Test Data

    func createTestTrack() -> TelemetryTrack {
        let baseTime = Date(timeIntervalSince1970: 1000000)

        let points = (0..<10).map { i in
            TelemetryPoint(
                timestamp: baseTime.addingTimeInterval(Double(i)),
                coordinate: CLLocationCoordinate2D(
                    latitude: 37.0 + Double(i) * 0.001,
                    longitude: -122.0 + Double(i) * 0.001
                ),
                elevation: 100.0 + Double(i) * 10.0,
                speed: 20.0 + Double(i) * 2.0
            )
        }

        return TelemetryTrack(name: "Test Track", points: points)
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)
        let provider = TimelineDataProvider(engine: engine)

        XCTAssertNotNil(provider)
    }

    func testConvenienceMethod() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)
        let provider = engine.asDataProvider()

        XCTAssertNotNil(provider)
    }

    // MARK: - Data Access Tests

    func testCurrentPoint() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)
        let provider = TimelineDataProvider(engine: engine)

        engine.seek(to: 3.0)
        let point = provider.currentPoint()

        XCTAssertNotNil(point)
        XCTAssertEqual(point?.coordinate.latitude, 37.003, accuracy: 0.0001)
        XCTAssertEqual(point?.elevation, 130.0)
    }

    func testPointAtTimestamp() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)
        let provider = TimelineDataProvider(engine: engine)

        let timestamp = track.startTime!.addingTimeInterval(5.0)
        let point = provider.point(at: timestamp)

        XCTAssertNotNil(point)
        XCTAssertEqual(point?.coordinate.latitude, 37.005, accuracy: 0.0001)
    }

    func testPointsInRange() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)
        let provider = TimelineDataProvider(engine: engine)

        let startTime = track.startTime!.addingTimeInterval(2.0)
        let endTime = track.startTime!.addingTimeInterval(5.0)

        let points = provider.points(from: startTime, to: endTime)

        XCTAssertEqual(points.count, 4)
        XCTAssertEqual(points.first?.coordinate.latitude, 37.002, accuracy: 0.0001)
        XCTAssertEqual(points.last?.coordinate.latitude, 37.005, accuracy: 0.0001)
    }

    func testLastPoints() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)
        let provider = TimelineDataProvider(engine: engine)

        engine.seek(to: 5.0)
        let lastPoints = provider.lastPoints(3)

        XCTAssertEqual(lastPoints.count, 3)
        XCTAssertEqual(lastPoints.last?.coordinate.latitude, 37.005, accuracy: 0.0001)
    }

    func testTrackAccess() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)
        let provider = TimelineDataProvider(engine: engine)

        let retrievedTrack = provider.track()

        XCTAssertNotNil(retrievedTrack)
        XCTAssertEqual(retrievedTrack?.name, "Test Track")
        XCTAssertEqual(retrievedTrack?.points.count, 10)
    }

    func testTrackStatistics() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)
        let provider = TimelineDataProvider(engine: engine)

        let stats = provider.trackStatistics()

        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.duration, 9.0)
        XCTAssertEqual(stats?.maxSpeed, 38.0) // Last point has speed 38.0
        XCTAssertEqual(stats?.maxElevation, 190.0) // Last point has elevation 190.0
        XCTAssertEqual(stats?.minElevation, 100.0) // First point has elevation 100.0
    }

    // MARK: - Integration Tests

    func testDataProviderWithTimelineUpdates() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)
        let provider = TimelineDataProvider(engine: engine)

        // Initial position
        engine.seek(to: 2.0)
        let point1 = provider.currentPoint()
        XCTAssertEqual(point1?.coordinate.latitude, 37.002, accuracy: 0.0001)

        // Update position
        engine.seek(to: 5.0)
        let point2 = provider.currentPoint()
        XCTAssertEqual(point2?.coordinate.latitude, 37.005, accuracy: 0.0001)

        // Verify points are different
        XCTAssertNotEqual(point1?.coordinate.latitude, point2?.coordinate.latitude)
    }

    func testDataProviderWithOffset() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track, timeOffset: 3.0)
        let provider = TimelineDataProvider(engine: engine)

        // Video time 3.0 should map to GPX start
        engine.seek(to: 3.0)
        let point = provider.currentPoint()

        XCTAssertNotNil(point)
        XCTAssertEqual(point?.coordinate.latitude, 37.0, accuracy: 0.0001)
    }

    func testDataProviderWithInterpolation() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)
        let provider = TimelineDataProvider(engine: engine)

        // Seek to time between samples
        engine.seek(to: 2.5)
        let point = provider.currentPoint()

        XCTAssertNotNil(point)

        // Should be interpolated
        let expectedLat = 37.0 + 0.001 * 2.5
        XCTAssertEqual(point?.coordinate.latitude, expectedLat, accuracy: 0.00001)
    }

    // MARK: - Edge Case Tests

    func testDataProviderWithNoTrack() {
        let engine = TimelineEngine()
        let provider = TimelineDataProvider(engine: engine)

        XCTAssertNil(provider.currentPoint())
        XCTAssertNil(provider.track())
        XCTAssertNil(provider.trackStatistics())
    }

    func testDataProviderWithEmptyRange() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)
        let provider = TimelineDataProvider(engine: engine)

        let startTime = track.startTime!
        let points = provider.points(from: startTime, to: startTime)

        // Should return the point at that exact time
        XCTAssertEqual(points.count, 1)
    }

    func testDataProviderWithInvertedRange() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)
        let provider = TimelineDataProvider(engine: engine)

        let startTime = track.startTime!.addingTimeInterval(5.0)
        let endTime = track.startTime!.addingTimeInterval(2.0)

        // Inverted range should return empty array
        let points = provider.points(from: startTime, to: endTime)
        XCTAssertEqual(points.count, 0)
    }

    func testLastPointsAtStart() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)
        let provider = TimelineDataProvider(engine: engine)

        // At start, requesting 5 points should only return the first point
        engine.seek(to: 0.0)
        let points = provider.lastPoints(5)

        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points.first?.coordinate.latitude, 37.0, accuracy: 0.0001)
    }

    func testLastPointsMoreThanAvailable() {
        let track = createTestTrack()
        let engine = TimelineEngine(track: track)
        let provider = TimelineDataProvider(engine: engine)

        engine.seek(to: 3.0)
        let points = provider.lastPoints(100) // Request more than available

        // Should return all points up to current position (4 points: 0, 1, 2, 3)
        XCTAssertEqual(points.count, 4)
    }
}
