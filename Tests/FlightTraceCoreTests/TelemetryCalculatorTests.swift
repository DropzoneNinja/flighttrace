// TelemetryCalculatorTests.swift
// Unit tests for telemetry calculation functionality

import XCTest
import CoreLocation
@testable import FlightTraceCore

final class TelemetryCalculatorTests: XCTestCase {

    // MARK: - Distance Calculation Tests

    func testCalculateDistance() {
        let coord1 = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let coord2 = CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195)

        let distance = TelemetryCalculator.calculateDistance(from: coord1, to: coord2)

        // Distance should be approximately 13-15 meters
        XCTAssertGreaterThan(distance, 10.0)
        XCTAssertLessThan(distance, 20.0)
    }

    func testCalculateDistanceSamePoint() {
        let coord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        let distance = TelemetryCalculator.calculateDistance(from: coord, to: coord)

        XCTAssertEqual(distance, 0.0, accuracy: 0.001)
    }

    // MARK: - Bearing Calculation Tests

    func testCalculateBearingNorth() {
        let start = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let end = CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4194)

        let bearing = TelemetryCalculator.calculateBearing(from: start, to: end)

        // Bearing should be approximately north (0 degrees)
        XCTAssertLessThan(bearing, 5.0)
    }

    func testCalculateBearingEast() {
        let start = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let end = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4184)

        let bearing = TelemetryCalculator.calculateBearing(from: start, to: end)

        // Bearing should be approximately east (90 degrees)
        XCTAssertGreaterThan(bearing, 85.0)
        XCTAssertLessThan(bearing, 95.0)
    }

    // MARK: - Speed Derivation Tests

    func testDeriveSpeedFromPositionDeltas() {
        let formatter = ISO8601DateFormatter()
        let time1 = formatter.date(from: "2024-01-01T12:00:00Z")!
        let time2 = formatter.date(from: "2024-01-01T12:00:10Z")!

        let point1 = TelemetryPoint(
            timestamp: time1,
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            elevation: 100.0
        )

        let point2 = TelemetryPoint(
            timestamp: time2,
            coordinate: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195),
            elevation: 110.0
        )

        let track = TelemetryTrack(points: [point1, point2])
        let processedTrack = TelemetryCalculator.process(track: track, smoothing: false)

        let processedPoint2 = processedTrack.points[1]
        XCTAssertNotNil(processedPoint2.speed)
        XCTAssertGreaterThan(processedPoint2.speed!, 0.0)
    }

    func testDeriveVerticalSpeed() {
        let formatter = ISO8601DateFormatter()
        let time1 = formatter.date(from: "2024-01-01T12:00:00Z")!
        let time2 = formatter.date(from: "2024-01-01T12:00:10Z")!

        let point1 = TelemetryPoint(
            timestamp: time1,
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            elevation: 100.0
        )

        let point2 = TelemetryPoint(
            timestamp: time2,
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            elevation: 110.0
        )

        let track = TelemetryTrack(points: [point1, point2])
        let processedTrack = TelemetryCalculator.process(track: track, smoothing: false)

        let processedPoint2 = processedTrack.points[1]
        XCTAssertNotNil(processedPoint2.verticalSpeed)
        XCTAssertEqual(processedPoint2.verticalSpeed!, 1.0, accuracy: 0.01) // 10m in 10s = 1 m/s
    }

    // MARK: - G-Force Calculation Tests

    func testDeriveGForce() {
        let formatter = ISO8601DateFormatter()
        let time1 = formatter.date(from: "2024-01-01T12:00:00Z")!
        let time2 = formatter.date(from: "2024-01-01T12:00:01Z")!
        let time3 = formatter.date(from: "2024-01-01T12:00:02Z")!

        let point1 = TelemetryPoint(
            timestamp: time1,
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            speed: 10.0
        )

        let point2 = TelemetryPoint(
            timestamp: time2,
            coordinate: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195),
            speed: 15.0
        )

        let point3 = TelemetryPoint(
            timestamp: time3,
            coordinate: CLLocationCoordinate2D(latitude: 37.7751, longitude: -122.4196),
            speed: 20.0
        )

        let track = TelemetryTrack(points: [point1, point2, point3])
        let processedTrack = TelemetryCalculator.process(track: track, smoothing: false)

        let processedPoint2 = processedTrack.points[1]
        XCTAssertNotNil(processedPoint2.gForce)
        XCTAssertGreaterThan(processedPoint2.gForce!, 1.0) // Should be > 1G due to acceleration
    }

    // MARK: - Track Statistics Tests

    func testTrackElevationGain() {
        let formatter = ISO8601DateFormatter()
        let time1 = formatter.date(from: "2024-01-01T12:00:00Z")!
        let time2 = formatter.date(from: "2024-01-01T12:00:10Z")!
        let time3 = formatter.date(from: "2024-01-01T12:00:20Z")!

        let point1 = TelemetryPoint(
            timestamp: time1,
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            elevation: 100.0
        )

        let point2 = TelemetryPoint(
            timestamp: time2,
            coordinate: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195),
            elevation: 120.0
        )

        let point3 = TelemetryPoint(
            timestamp: time3,
            coordinate: CLLocationCoordinate2D(latitude: 37.7751, longitude: -122.4196),
            elevation: 110.0
        )

        let track = TelemetryTrack(points: [point1, point2, point3])

        XCTAssertEqual(track.elevationGain, 20.0, accuracy: 0.1)
        XCTAssertEqual(track.elevationLoss, 10.0, accuracy: 0.1)
    }

    func testTrackMaxSpeed() {
        let formatter = ISO8601DateFormatter()
        let time1 = formatter.date(from: "2024-01-01T12:00:00Z")!
        let time2 = formatter.date(from: "2024-01-01T12:00:10Z")!

        let point1 = TelemetryPoint(
            timestamp: time1,
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            speed: 10.0
        )

        let point2 = TelemetryPoint(
            timestamp: time2,
            coordinate: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195),
            speed: 25.0
        )

        let track = TelemetryTrack(points: [point1, point2])

        XCTAssertEqual(track.maxSpeed, 25.0)
        XCTAssertEqual(track.averageSpeed, 17.5)
    }

    // MARK: - Point Lookup Tests

    func testPointAtTimestamp() {
        let formatter = ISO8601DateFormatter()
        let time1 = formatter.date(from: "2024-01-01T12:00:00Z")!
        let time2 = formatter.date(from: "2024-01-01T12:00:10Z")!
        let time3 = formatter.date(from: "2024-01-01T12:00:20Z")!

        let point1 = TelemetryPoint(
            timestamp: time1,
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        )

        let point2 = TelemetryPoint(
            timestamp: time2,
            coordinate: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195)
        )

        let point3 = TelemetryPoint(
            timestamp: time3,
            coordinate: CLLocationCoordinate2D(latitude: 37.7751, longitude: -122.4196)
        )

        let track = TelemetryTrack(points: [point1, point2, point3])

        // Test exact timestamp match
        let foundPoint = track.point(at: time2)
        XCTAssertNotNil(foundPoint)
        XCTAssertEqual(foundPoint?.timestamp, time2)

        // Test closest point
        let midTime = time1.addingTimeInterval(5)
        let closestPoint = track.point(at: midTime)
        XCTAssertNotNil(closestPoint)
    }
}
