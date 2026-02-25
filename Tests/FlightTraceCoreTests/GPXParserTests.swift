// GPXParserTests.swift
// Unit tests for GPX parsing functionality

import XCTest
@testable import FlightTraceCore

final class GPXParserTests: XCTestCase {

    // MARK: - Test GPX Data

    let sampleGPX = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="FlightTrace Test">
      <trk>
        <name>Test Flight</name>
        <desc>Sample GPS track for testing</desc>
        <type>flying</type>
        <trkseg>
          <trkpt lat="37.7749" lon="-122.4194">
            <ele>100.0</ele>
            <time>2024-01-01T12:00:00Z</time>
          </trkpt>
          <trkpt lat="37.7750" lon="-122.4195">
            <ele>110.0</ele>
            <time>2024-01-01T12:00:10Z</time>
            <speed>5.0</speed>
          </trkpt>
          <trkpt lat="37.7751" lon="-122.4196">
            <ele>120.0</ele>
            <time>2024-01-01T12:00:20Z</time>
          </trkpt>
        </trkseg>
      </trk>
    </gpx>
    """

    let multiTrackGPX = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1">
      <trk>
        <name>Track 1</name>
        <trkseg>
          <trkpt lat="37.7749" lon="-122.4194">
            <time>2024-01-01T12:00:00Z</time>
          </trkpt>
        </trkseg>
      </trk>
      <trk>
        <name>Track 2</name>
        <trkseg>
          <trkpt lat="37.7750" lon="-122.4195">
            <time>2024-01-01T12:00:10Z</time>
          </trkpt>
        </trkseg>
      </trk>
    </gpx>
    """

    // MARK: - Basic Parsing Tests

    func testParseValidGPX() throws {
        let data = sampleGPX.data(using: .utf8)!
        let tracks = try GPXParser.parse(data: data)

        XCTAssertEqual(tracks.count, 1)
        let track = tracks[0]

        XCTAssertEqual(track.name, "Test Flight")
        XCTAssertEqual(track.description, "Sample GPS track for testing")
        XCTAssertEqual(track.type, "flying")
        XCTAssertEqual(track.points.count, 3)
    }

    func testParseCoordinates() throws {
        let data = sampleGPX.data(using: .utf8)!
        let tracks = try GPXParser.parse(data: data)

        let firstPoint = tracks[0].points[0]
        XCTAssertEqual(firstPoint.coordinate.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(firstPoint.coordinate.longitude, -122.4194, accuracy: 0.0001)
    }

    func testParseElevation() throws {
        let data = sampleGPX.data(using: .utf8)!
        let tracks = try GPXParser.parse(data: data)

        let firstPoint = tracks[0].points[0]
        XCTAssertNotNil(firstPoint.elevation)
        XCTAssertEqual(firstPoint.elevation, 100.0, accuracy: 0.1)

        let secondPoint = tracks[0].points[1]
        XCTAssertEqual(secondPoint.elevation, 110.0, accuracy: 0.1)
    }

    func testParseTimestamp() throws {
        let data = sampleGPX.data(using: .utf8)!
        let tracks = try GPXParser.parse(data: data)

        let firstPoint = tracks[0].points[0]
        let formatter = ISO8601DateFormatter()
        let expectedDate = formatter.date(from: "2024-01-01T12:00:00Z")

        XCTAssertNotNil(expectedDate)
        XCTAssertEqual(firstPoint.timestamp, expectedDate)
    }

    func testParseSpeed() throws {
        let data = sampleGPX.data(using: .utf8)!
        let tracks = try GPXParser.parse(data: data)

        let secondPoint = tracks[0].points[1]
        XCTAssertNotNil(secondPoint.speed)
        XCTAssertEqual(secondPoint.speed, 5.0, accuracy: 0.1)
    }

    // MARK: - Multi-Track Tests

    func testParseMultipleTracks() throws {
        let data = multiTrackGPX.data(using: .utf8)!
        let tracks = try GPXParser.parse(data: data)

        XCTAssertEqual(tracks.count, 2)
        XCTAssertEqual(tracks[0].name, "Track 1")
        XCTAssertEqual(tracks[1].name, "Track 2")
    }

    // MARK: - Error Handling Tests

    func testParseInvalidXML() throws {
        let invalidXML = "This is not XML"
        let data = invalidXML.data(using: .utf8)!

        XCTAssertThrowsError(try GPXParser.parse(data: data)) { error in
            XCTAssertTrue(error is GPXParserError)
        }
    }

    func testParseEmptyGPX() throws {
        let emptyGPX = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1"></gpx>
        """
        let data = emptyGPX.data(using: .utf8)!

        XCTAssertThrowsError(try GPXParser.parse(data: data)) { error in
            if case GPXParserError.noTracksFound = error {
                // Expected error
            } else {
                XCTFail("Expected noTracksFound error")
            }
        }
    }

    // MARK: - Track Properties Tests

    func testTrackDuration() throws {
        let data = sampleGPX.data(using: .utf8)!
        let tracks = try GPXParser.parse(data: data)
        let track = tracks[0]

        XCTAssertNotNil(track.duration)
        XCTAssertEqual(track.duration, 20.0, accuracy: 0.1) // 20 seconds
    }

    func testTrackBoundingBox() throws {
        let data = sampleGPX.data(using: .utf8)!
        let tracks = try GPXParser.parse(data: data)
        let track = tracks[0]

        XCTAssertNotNil(track.boundingBox)
        let bbox = track.boundingBox!

        XCTAssertEqual(bbox.min.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(bbox.max.latitude, 37.7751, accuracy: 0.0001)
        XCTAssertEqual(bbox.min.longitude, -122.4196, accuracy: 0.0001)
        XCTAssertEqual(bbox.max.longitude, -122.4194, accuracy: 0.0001)
    }
}
