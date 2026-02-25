// TimelineDataProvider.swift
// Adapter that makes TimelineEngine conform to TelemetryDataProvider

import Foundation
@preconcurrency import FlightTraceCore

/// Adapter that wraps TimelineEngine to provide the TelemetryDataProvider interface
///
/// This class bridges the core timeline engine with the plugin system, allowing plugins
/// to access telemetry data through the standardized TelemetryDataProvider protocol.
///
/// ## Usage
/// ```swift
/// let timelineEngine = TimelineEngine(track: gpxTrack)
/// let dataProvider = await TimelineDataProvider(engine: timelineEngine)
///
/// // Plugins can now use the provider
/// let currentPoint = dataProvider.currentPoint()
/// ```
public final class TimelineDataProvider: TelemetryDataProvider, Sendable {

    // MARK: - Properties

    /// The underlying timeline engine (stored as weak reference to avoid retain cycles)
    private let getEngine: @Sendable @MainActor () -> TimelineEngine?

    // MARK: - Initialization

    /// Create a new data provider wrapping a timeline engine
    /// - Parameter engine: The timeline engine to wrap
    @MainActor
    public init(engine: TimelineEngine) {
        // Capture engine weakly to allow proper lifecycle management
        weak var weakEngine = engine
        self.getEngine = { weakEngine }
    }

    // MARK: - TelemetryDataProvider Conformance

    /// Get the telemetry point at the current timeline position
    public func currentPoint() -> TelemetryPoint? {
        MainActor.assumeIsolated {
            getEngine()?.currentPoint()
        }
    }

    /// Get telemetry data at a specific timestamp
    /// - Parameter timestamp: The target timestamp
    /// - Returns: The telemetry point at that time, or nil if unavailable
    public func point(at timestamp: Date) -> TelemetryPoint? {
        MainActor.assumeIsolated {
            getEngine()?.point(at: timestamp)
        }
    }

    /// Get telemetry points within a time range
    /// - Parameters:
    ///   - startTime: The start of the time range
    ///   - endTime: The end of the time range
    /// - Returns: Array of telemetry points within the range
    public func points(from startTime: Date, to endTime: Date) -> [TelemetryPoint] {
        MainActor.assumeIsolated {
            getEngine()?.points(from: startTime, to: endTime) ?? []
        }
    }

    /// Get the last N telemetry points from the current position
    /// - Parameter count: Number of historical points to retrieve
    /// - Returns: Array of the last N points (may be fewer if not enough data exists)
    public func lastPoints(_ count: Int) -> [TelemetryPoint] {
        MainActor.assumeIsolated {
            getEngine()?.lastPoints(count) ?? []
        }
    }

    /// Get the entire track
    /// - Returns: The full telemetry track, or nil if no track loaded
    public func track() -> TelemetryTrack? {
        MainActor.assumeIsolated {
            getEngine()?.track
        }
    }

    /// Get track statistics
    /// - Returns: Aggregated statistics for the track, or nil if no track loaded
    public func trackStatistics() -> TrackStatistics? {
        MainActor.assumeIsolated {
            guard let track = getEngine()?.track else { return nil }
            return TrackStatistics(from: track)
        }
    }
}

// MARK: - TimelineEngine Extension

/// Extension to conveniently create a TelemetryDataProvider from a TimelineEngine
public extension TimelineEngine {
    /// Create a TelemetryDataProvider that wraps this timeline engine
    /// - Returns: A data provider for plugin use
    @MainActor
    func asDataProvider() -> TelemetryDataProvider {
        TimelineDataProvider(engine: self)
    }
}
