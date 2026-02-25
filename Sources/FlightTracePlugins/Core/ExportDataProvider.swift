// ExportDataProvider.swift
// Thread-safe data provider for export rendering

import Foundation
import CoreLocation
@preconcurrency import FlightTraceCore

/// Thread-safe telemetry data provider for export rendering
///
/// Unlike `TimelineDataProvider`, this provider doesn't rely on main-actor-isolated
/// `TimelineEngine` and can safely be called from background rendering threads.
///
/// ## Usage
/// ```swift
/// @MainActor
/// let provider = ExportDataProvider(
///     track: timelineEngine.track,
///     timeOffset: timelineEngine.timeOffset
/// )
///
/// // Can now be used from background thread during export
/// Task.detached {
///     let point = provider.point(at: timestamp)
/// }
/// ```
public final class ExportDataProvider: TelemetryDataProvider, Sendable {

    // MARK: - Properties

    /// The telemetry track (immutable snapshot)
    private let telemetryTrack: TelemetryTrack?

    /// Time offset between video and GPX
    private let timeOffset: TimeInterval

    /// Current timestamp for "current point" queries
    private let currentTimestamp: SendableBox<Date>

    // MARK: - Initialization

    /// Create an export data provider
    /// - Parameters:
    ///   - track: The telemetry track to export
    ///   - timeOffset: Time offset between video and GPX
    ///   - startTime: Initial timestamp for current point queries
    @MainActor
    public init(
        track: TelemetryTrack?,
        timeOffset: TimeInterval = 0.0,
        startTime: Date? = nil
    ) {
        self.telemetryTrack = track
        self.timeOffset = timeOffset
        self.currentTimestamp = SendableBox(startTime ?? track?.startTime ?? Date())

        // Debug logging
        if let track = track {
            print("ExportDataProvider: Initialized with track containing \(track.points.count) points")
            if let firstPoint = track.points.first {
                print("ExportDataProvider: First point has elevation: \(firstPoint.elevation != nil)")
            }
        } else {
            print("ExportDataProvider: Initialized with nil track")
        }
    }

    // MARK: - Current Time Management

    /// Update the current timestamp (called by export engine for each frame)
    public func setCurrentTimestamp(_ timestamp: Date) {
        currentTimestamp.value = timestamp
    }

    // MARK: - TelemetryDataProvider Conformance

    /// Get the telemetry point at the current timestamp
    public func currentPoint() -> TelemetryPoint? {
        let timestamp = currentTimestamp.value
        let result = point(at: timestamp)
        return result
    }

    /// Get telemetry data at a specific timestamp
    public func point(at timestamp: Date) -> TelemetryPoint? {
        guard let track = telemetryTrack else { return nil }
        return interpolatedPoint(at: timestamp, in: track)
    }

    /// Get telemetry points within a time range
    public func points(from startTime: Date, to endTime: Date) -> [TelemetryPoint] {
        guard let track = telemetryTrack else { return [] }

        return track.points.filter { point in
            point.timestamp >= startTime && point.timestamp <= endTime
        }
    }

    /// Get the last N telemetry points from the current timestamp
    public func lastPoints(_ count: Int) -> [TelemetryPoint] {
        guard let track = telemetryTrack, count > 0 else { return [] }

        let timestamp = currentTimestamp.value

        // Find points before current timestamp
        let beforeCurrent = track.points.filter { $0.timestamp <= timestamp }

        // Return the last N points
        return Array(beforeCurrent.suffix(count))
    }

    /// Get the entire track
    public func track() -> TelemetryTrack? {
        telemetryTrack
    }

    /// Get track statistics
    public func trackStatistics() -> TrackStatistics? {
        guard let track = telemetryTrack else { return nil }
        return TrackStatistics(from: track)
    }

    // MARK: - Interpolation

    /// Get interpolated telemetry point at a specific timestamp
    private func interpolatedPoint(at timestamp: Date, in track: TelemetryTrack) -> TelemetryPoint? {
        guard !track.points.isEmpty else { return nil }

        // If before track start, return first point
        if let start = track.startTime, timestamp <= start {
            return track.points.first
        }

        // If after track end, return last point
        if let end = track.endTime, timestamp >= end {
            return track.points.last
        }

        // Find surrounding points using binary search
        let (before, after) = findSurroundingPoints(for: timestamp, in: track.points)

        guard let beforePoint = before else {
            return after ?? track.points.first
        }

        guard let afterPoint = after else {
            return beforePoint
        }

        // If timestamps match exactly, return the point
        if beforePoint.timestamp == timestamp {
            return beforePoint
        }
        if afterPoint.timestamp == timestamp {
            return afterPoint
        }

        // Interpolate between the two points
        return interpolate(from: beforePoint, to: afterPoint, at: timestamp)
    }

    /// Find points immediately before and after a timestamp
    private func findSurroundingPoints(
        for timestamp: Date,
        in points: [TelemetryPoint]
    ) -> (before: TelemetryPoint?, after: TelemetryPoint?) {
        var left = 0
        var right = points.count - 1

        while left <= right {
            let mid = (left + right) / 2
            let midTime = points[mid].timestamp

            if midTime == timestamp {
                return (points[mid], points[mid])
            } else if midTime < timestamp {
                left = mid + 1
            } else {
                right = mid - 1
            }
        }

        // After binary search:
        // - right is the index before the target
        // - left is the index after the target

        let before = right >= 0 && right < points.count ? points[right] : nil
        let after = left >= 0 && left < points.count ? points[left] : nil

        return (before, after)
    }

    /// Interpolate telemetry data between two points
    private func interpolate(
        from start: TelemetryPoint,
        to end: TelemetryPoint,
        at timestamp: Date
    ) -> TelemetryPoint {
        let totalInterval = end.timestamp.timeIntervalSince(start.timestamp)
        guard totalInterval > 0 else { return start }

        let elapsed = timestamp.timeIntervalSince(start.timestamp)
        let ratio = elapsed / totalInterval

        // Interpolate coordinate
        let lat = start.coordinate.latitude + (end.coordinate.latitude - start.coordinate.latitude) * ratio
        let lon = start.coordinate.longitude + (end.coordinate.longitude - start.coordinate.longitude) * ratio
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)

        // Interpolate elevation
        let elevation: Double?
        if let startElev = start.elevation, let endElev = end.elevation {
            elevation = startElev + (endElev - startElev) * ratio
        } else {
            elevation = start.elevation ?? end.elevation
        }

        // Interpolate speed
        let speed: Double?
        if let startSpeed = start.speed, let endSpeed = end.speed {
            speed = startSpeed + (endSpeed - startSpeed) * ratio
        } else {
            speed = start.speed ?? end.speed
        }

        // Interpolate vertical speed
        let verticalSpeed: Double?
        if let startVS = start.verticalSpeed, let endVS = end.verticalSpeed {
            verticalSpeed = startVS + (endVS - startVS) * ratio
        } else {
            verticalSpeed = start.verticalSpeed ?? end.verticalSpeed
        }

        // Interpolate heading
        let heading: Double?
        if let startHeading = start.heading, let endHeading = end.heading {
            heading = interpolateHeading(from: startHeading, to: endHeading, ratio: ratio)
        } else {
            heading = start.heading ?? end.heading
        }

        // Interpolate G-force
        let gForce: Double?
        if let startG = start.gForce, let endG = end.gForce {
            gForce = startG + (endG - startG) * ratio
        } else {
            gForce = start.gForce ?? end.gForce
        }

        return TelemetryPoint(
            timestamp: timestamp,
            coordinate: coordinate,
            elevation: elevation,
            speed: speed,
            verticalSpeed: verticalSpeed,
            heading: heading,
            horizontalAccuracy: start.horizontalAccuracy,
            verticalAccuracy: start.verticalAccuracy,
            gForce: gForce
        )
    }

    /// Interpolate heading values accounting for 360° wrap-around
    private func interpolateHeading(from start: Double, to end: Double, ratio: Double) -> Double {
        var delta = end - start

        // Handle wrap-around (e.g., 350° to 10° should go via 360°, not backwards)
        if delta > 180 {
            delta -= 360
        } else if delta < -180 {
            delta += 360
        }

        var result = start + delta * ratio

        // Normalize to 0-360 range
        if result < 0 {
            result += 360
        } else if result >= 360 {
            result -= 360
        }

        return result
    }
}

// MARK: - Sendable Box

/// Thread-safe box for mutable value
private final class SendableBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T

    var value: T {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _value = newValue
        }
    }

    init(_ value: T) {
        self._value = value
    }
}
