// TelemetryCalculator.swift
// Derives telemetry metrics from raw GPS data

import Foundation
import CoreLocation

/// Calculates derived telemetry metrics from GPS data
public struct TelemetryCalculator {

    // MARK: - Constants

    private static let gravityAcceleration: Double = 9.80665 // m/s²

    // MARK: - Public API

    /// Process a track and derive missing metrics (speed, vertical speed, G-forces, etc.)
    /// - Parameters:
    ///   - track: The telemetry track to process
    ///   - smoothing: Whether to apply smoothing to derived values
    /// - Returns: A new track with derived metrics populated
    public static func process(track: TelemetryTrack, smoothing: Bool = true) -> TelemetryTrack {
        var processedPoints: [TelemetryPoint] = []

        for i in 0..<track.points.count {
            var point = track.points[i]

            // Calculate distance and time delta from previous point
            if i > 0 {
                // Use the already-processed previous point (with derived speed, etc.)
                let previousPoint = processedPoints[i - 1]
                let distance = calculateDistance(from: previousPoint.coordinate, to: point.coordinate)
                let timeDelta = point.timestamp.timeIntervalSince(previousPoint.timestamp)

                // Update point with deltas
                point = TelemetryPoint(
                    id: point.id,
                    timestamp: point.timestamp,
                    coordinate: point.coordinate,
                    elevation: point.elevation,
                    speed: point.speed,
                    verticalSpeed: point.verticalSpeed,
                    heading: point.heading,
                    horizontalAccuracy: point.horizontalAccuracy,
                    verticalAccuracy: point.verticalAccuracy,
                    gForce: point.gForce,
                    distanceFromPrevious: distance,
                    timeDeltaFromPrevious: timeDelta
                )

                // Derive speed if not present
                if point.speed == nil && timeDelta > 0 {
                    let derivedSpeed = distance / timeDelta
                    point = TelemetryPoint(
                        id: point.id,
                        timestamp: point.timestamp,
                        coordinate: point.coordinate,
                        elevation: point.elevation,
                        speed: derivedSpeed,
                        verticalSpeed: point.verticalSpeed,
                        heading: point.heading,
                        horizontalAccuracy: point.horizontalAccuracy,
                        verticalAccuracy: point.verticalAccuracy,
                        gForce: point.gForce,
                        distanceFromPrevious: distance,
                        timeDeltaFromPrevious: timeDelta
                    )
                }

                // Derive vertical speed if elevation is present
                if point.verticalSpeed == nil,
                   let currentElevation = point.elevation,
                   let previousElevation = previousPoint.elevation,
                   timeDelta > 0 {
                    let elevationDelta = currentElevation - previousElevation
                    let derivedVerticalSpeed = elevationDelta / timeDelta
                    point = TelemetryPoint(
                        id: point.id,
                        timestamp: point.timestamp,
                        coordinate: point.coordinate,
                        elevation: point.elevation,
                        speed: point.speed,
                        verticalSpeed: derivedVerticalSpeed,
                        heading: point.heading,
                        horizontalAccuracy: point.horizontalAccuracy,
                        verticalAccuracy: point.verticalAccuracy,
                        gForce: point.gForce,
                        distanceFromPrevious: distance,
                        timeDeltaFromPrevious: timeDelta
                    )
                }

                // Derive heading from movement
                if point.heading == nil {
                    let derivedHeading = calculateBearing(
                        from: previousPoint.coordinate,
                        to: point.coordinate
                    )
                    point = TelemetryPoint(
                        id: point.id,
                        timestamp: point.timestamp,
                        coordinate: point.coordinate,
                        elevation: point.elevation,
                        speed: point.speed,
                        verticalSpeed: point.verticalSpeed,
                        heading: derivedHeading,
                        horizontalAccuracy: point.horizontalAccuracy,
                        verticalAccuracy: point.verticalAccuracy,
                        gForce: point.gForce,
                        distanceFromPrevious: distance,
                        timeDeltaFromPrevious: timeDelta
                    )
                }

                // Derive G-force from acceleration
                if point.gForce == nil,
                   let currentSpeed = point.speed,
                   let previousSpeed = previousPoint.speed,
                   timeDelta > 0 {
                    let speedDelta = currentSpeed - previousSpeed
                    let acceleration = speedDelta / timeDelta
                    let gForce = sqrt(pow(acceleration / gravityAcceleration, 2) + 1) // Total G-force

                    if i < 5 || i == track.points.count - 1 {
                        print("🔍 TelemetryCalculator[point \(i)]: Calculated G-force = \(gForce) (speed: \(previousSpeed) → \(currentSpeed) m/s, accel: \(acceleration) m/s²)")
                    }

                    point = TelemetryPoint(
                        id: point.id,
                        timestamp: point.timestamp,
                        coordinate: point.coordinate,
                        elevation: point.elevation,
                        speed: point.speed,
                        verticalSpeed: point.verticalSpeed,
                        heading: point.heading,
                        horizontalAccuracy: point.horizontalAccuracy,
                        verticalAccuracy: point.verticalAccuracy,
                        gForce: gForce,
                        distanceFromPrevious: distance,
                        timeDeltaFromPrevious: timeDelta
                    )
                } else if point.gForce == nil && i < 5 {
                    print("🔍 TelemetryCalculator[point \(i)]: Could not calculate G-force (currentSpeed=\(point.speed?.description ?? "nil"), previousSpeed=\(previousPoint.speed?.description ?? "nil"), timeDelta=\(timeDelta))")
                }
            }

            processedPoints.append(point)
        }

        // Apply smoothing if requested
        if smoothing {
            processedPoints = smoothPoints(processedPoints)
        }

        return TelemetryTrack(
            id: track.id,
            name: track.name,
            description: track.description,
            type: track.type,
            source: track.source,
            points: processedPoints
        )
    }

    // MARK: - Distance Calculation

    /// Calculate distance between two coordinates using Haversine formula
    /// - Parameters:
    ///   - from: Starting coordinate
    ///   - to: Ending coordinate
    /// - Returns: Distance in meters
    public static func calculateDistance(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let location1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let location2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return location1.distance(from: location2)
    }

    // MARK: - Bearing Calculation

    /// Calculate bearing (heading) from one coordinate to another
    /// - Parameters:
    ///   - from: Starting coordinate
    ///   - to: Ending coordinate
    /// - Returns: Bearing in degrees (0-360, where 0 is north)
    public static func calculateBearing(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let lat1 = from.latitude.degreesToRadians
        let lon1 = from.longitude.degreesToRadians
        let lat2 = to.latitude.degreesToRadians
        let lon2 = to.longitude.degreesToRadians

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x).radiansToDegrees

        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    // MARK: - Smoothing

    /// Apply moving average smoothing to telemetry points
    /// - Parameter points: Points to smooth
    /// - Returns: Smoothed points
    private static func smoothPoints(_ points: [TelemetryPoint]) -> [TelemetryPoint] {
        guard points.count >= 3 else { return points }

        var smoothedPoints: [TelemetryPoint] = []
        let windowSize = 3 // Simple 3-point moving average

        for i in 0..<points.count {
            let startIndex = max(0, i - windowSize / 2)
            let endIndex = min(points.count - 1, i + windowSize / 2)
            let window = points[startIndex...endIndex]

            // Average speed
            let speeds = window.compactMap { $0.speed }
            let avgSpeed = speeds.isEmpty ? nil : speeds.reduce(0, +) / Double(speeds.count)

            // Average vertical speed
            let verticalSpeeds = window.compactMap { $0.verticalSpeed }
            let avgVerticalSpeed = verticalSpeeds.isEmpty ? nil : verticalSpeeds.reduce(0, +) / Double(verticalSpeeds.count)

            // Average G-force
            let gForces = window.compactMap { $0.gForce }
            let avgGForce = gForces.isEmpty ? nil : gForces.reduce(0, +) / Double(gForces.count)

            let point = points[i]
            let smoothedPoint = TelemetryPoint(
                id: point.id,
                timestamp: point.timestamp,
                coordinate: point.coordinate,
                elevation: point.elevation,
                speed: avgSpeed ?? point.speed,
                verticalSpeed: avgVerticalSpeed ?? point.verticalSpeed,
                heading: point.heading,
                horizontalAccuracy: point.horizontalAccuracy,
                verticalAccuracy: point.verticalAccuracy,
                gForce: avgGForce ?? point.gForce,
                distanceFromPrevious: point.distanceFromPrevious,
                timeDeltaFromPrevious: point.timeDeltaFromPrevious
            )

            smoothedPoints.append(smoothedPoint)
        }

        return smoothedPoints
    }
}

// MARK: - Helper Extensions

private extension Double {
    var degreesToRadians: Double {
        self * .pi / 180.0
    }

    var radiansToDegrees: Double {
        self * 180.0 / .pi
    }
}
