// TimelinePosition.swift
// Represents the current playhead position in the timeline

import Foundation

/// Represents the current position in the timeline
///
/// The timeline position tracks both video time and corresponding GPX timestamp,
/// accounting for manual offset adjustments.
public struct TimelinePosition: Sendable, Equatable {

    // MARK: - Time Properties

    /// The current video time (time elapsed from video start)
    public let videoTime: TimeInterval

    /// The corresponding GPX timestamp (after applying offset)
    public let gpxTimestamp: Date

    /// Whether this position is within the valid GPX data range
    public let isWithinTrack: Bool

    // MARK: - Position Metadata

    /// The normalized position in the timeline (0.0 = start, 1.0 = end)
    public let normalizedPosition: Double

    /// Frame number (for export rendering)
    public let frameNumber: Int?

    // MARK: - Initialization

    public init(
        videoTime: TimeInterval,
        gpxTimestamp: Date,
        isWithinTrack: Bool = true,
        normalizedPosition: Double = 0.0,
        frameNumber: Int? = nil
    ) {
        self.videoTime = videoTime
        self.gpxTimestamp = gpxTimestamp
        self.isWithinTrack = isWithinTrack
        self.normalizedPosition = normalizedPosition
        self.frameNumber = frameNumber
    }

    // MARK: - Computed Properties

    /// Whether the position is at the beginning of the timeline
    public var isAtStart: Bool {
        videoTime <= 0.0
    }

    /// Whether the position is at the end of the timeline
    public var isAtEnd: Bool {
        normalizedPosition >= 1.0
    }

    // MARK: - Position Adjustment

    /// Create a new position by adding a time offset
    /// - Parameter offset: Time offset in seconds
    /// - Returns: New position with adjusted times
    public func offset(by offset: TimeInterval) -> TimelinePosition {
        TimelinePosition(
            videoTime: videoTime + offset,
            gpxTimestamp: gpxTimestamp.addingTimeInterval(offset),
            isWithinTrack: isWithinTrack,
            normalizedPosition: normalizedPosition,
            frameNumber: frameNumber
        )
    }
}

// MARK: - Convenience Constructors

public extension TimelinePosition {
    /// Create a position at the start of the timeline
    static func start(gpxStart: Date) -> TimelinePosition {
        TimelinePosition(
            videoTime: 0.0,
            gpxTimestamp: gpxStart,
            isWithinTrack: true,
            normalizedPosition: 0.0
        )
    }

    /// Create a position at a specific time with normalized position
    static func at(
        videoTime: TimeInterval,
        gpxTimestamp: Date,
        normalizedPosition: Double,
        isWithinTrack: Bool = true
    ) -> TimelinePosition {
        TimelinePosition(
            videoTime: videoTime,
            gpxTimestamp: gpxTimestamp,
            isWithinTrack: isWithinTrack,
            normalizedPosition: normalizedPosition
        )
    }
}
