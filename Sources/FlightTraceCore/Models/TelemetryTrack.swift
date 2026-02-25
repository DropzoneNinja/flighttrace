// TelemetryTrack.swift
// Represents an entire GPS track with multiple telemetry points

import Foundation
import CoreLocation

/// Represents a complete GPS track/session with metadata and telemetry points
public struct TelemetryTrack: Sendable, Equatable, Identifiable {
    public let id: UUID

    // MARK: - Metadata

    /// Name of the track (from GPX <name> element)
    public let name: String?

    /// Description of the track (from GPX <desc> element)
    public let description: String?

    /// Track type (e.g., "running", "cycling", "flying")
    public let type: String?

    /// Source device or application that created the track
    public let source: String?

    // MARK: - Telemetry Data

    /// Array of telemetry points in chronological order
    public let points: [TelemetryPoint]

    // MARK: - Computed Properties

    /// Start time of the track
    public var startTime: Date? {
        points.first?.timestamp
    }

    /// End time of the track
    public var endTime: Date? {
        points.last?.timestamp
    }

    /// Total duration of the track in seconds
    public var duration: TimeInterval? {
        guard let start = startTime, let end = endTime else { return nil }
        return end.timeIntervalSince(start)
    }

    /// Total distance traveled in meters
    public var totalDistance: Double {
        points.compactMap { $0.distanceFromPrevious }.reduce(0, +)
    }

    /// Maximum speed recorded in meters per second
    public var maxSpeed: Double? {
        points.compactMap { $0.speed }.max()
    }

    /// Average speed in meters per second
    public var averageSpeed: Double? {
        let speeds = points.compactMap { $0.speed }
        guard !speeds.isEmpty else { return nil }
        return speeds.reduce(0, +) / Double(speeds.count)
    }

    /// Maximum elevation in meters
    public var maxElevation: Double? {
        points.compactMap { $0.elevation }.max()
    }

    /// Minimum elevation in meters
    public var minElevation: Double? {
        points.compactMap { $0.elevation }.min()
    }

    /// Total elevation gain in meters
    public var elevationGain: Double {
        var gain: Double = 0
        for i in 1..<points.count {
            if let prevElevation = points[i - 1].elevation,
               let currentElevation = points[i].elevation {
                let delta = currentElevation - prevElevation
                if delta > 0 {
                    gain += delta
                }
            }
        }
        return gain
    }

    /// Total elevation loss in meters
    public var elevationLoss: Double {
        var loss: Double = 0
        for i in 1..<points.count {
            if let prevElevation = points[i - 1].elevation,
               let currentElevation = points[i].elevation {
                let delta = currentElevation - prevElevation
                if delta < 0 {
                    loss += abs(delta)
                }
            }
        }
        return loss
    }

    /// Bounding box containing all points
    public var boundingBox: (min: CLLocationCoordinate2D, max: CLLocationCoordinate2D)? {
        guard !points.isEmpty else { return nil }

        var minLat = Double.infinity
        var maxLat = -Double.infinity
        var minLon = Double.infinity
        var maxLon = -Double.infinity

        for point in points {
            minLat = min(minLat, point.coordinate.latitude)
            maxLat = max(maxLat, point.coordinate.latitude)
            minLon = min(minLon, point.coordinate.longitude)
            maxLon = max(maxLon, point.coordinate.longitude)
        }

        return (
            min: CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
            max: CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon)
        )
    }

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        name: String? = nil,
        description: String? = nil,
        type: String? = nil,
        source: String? = nil,
        points: [TelemetryPoint]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.source = source
        self.points = points
    }

    // MARK: - Subscript Access

    /// Access telemetry point at a specific index
    public subscript(index: Int) -> TelemetryPoint {
        points[index]
    }

    /// Get telemetry point at or near a specific timestamp using interpolation
    /// - Parameter timestamp: The target timestamp
    /// - Returns: The closest telemetry point, or nil if track is empty
    public func point(at timestamp: Date) -> TelemetryPoint? {
        guard !points.isEmpty else { return nil }

        // If before track start, return first point
        if let start = startTime, timestamp <= start {
            return points.first
        }

        // If after track end, return last point
        if let end = endTime, timestamp >= end {
            return points.last
        }

        // Binary search for closest point
        var left = 0
        var right = points.count - 1

        while left <= right {
            let mid = (left + right) / 2
            let midTime = points[mid].timestamp

            if midTime == timestamp {
                return points[mid]
            } else if midTime < timestamp {
                left = mid + 1
            } else {
                right = mid - 1
            }
        }

        // Return closest point
        if left >= points.count {
            return points.last
        }
        if right < 0 {
            return points.first
        }

        let leftDiff = abs(points[left].timestamp.timeIntervalSince(timestamp))
        let rightDiff = abs(points[right].timestamp.timeIntervalSince(timestamp))

        return leftDiff < rightDiff ? points[left] : points[right]
    }

    // MARK: - Equatable

    public static func == (lhs: TelemetryTrack, rhs: TelemetryTrack) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.points == rhs.points
    }
}
