// SnapGuideEngineTests.swift
// Tests for snap guide detection functionality

import XCTest
import CoreGraphics
@testable import FlightTraceUI

final class SnapGuideEngineTests: XCTestCase {

    var engine: SnapGuideEngine!

    override func setUp() {
        super.setUp()
        engine = SnapGuideEngine(snapThreshold: 10.0)
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Canvas Edge Snapping

    func testSnapToLeftEdge() {
        // Position near left edge (within threshold)
        let position = CGPoint(x: 5, y: 100)
        let size = CGSize(width: 100, height: 100)
        let canvasSize = CGSize(width: 800, height: 600)

        let result = engine.calculateSnap(
            position: position,
            size: size,
            canvasSize: canvasSize
        )

        // Should snap to x = 0
        XCTAssertEqual(result.snappedPosition.x, 0, accuracy: 0.001)
        XCTAssertEqual(result.snappedPosition.y, 100) // Y unchanged
        XCTAssertTrue(result.didSnap)
        XCTAssertTrue(result.activeGuides.contains { $0.type == .edge && $0.orientation == .vertical })
    }

    func testSnapToRightEdge() {
        // Position near right edge
        let position = CGPoint(x: 695, y: 100)
        let size = CGSize(width: 100, height: 100)
        let canvasSize = CGSize(width: 800, height: 600)

        let result = engine.calculateSnap(
            position: position,
            size: size,
            canvasSize: canvasSize
        )

        // Should snap to right edge (canvas width - instrument width)
        XCTAssertEqual(result.snappedPosition.x, 700, accuracy: 0.001)
        XCTAssertTrue(result.didSnap)
    }

    func testSnapToTopEdge() {
        // Position near top edge
        let position = CGPoint(x: 100, y: 3)
        let size = CGSize(width: 100, height: 100)
        let canvasSize = CGSize(width: 800, height: 600)

        let result = engine.calculateSnap(
            position: position,
            size: size,
            canvasSize: canvasSize
        )

        // Should snap to y = 0
        XCTAssertEqual(result.snappedPosition.y, 0, accuracy: 0.001)
        XCTAssertTrue(result.didSnap)
    }

    func testSnapToBottomEdge() {
        // Position near bottom edge
        let position = CGPoint(x: 100, y: 497)
        let size = CGSize(width: 100, height: 100)
        let canvasSize = CGSize(width: 800, height: 600)

        let result = engine.calculateSnap(
            position: position,
            size: size,
            canvasSize: canvasSize
        )

        // Should snap to bottom edge (canvas height - instrument height)
        XCTAssertEqual(result.snappedPosition.y, 500, accuracy: 0.001)
        XCTAssertTrue(result.didSnap)
    }

    // MARK: - Canvas Center Snapping

    func testSnapToHorizontalCenter() {
        // Position near horizontal center
        let position = CGPoint(x: 345, y: 100)
        let size = CGSize(width: 100, height: 100)
        let canvasSize = CGSize(width: 800, height: 600)

        let result = engine.calculateSnap(
            position: position,
            size: size,
            canvasSize: canvasSize
        )

        // Should snap to horizontal center (instrument center at canvas center)
        // Canvas center X = 400, so position should be 400 - 50 = 350
        XCTAssertEqual(result.snappedPosition.x, 350, accuracy: 0.001)
        XCTAssertTrue(result.didSnap)
        XCTAssertTrue(result.activeGuides.contains { $0.type == .center && $0.orientation == .vertical })
    }

    func testSnapToVerticalCenter() {
        // Position near vertical center
        let position = CGPoint(x: 100, y: 245)
        let size = CGSize(width: 100, height: 100)
        let canvasSize = CGSize(width: 800, height: 600)

        let result = engine.calculateSnap(
            position: position,
            size: size,
            canvasSize: canvasSize
        )

        // Should snap to vertical center
        // Canvas center Y = 300, so position should be 300 - 50 = 250
        XCTAssertEqual(result.snappedPosition.y, 250, accuracy: 0.001)
        XCTAssertTrue(result.didSnap)
        XCTAssertTrue(result.activeGuides.contains { $0.type == .center && $0.orientation == .horizontal })
    }

    // MARK: - Rule of Thirds Snapping

    func testSnapToRuleOfThirdsVertical() {
        // Position near 1/3 vertical line
        let canvasSize = CGSize(width: 900, height: 600)
        let thirdX = canvasSize.width / 3 // 300

        // Position instrument so its center is near the third line
        let position = CGPoint(x: 245, y: 100)
        let size = CGSize(width: 100, height: 100)

        let result = engine.calculateSnap(
            position: position,
            size: size,
            canvasSize: canvasSize
        )

        // Should snap to 1/3 line (center at 300, so position at 250)
        XCTAssertEqual(result.snappedPosition.x, 250, accuracy: 0.001)
        XCTAssertTrue(result.didSnap)
        XCTAssertTrue(result.activeGuides.contains { $0.type == .ruleOfThirds && $0.orientation == .vertical })
    }

    func testSnapToRuleOfThirdsHorizontal() {
        // Position near 2/3 horizontal line
        let canvasSize = CGSize(width: 800, height: 900)
        let twoThirdsY = canvasSize.height * 2 / 3 // 600

        // Position instrument so its center is near the 2/3 line
        let position = CGPoint(x: 100, y: 545)
        let size = CGSize(width: 100, height: 100)

        let result = engine.calculateSnap(
            position: position,
            size: size,
            canvasSize: canvasSize
        )

        // Should snap to 2/3 line (center at 600, so position at 550)
        XCTAssertEqual(result.snappedPosition.y, 550, accuracy: 0.001)
        XCTAssertTrue(result.didSnap)
        XCTAssertTrue(result.activeGuides.contains { $0.type == .ruleOfThirds && $0.orientation == .horizontal })
    }

    // MARK: - Instrument-to-Instrument Snapping

    func testSnapToOtherInstrumentLeftEdge() {
        let position = CGPoint(x: 205, y: 100)
        let size = CGSize(width: 100, height: 100)
        let canvasSize = CGSize(width: 800, height: 600)

        // Other instrument at x: 200
        let otherInstruments = [
            (position: CGPoint(x: 200, y: 200), size: CGSize(width: 100, height: 100))
        ]

        let result = engine.calculateSnap(
            position: position,
            size: size,
            canvasSize: canvasSize,
            otherInstruments: otherInstruments
        )

        // Should snap to align left edges
        XCTAssertEqual(result.snappedPosition.x, 200, accuracy: 0.001)
        XCTAssertTrue(result.didSnap)
        XCTAssertTrue(result.activeGuides.contains { $0.type == .instrumentEdge })
    }

    func testSnapToOtherInstrumentCenter() {
        let position = CGPoint(x: 145, y: 100)
        let size = CGSize(width: 100, height: 100)
        let canvasSize = CGSize(width: 800, height: 600)

        // Other instrument centered at x: 200
        let otherInstruments = [
            (position: CGPoint(x: 150, y: 200), size: CGSize(width: 100, height: 100))
        ]

        let result = engine.calculateSnap(
            position: position,
            size: size,
            canvasSize: canvasSize,
            otherInstruments: otherInstruments
        )

        // Should snap to align centers (center at 200, so position at 150)
        XCTAssertEqual(result.snappedPosition.x, 150, accuracy: 0.001)
        XCTAssertTrue(result.didSnap)
        XCTAssertTrue(result.activeGuides.contains { $0.type == .instrumentCenter })
    }

    // MARK: - No Snap Condition

    func testNoSnapWhenFarFromGuides() {
        // Position far from any snap points
        let position = CGPoint(x: 222, y: 222)
        let size = CGSize(width: 100, height: 100)
        let canvasSize = CGSize(width: 800, height: 600)

        let result = engine.calculateSnap(
            position: position,
            size: size,
            canvasSize: canvasSize
        )

        // Should not snap
        XCTAssertEqual(result.snappedPosition, position)
        XCTAssertFalse(result.didSnap)
        XCTAssertTrue(result.activeGuides.isEmpty)
    }

    // MARK: - Static Guide Generation

    func testStaticGuideGeneration() {
        let canvasSize = CGSize(width: 900, height: 600)
        let guides = SnapGuideEngine.generateStaticGuides(canvasSize: canvasSize)

        // Should have 2 center guides + 4 rule of thirds guides = 6 total
        XCTAssertEqual(guides.count, 6)

        // Check center guides
        let centerGuides = guides.filter { $0.type == .center }
        XCTAssertEqual(centerGuides.count, 2)
        XCTAssertTrue(centerGuides.contains { $0.orientation == .vertical && $0.position == 450 })
        XCTAssertTrue(centerGuides.contains { $0.orientation == .horizontal && $0.position == 300 })

        // Check rule of thirds guides
        let thirdGuides = guides.filter { $0.type == .ruleOfThirds }
        XCTAssertEqual(thirdGuides.count, 4)
    }

    // MARK: - Snap Threshold

    func testSnapThresholdRespected() {
        // Create engine with smaller threshold
        let smallThresholdEngine = SnapGuideEngine(snapThreshold: 5.0)

        // Position 7 points from edge (beyond 5pt threshold)
        let position = CGPoint(x: 7, y: 100)
        let size = CGSize(width: 100, height: 100)
        let canvasSize = CGSize(width: 800, height: 600)

        let result = smallThresholdEngine.calculateSnap(
            position: position,
            size: size,
            canvasSize: canvasSize
        )

        // Should NOT snap (beyond threshold)
        XCTAssertEqual(result.snappedPosition, position)
        XCTAssertFalse(result.didSnap)
    }

    // MARK: - Multiple Snap Points

    func testPrioritizeFirstSnapPoint() {
        // Position that could snap to both left edge and another instrument
        let position = CGPoint(x: 5, y: 100)
        let size = CGSize(width: 100, height: 100)
        let canvasSize = CGSize(width: 800, height: 600)

        // Other instrument at x: 8
        let otherInstruments = [
            (position: CGPoint(x: 8, y: 200), size: CGSize(width: 100, height: 100))
        ]

        let result = engine.calculateSnap(
            position: position,
            size: size,
            canvasSize: canvasSize,
            otherInstruments: otherInstruments
        )

        // Should snap to left edge (checked first)
        XCTAssertEqual(result.snappedPosition.x, 0, accuracy: 0.001)
        XCTAssertTrue(result.didSnap)
    }
}
