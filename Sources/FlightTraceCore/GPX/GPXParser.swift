// GPXParser.swift
// Parses GPX files and extracts telemetry data

import Foundation
import CoreLocation

/// Errors that can occur during GPX parsing
public enum GPXParserError: Error, LocalizedError {
    case invalidData
    case invalidXML
    case noTracksFound
    case invalidCoordinates
    case parsingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid GPX data provided"
        case .invalidXML:
            return "GPX file contains invalid XML"
        case .noTracksFound:
            return "No tracks found in GPX file"
        case .invalidCoordinates:
            return "Invalid coordinates in GPX data"
        case .parsingFailed(let reason):
            return "GPX parsing failed: \(reason)"
        }
    }
}

/// Parses GPX files and converts them to TelemetryTrack objects
public final class GPXParser: NSObject {

    // MARK: - Public API

    /// Parse GPX data from a file URL
    /// - Parameter url: URL to the GPX file
    /// - Returns: Array of parsed telemetry tracks
    /// - Throws: GPXParserError if parsing fails
    public static func parse(fileURL url: URL) throws -> [TelemetryTrack] {
        let data = try Data(contentsOf: url)
        return try parse(data: data)
    }

    /// Parse GPX data from raw data
    /// - Parameter data: GPX XML data
    /// - Returns: Array of parsed telemetry tracks
    /// - Throws: GPXParserError if parsing fails
    public static func parse(data: Data) throws -> [TelemetryTrack] {
        let parser = GPXParser()
        return try parser.parseInternal(data: data)
    }

    // MARK: - Private Implementation

    private var tracks: [TelemetryTrack] = []
    private var currentTrackName: String?
    private var currentTrackDescription: String?
    private var currentTrackType: String?
    private var currentSegmentPoints: [TelemetryPoint] = []
    private var allSegmentPoints: [[TelemetryPoint]] = []

    // Current point being parsed
    private var currentLatitude: Double?
    private var currentLongitude: Double?
    private var currentElevation: Double?
    private var currentTimestamp: Date?
    private var currentSpeed: Double?
    private var currentHorizontalAccuracy: Double?
    private var currentVerticalAccuracy: Double?

    // Current XML element and content
    private var currentElement: String = ""
    private var currentText: String = ""

    // Track metadata
    private var trackSource: String?

    private func parseInternal(data: Data) throws -> [TelemetryTrack] {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self
        xmlParser.shouldProcessNamespaces = false
        xmlParser.shouldReportNamespacePrefixes = false

        guard xmlParser.parse() else {
            if let error = xmlParser.parserError {
                throw GPXParserError.parsingFailed(error.localizedDescription)
            }
            throw GPXParserError.invalidXML
        }

        guard !tracks.isEmpty else {
            throw GPXParserError.noTracksFound
        }

        return tracks
    }

    private func createTelemetryPoint() -> TelemetryPoint? {
        guard let lat = currentLatitude,
              let lon = currentLongitude,
              let timestamp = currentTimestamp else {
            return nil
        }

        // Validate coordinates
        guard lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 else {
            return nil
        }

        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)

        return TelemetryPoint(
            timestamp: timestamp,
            coordinate: coordinate,
            elevation: currentElevation,
            speed: currentSpeed,
            horizontalAccuracy: currentHorizontalAccuracy,
            verticalAccuracy: currentVerticalAccuracy
        )
    }

    private func resetCurrentPoint() {
        currentLatitude = nil
        currentLongitude = nil
        currentElevation = nil
        currentTimestamp = nil
        currentSpeed = nil
        currentHorizontalAccuracy = nil
        currentVerticalAccuracy = nil
    }

    private func finishTrack() {
        guard !allSegmentPoints.isEmpty else {
            return
        }

        // Flatten all segments into a single track
        let allPoints = allSegmentPoints.flatMap { $0 }

        guard !allPoints.isEmpty else {
            return
        }

        let track = TelemetryTrack(
            name: currentTrackName,
            description: currentTrackDescription,
            type: currentTrackType,
            source: trackSource,
            points: allPoints
        )

        tracks.append(track)

        // Reset for next track
        currentTrackName = nil
        currentTrackDescription = nil
        currentTrackType = nil
        allSegmentPoints.removeAll()
    }
}

// MARK: - XMLParserDelegate

extension GPXParser: XMLParserDelegate {

    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentText = ""

        switch elementName {
        case "trkpt", "wpt":
            // Track point or waypoint - extract lat/lon from attributes
            if let latStr = attributeDict["lat"],
               let lonStr = attributeDict["lon"],
               let lat = Double(latStr),
               let lon = Double(lonStr) {
                currentLatitude = lat
                currentLongitude = lon
            }

        case "trkseg":
            // Start of a new track segment
            currentSegmentPoints = []

        case "trk":
            // Start of a new track
            allSegmentPoints = []

        default:
            break
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "trkpt", "wpt":
            // Finish current point and add to segment
            if let point = createTelemetryPoint() {
                currentSegmentPoints.append(point)
            }
            resetCurrentPoint()

        case "trkseg":
            // Finish current segment
            if !currentSegmentPoints.isEmpty {
                allSegmentPoints.append(currentSegmentPoints)
            }
            currentSegmentPoints = []

        case "trk":
            // Finish current track
            finishTrack()

        case "name":
            if currentElement == "name" {
                currentTrackName = trimmedText.isEmpty ? nil : trimmedText
            }

        case "desc":
            if currentElement == "desc" {
                currentTrackDescription = trimmedText.isEmpty ? nil : trimmedText
            }

        case "type":
            if currentElement == "type" {
                currentTrackType = trimmedText.isEmpty ? nil : trimmedText
            }

        case "ele":
            if let elevation = Double(trimmedText) {
                currentElevation = elevation
            }

        case "time":
            // Parse ISO 8601 timestamp with fractional seconds support
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            currentTimestamp = formatter.date(from: trimmedText)

            // Fallback to standard format if fractional seconds parsing fails
            if currentTimestamp == nil {
                currentTimestamp = ISO8601DateFormatter().date(from: trimmedText)
            }

        case "speed":
            if let speed = Double(trimmedText) {
                currentSpeed = speed
            }

        case "hdop":
            // Horizontal dilution of precision
            if let hdop = Double(trimmedText) {
                currentHorizontalAccuracy = hdop
            }

        case "vdop":
            // Vertical dilution of precision
            if let vdop = Double(trimmedText) {
                currentVerticalAccuracy = vdop
            }

        case "src", "source":
            if !trimmedText.isEmpty {
                trackSource = trimmedText
            }

        default:
            break
        }

        currentText = ""
    }

    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        // Error will be handled in parseInternal
    }
}
