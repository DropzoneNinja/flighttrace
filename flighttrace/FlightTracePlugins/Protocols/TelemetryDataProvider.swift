// TelemetryDataProvider.swift
// Interface for plugins to query telemetry data without accessing core internals

import Foundation
import CoreLocation
import FlightTraceCore

/// Protocol that provides telemetry data to instrument plugins
///
/// This protocol isolates plugins from the core timeline engine and data management.
/// Plugins receive only the data they need through this clean interface.
public protocol TelemetryDataProvider: Sendable {

    // MARK: - Current Data Access

    /// Get the telemetry point at the current timeline position
    ///
    /// This returns interpolated data if the current position is between GPS samples
    /// - Returns: The current telemetry point, or nil if no data is available
    func currentPoint() -> TelemetryPoint?

    /// Get telemetry data at a specific timestamp
    /// - Parameter timestamp: The target timestamp
    /// - Returns: The telemetry point at that time, or nil if unavailable
    func point(at timestamp: Date) -> TelemetryPoint?

    // MARK: - Historical Data Access

    /// Get telemetry points within a time range
    ///
    /// Useful for plugins that need to render historical data (e.g., breadcrumb trails)
    /// - Parameters:
    ///   - startTime: The start of the time range
    ///   - endTime: The end of the time range
    /// - Returns: Array of telemetry points within the range
    func points(from startTime: Date, to endTime: Date) -> [TelemetryPoint]

    /// Get the last N telemetry points from the current position
    ///
    /// Useful for trail effects or moving averages
    /// - Parameter count: Number of historical points to retrieve
    /// - Returns: Array of the last N points (may be fewer if not enough data exists)
    func lastPoints(_ count: Int) -> [TelemetryPoint]

    // MARK: - Track Metadata

    /// Get the entire track (use sparingly - prefer querying specific points)
    ///
    /// Note: Plugins should avoid accessing the full track for performance reasons.
    /// Use this only when absolutely necessary (e.g., minimap rendering)
    func track() -> TelemetryTrack?

    /// Get track statistics
    func trackStatistics() -> TrackStatistics?
}

// MARK: - Track Statistics

/// Aggregated statistics for the entire track
public struct TrackStatistics: Sendable {
    /// Total duration of the track
    public let duration: TimeInterval?

    /// Total distance traveled in meters
    public let totalDistance: Double

    /// Maximum speed in meters per second
    public let maxSpeed: Double?

    /// Average speed in meters per second
    public let averageSpeed: Double?

    /// Maximum elevation in meters
    public let maxElevation: Double?

    /// Minimum elevation in meters
    public let minElevation: Double?

    /// Total elevation gain in meters
    public let elevationGain: Double

    /// Total elevation loss in meters
    public let elevationLoss: Double

    /// Bounding box of the track
    public let boundingBox: (min: CLLocationCoordinate2D, max: CLLocationCoordinate2D)?

    public init(
        duration: TimeInterval?,
        totalDistance: Double,
        maxSpeed: Double?,
        averageSpeed: Double?,
        maxElevation: Double?,
        minElevation: Double?,
        elevationGain: Double,
        elevationLoss: Double,
        boundingBox: (min: CLLocationCoordinate2D, max: CLLocationCoordinate2D)?
    ) {
        self.duration = duration
        self.totalDistance = totalDistance
        self.maxSpeed = maxSpeed
        self.averageSpeed = averageSpeed
        self.maxElevation = maxElevation
        self.minElevation = minElevation
        self.elevationGain = elevationGain
        self.elevationLoss = elevationLoss
        self.boundingBox = boundingBox
    }

    /// Create statistics from a TelemetryTrack
    public init(from track: TelemetryTrack) {
        self.duration = track.duration
        self.totalDistance = track.totalDistance
        self.maxSpeed = track.maxSpeed
        self.averageSpeed = track.averageSpeed
        self.maxElevation = track.maxElevation
        self.minElevation = track.minElevation
        self.elevationGain = track.elevationGain
        self.elevationLoss = track.elevationLoss
        self.boundingBox = track.boundingBox
    }
}
