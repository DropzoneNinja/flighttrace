// TelemetryPoint.swift
// Represents a single GPS data point with telemetry information

import Foundation
import CoreLocation

/// A single telemetry data point representing GPS position and derived metrics at a specific time
public struct TelemetryPoint: Sendable, Equatable, Identifiable {
    public let id: UUID

    // MARK: - Core GPS Data

    /// Timestamp of the GPS reading
    public let timestamp: Date

    /// Coordinate (latitude and longitude)
    public let coordinate: CLLocationCoordinate2D

    /// Elevation above sea level in meters (may be nil if not available)
    public let elevation: Double?

    // MARK: - Derived Metrics

    /// Speed in meters per second (derived from position deltas if not present in GPX)
    public let speed: Double?

    /// Vertical speed in meters per second (derived from elevation changes)
    public let verticalSpeed: Double?

    /// Heading/course in degrees (0-360, where 0 is true north)
    public let heading: Double?

    /// Horizontal dilution of precision (accuracy indicator)
    public let horizontalAccuracy: Double?

    /// Vertical dilution of precision (accuracy indicator)
    public let verticalAccuracy: Double?

    // MARK: - Advanced Metrics

    /// G-force (derived from acceleration)
    public let gForce: Double?

    /// Distance traveled from previous point in meters
    public let distanceFromPrevious: Double?

    /// Time delta from previous point in seconds
    public let timeDeltaFromPrevious: TimeInterval?

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        coordinate: CLLocationCoordinate2D,
        elevation: Double? = nil,
        speed: Double? = nil,
        verticalSpeed: Double? = nil,
        heading: Double? = nil,
        horizontalAccuracy: Double? = nil,
        verticalAccuracy: Double? = nil,
        gForce: Double? = nil,
        distanceFromPrevious: Double? = nil,
        timeDeltaFromPrevious: TimeInterval? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.coordinate = coordinate
        self.elevation = elevation
        self.speed = speed
        self.verticalSpeed = verticalSpeed
        self.heading = heading
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.gForce = gForce
        self.distanceFromPrevious = distanceFromPrevious
        self.timeDeltaFromPrevious = timeDeltaFromPrevious
    }

    // MARK: - Equatable

    public static func == (lhs: TelemetryPoint, rhs: TelemetryPoint) -> Bool {
        lhs.id == rhs.id &&
        lhs.timestamp == rhs.timestamp &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.elevation == rhs.elevation
    }
}

// MARK: - CLLocationCoordinate2D Sendable Conformance
extension CLLocationCoordinate2D: @retroactive @unchecked Sendable {}
