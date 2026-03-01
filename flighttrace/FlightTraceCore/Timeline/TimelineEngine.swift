// TimelineEngine.swift
// Manages timeline state and synchronizes GPX data with video playback

import Foundation
import CoreLocation
import Combine

/// Engine that manages timeline state and synchronizes telemetry data with video playback
///
/// The TimelineEngine is responsible for:
/// - Managing current playhead position
/// - Applying manual time offset between video and GPX start
/// - Handling trim/clip start and end times
/// - Interpolating telemetry data between GPS samples
/// - Providing synchronized data access for plugins
///
/// ## Usage
/// ```swift
/// let engine = TimelineEngine(track: gpxTrack)
/// engine.setOffset(5.0)  // GPX starts 5 seconds into video
/// engine.seek(to: 30.0)  // Seek to 30 seconds in video
///
/// let currentPoint = engine.currentPoint()
/// let interpolated = engine.pointAt(videoTime: 45.5)
/// ```
@MainActor
public final class TimelineEngine: ObservableObject {

    // MARK: - Published State

    /// Current timeline position
    @Published public private(set) var currentPosition: TimelinePosition

    /// The telemetry track being played
    @Published public private(set) var track: TelemetryTrack?

    /// Manual time offset (in seconds) between video start and GPX start
    ///
    /// Positive value: GPX starts after video begins
    /// Negative value: GPX starts before video begins
    @Published public var timeOffset: TimeInterval = 0.0 {
        didSet {
            updateCurrentPosition()
        }
    }

    /// Trim start time (video time, not GPX time)
    @Published public var trimStart: TimeInterval = 0.0 {
        didSet {
            if currentVideoTime < trimStart {
                seek(to: trimStart)
            }
        }
    }

    /// Trim end time (video time, not GPX time)
    @Published public var trimEnd: TimeInterval? {
        didSet {
            if let end = trimEnd, currentVideoTime > end {
                seek(to: end)
            }
        }
    }

    // MARK: - Private State

    /// Current video time (independent of GPX)
    private var currentVideoTime: TimeInterval = 0.0

    /// Cache for interpolated points to avoid recomputation
    private var interpolationCache: [TimeInterval: TelemetryPoint] = [:]

    // MARK: - Computed Properties

    /// Total duration of the track (in seconds)
    public var duration: TimeInterval {
        track?.duration ?? 0.0
    }

    /// Effective duration considering trim points
    public var effectiveDuration: TimeInterval {
        let end = trimEnd ?? duration
        return max(0, end - trimStart)
    }

    /// Whether the timeline is currently within valid GPX data
    public var isWithinTrack: Bool {
        currentPosition.isWithinTrack
    }

    // MARK: - Initialization

    public init(track: TelemetryTrack? = nil, timeOffset: TimeInterval = 0.0) {
        self.track = track
        self.timeOffset = timeOffset
        self.currentPosition = .start(gpxStart: track?.startTime ?? Date())
        updateCurrentPosition()
    }

    // MARK: - Track Management

    /// Load a new telemetry track
    /// - Parameter track: The track to load
    public func loadTrack(_ track: TelemetryTrack) {
        self.track = track
        self.interpolationCache.removeAll()
        seek(to: 0.0)
    }

    /// Clear the current track
    public func clearTrack() {
        self.track = nil
        self.interpolationCache.removeAll()
        seek(to: 0.0)
    }

    // MARK: - Playhead Control

    /// Seek to a specific video time
    /// - Parameter videoTime: Time in seconds from video start
    public func seek(to videoTime: TimeInterval) {
        currentVideoTime = max(trimStart, min(videoTime, trimEnd ?? .infinity))
        updateCurrentPosition()
    }

    /// Advance the playhead by a time delta
    /// - Parameter delta: Time delta in seconds
    public func advance(by delta: TimeInterval) {
        seek(to: currentVideoTime + delta)
    }

    /// Move to the next frame (useful for frame-by-frame navigation)
    /// - Parameter frameRate: Frames per second
    public func nextFrame(frameRate: Double = 30.0) {
        advance(by: 1.0 / frameRate)
    }

    /// Move to the previous frame
    /// - Parameter frameRate: Frames per second
    public func previousFrame(frameRate: Double = 30.0) {
        advance(by: -1.0 / frameRate)
    }

    /// Jump to the beginning
    public func jumpToStart() {
        seek(to: trimStart)
    }

    /// Jump to the end
    public func jumpToEnd() {
        seek(to: trimEnd ?? duration)
    }

    // MARK: - Data Access

    /// Get the telemetry point at the current timeline position
    /// - Returns: Interpolated telemetry point, or nil if no track loaded
    public func currentPoint() -> TelemetryPoint? {
        pointAt(videoTime: currentVideoTime)
    }

    /// Get telemetry point at a specific video time
    /// - Parameter videoTime: Time in seconds from video start
    /// - Returns: Interpolated telemetry point, or nil if unavailable
    public func pointAt(videoTime: TimeInterval) -> TelemetryPoint? {
        guard let track = track else { return nil }

        // Check cache first
        if let cached = interpolationCache[videoTime] {
            return cached
        }

        // Convert video time to GPX timestamp
        let gpxTimestamp = videoTimeToGPXTimestamp(videoTime)

        // Get point from track (with interpolation)
        let point = interpolatedPoint(at: gpxTimestamp, in: track)

        // Cache the result
        if let point = point {
            interpolationCache[videoTime] = point
        }

        return point
    }

    /// Get telemetry point at a specific GPX timestamp
    /// - Parameter timestamp: GPX timestamp
    /// - Returns: Interpolated telemetry point, or nil if unavailable
    public func point(at timestamp: Date) -> TelemetryPoint? {
        guard let track = track else { return nil }
        return interpolatedPoint(at: timestamp, in: track)
    }

    /// Get telemetry points within a time range
    /// - Parameters:
    ///   - startTime: Start GPX timestamp
    ///   - endTime: End GPX timestamp
    /// - Returns: Array of telemetry points in range
    public func points(from startTime: Date, to endTime: Date) -> [TelemetryPoint] {
        guard let track = track else { return [] }

        return track.points.filter { point in
            point.timestamp >= startTime && point.timestamp <= endTime
        }
    }

    /// Get the last N telemetry points from current position
    /// - Parameter count: Number of points to retrieve
    /// - Returns: Array of the last N points
    public func lastPoints(_ count: Int) -> [TelemetryPoint] {
        guard let track = track, count > 0 else { return [] }

        let currentTimestamp = currentPosition.gpxTimestamp

        // Find points before current position
        let beforeCurrent = track.points.filter { $0.timestamp <= currentTimestamp }

        // Return the last N points
        return Array(beforeCurrent.suffix(count))
    }

    // MARK: - Time Conversion

    /// Convert video time to GPX timestamp
    /// - Parameter videoTime: Time in seconds from video start
    /// - Returns: Corresponding GPX timestamp
    public func videoTimeToGPXTimestamp(_ videoTime: TimeInterval) -> Date {
        guard let gpxStart = track?.startTime else {
            return Date()
        }

        // Apply offset: positive offset means GPX starts after video begins
        let adjustedTime = videoTime - timeOffset
        return gpxStart.addingTimeInterval(adjustedTime)
    }

    /// Convert GPX timestamp to video time
    /// - Parameter timestamp: GPX timestamp
    /// - Returns: Corresponding video time in seconds
    public func gpxTimestampToVideoTime(_ timestamp: Date) -> TimeInterval {
        guard let gpxStart = track?.startTime else {
            return 0.0
        }

        let gpxElapsed = timestamp.timeIntervalSince(gpxStart)
        return gpxElapsed + timeOffset
    }

    // MARK: - Private Methods

    /// Update the current position based on current video time
    private func updateCurrentPosition() {
        guard track != nil else {
            currentPosition = .start(gpxStart: Date())
            return
        }

        let gpxTimestamp = videoTimeToGPXTimestamp(currentVideoTime)
        let isWithin = isTimestampWithinTrack(gpxTimestamp)
        let normalized = effectiveDuration > 0 ? currentVideoTime / effectiveDuration : 0.0

        currentPosition = TimelinePosition(
            videoTime: currentVideoTime,
            gpxTimestamp: gpxTimestamp,
            isWithinTrack: isWithin,
            normalizedPosition: min(1.0, max(0.0, normalized))
        )
    }

    /// Check if a timestamp is within the track's time range
    private func isTimestampWithinTrack(_ timestamp: Date) -> Bool {
        guard let track = track,
              let startTime = track.startTime,
              let endTime = track.endTime else {
            return false
        }

        return timestamp >= startTime && timestamp <= endTime
    }

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

    // MARK: - Cache Management

    /// Clear the interpolation cache
    ///
    /// Call this when offset or trim values change to ensure fresh interpolation
    public func clearCache() {
        interpolationCache.removeAll()
    }
}
