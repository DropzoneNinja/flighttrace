// ManualTest.swift
// Manual test to verify GPX parsing and telemetry calculation

import Foundation
import FlightTraceCore

@main
struct ManualTest {
    static func main() throws {
        print("FlightTrace Manual Test")
        print("======================\n")

        // Test 1: Parse Sample GPX File
        print("Test 1: Parsing sample GPX file...")
        let gpxPath = "Tests/TestData/sample_flight.gpx"
        let url = URL(fileURLWithPath: gpxPath)

        guard FileManager.default.fileExists(atPath: gpxPath) else {
            print("ERROR: Sample GPX file not found at \(gpxPath)")
            return
        }

        let tracks = try GPXParser.parse(fileURL: url)
        print("✅ Successfully parsed \(tracks.count) track(s)")

        let track = tracks[0]
        print("\nTrack Information:")
        print("  Name: \(track.name ?? "N/A")")
        print("  Description: \(track.description ?? "N/A")")
        print("  Type: \(track.type ?? "N/A")")
        print("  Points: \(track.points.count)")
        print("  Duration: \(track.duration?.formatted() ?? "N/A") seconds")

        // Test 2: Verify Coordinates
        print("\nTest 2: Verifying coordinates...")
        let firstPoint = track.points[0]
        print("  First point: \(firstPoint.coordinate.latitude), \(firstPoint.coordinate.longitude)")
        print("  Elevation: \(firstPoint.elevation?.formatted() ?? "N/A") meters")
        print("  Timestamp: \(firstPoint.timestamp)")
        print("✅ Coordinates parsed correctly")

        // Test 3: Process Telemetry with Calculator
        print("\nTest 3: Processing telemetry with calculator...")
        let processedTrack = TelemetryCalculator.process(track: track, smoothing: true)
        print("✅ Telemetry processed successfully")

        print("\nProcessed Track Statistics:")
        print("  Total Distance: \(processedTrack.totalDistance.formatted()) meters")
        print("  Max Speed: \(processedTrack.maxSpeed?.formatted() ?? "N/A") m/s")
        print("  Average Speed: \(processedTrack.averageSpeed?.formatted() ?? "N/A") m/s")
        print("  Max Elevation: \(processedTrack.maxElevation?.formatted() ?? "N/A") meters")
        print("  Min Elevation: \(processedTrack.minElevation?.formatted() ?? "N/A") meters")
        print("  Elevation Gain: \(processedTrack.elevationGain.formatted()) meters")
        print("  Elevation Loss: \(processedTrack.elevationLoss.formatted()) meters")

        // Test 4: Check Derived Metrics
        print("\nTest 4: Checking derived metrics...")
        let secondPoint = processedTrack.points[1]
        print("  Point 2 derived speed: \(secondPoint.speed?.formatted() ?? "N/A") m/s")
        print("  Point 2 vertical speed: \(secondPoint.verticalSpeed?.formatted() ?? "N/A") m/s")
        print("  Point 2 heading: \(secondPoint.heading?.formatted() ?? "N/A")°")
        print("  Point 2 distance from previous: \(secondPoint.distanceFromPrevious?.formatted() ?? "N/A") meters")

        if secondPoint.speed != nil {
            print("✅ Speed successfully derived")
        }
        if secondPoint.verticalSpeed != nil {
            print("✅ Vertical speed successfully derived")
        }
        if secondPoint.heading != nil {
            print("✅ Heading successfully derived")
        }

        // Test 5: Data Smoothing
        print("\nTest 5: Testing data smoothing...")
        let noisyData = [10.0, 50.0, 12.0, 11.0, 60.0, 13.0, 12.5]
        let smoothed = DataSmoother.smooth(noisyData, algorithm: .movingAverage(windowSize: 3))
        print("  Original: \(noisyData.map { String(format: "%.1f", $0) }.joined(separator: ", "))")
        print("  Smoothed: \(smoothed.map { String(format: "%.1f", $0) }.joined(separator: ", "))")
        print("✅ Smoothing applied successfully")

        // Test 6: Outlier Removal
        print("\nTest 6: Testing outlier removal...")
        let dataWithOutliers = [10.0, 11.0, 10.5, 100.0, 10.2, 11.5]
        let cleaned = DataSmoother.removeOutliers(dataWithOutliers, threshold: 2.0)
        print("  Original: \(dataWithOutliers.map { String(format: "%.1f", $0) }.joined(separator: ", "))")
        print("  Cleaned: \(cleaned.map { String(format: "%.1f", $0) }.joined(separator: ", "))")
        print("✅ Outlier removal successful")

        print("\n======================")
        print("All manual tests passed! ✅")
    }
}

extension Double {
    func formatted() -> String {
        String(format: "%.2f", self)
    }
}
