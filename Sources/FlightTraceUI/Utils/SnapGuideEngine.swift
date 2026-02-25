// SnapGuideEngine.swift
// Detects snap points for instrument positioning

import Foundation
import CoreGraphics

/// Snap guide engine for detecting alignment points during drag operations
///
/// Provides intelligent snapping to:
/// - Canvas edges
/// - Canvas center
/// - Rule of thirds grid points
/// - Other instrument edges and centers
@MainActor
public final class SnapGuideEngine {

    // MARK: - Constants

    /// Distance threshold for snapping (in points)
    public var snapThreshold: CGFloat = 10.0

    // MARK: - Snap Guide Types

    /// Represents a snap guide line
    public struct SnapGuide: Equatable {
        public let type: GuideType
        public let orientation: Orientation
        public let position: CGFloat
        public let range: ClosedRange<CGFloat>

        public enum GuideType {
            case edge
            case center
            case ruleOfThirds
            case instrumentEdge
            case instrumentCenter
        }

        public enum Orientation {
            case horizontal
            case vertical
        }

        public init(
            type: GuideType,
            orientation: Orientation,
            position: CGFloat,
            range: ClosedRange<CGFloat>
        ) {
            self.type = type
            self.orientation = orientation
            self.position = position
            self.range = range
        }
    }

    /// Result of snap detection
    public struct SnapResult {
        public let snappedPosition: CGPoint
        public let activeGuides: [SnapGuide]
        public let didSnap: Bool

        public init(
            snappedPosition: CGPoint,
            activeGuides: [SnapGuide],
            didSnap: Bool
        ) {
            self.snappedPosition = snappedPosition
            self.activeGuides = activeGuides
            self.didSnap = didSnap
        }
    }

    // MARK: - Initialization

    public init(snapThreshold: CGFloat = 10.0) {
        self.snapThreshold = snapThreshold
    }

    // MARK: - Snap Detection

    /// Calculate snap position for an instrument being dragged
    /// - Parameters:
    ///   - position: Desired position (top-left corner)
    ///   - size: Size of the instrument
    ///   - canvasSize: Size of the canvas
    ///   - otherInstruments: Other instruments on the canvas to snap to
    /// - Returns: Snap result with snapped position and active guides
    public func calculateSnap(
        position: CGPoint,
        size: CGSize,
        canvasSize: CGSize,
        otherInstruments: [(position: CGPoint, size: CGSize)] = []
    ) -> SnapResult {
        var snappedX = position.x
        var snappedY = position.y
        var activeGuides: [SnapGuide] = []
        var didSnapX = false
        var didSnapY = false

        // Calculate instrument center
        let centerX = position.x + size.width / 2
        let centerY = position.y + size.height / 2
        let right = position.x + size.width
        let bottom = position.y + size.height

        // MARK: Canvas Edge Snapping

        // Left edge
        if abs(position.x) < snapThreshold {
            snappedX = 0
            didSnapX = true
            activeGuides.append(SnapGuide(
                type: .edge,
                orientation: .vertical,
                position: 0,
                range: 0...canvasSize.height
            ))
        }

        // Right edge
        if abs(right - canvasSize.width) < snapThreshold {
            snappedX = canvasSize.width - size.width
            didSnapX = true
            activeGuides.append(SnapGuide(
                type: .edge,
                orientation: .vertical,
                position: canvasSize.width,
                range: 0...canvasSize.height
            ))
        }

        // Top edge
        if abs(position.y) < snapThreshold {
            snappedY = 0
            didSnapY = true
            activeGuides.append(SnapGuide(
                type: .edge,
                orientation: .horizontal,
                position: 0,
                range: 0...canvasSize.width
            ))
        }

        // Bottom edge
        if abs(bottom - canvasSize.height) < snapThreshold {
            snappedY = canvasSize.height - size.height
            didSnapY = true
            activeGuides.append(SnapGuide(
                type: .edge,
                orientation: .horizontal,
                position: canvasSize.height,
                range: 0...canvasSize.width
            ))
        }

        // MARK: Canvas Center Snapping

        let canvasCenterX = canvasSize.width / 2
        let canvasCenterY = canvasSize.height / 2

        // Horizontal center
        if abs(centerX - canvasCenterX) < snapThreshold {
            snappedX = canvasCenterX - size.width / 2
            didSnapX = true
            activeGuides.append(SnapGuide(
                type: .center,
                orientation: .vertical,
                position: canvasCenterX,
                range: 0...canvasSize.height
            ))
        }

        // Vertical center
        if abs(centerY - canvasCenterY) < snapThreshold {
            snappedY = canvasCenterY - size.height / 2
            didSnapY = true
            activeGuides.append(SnapGuide(
                type: .center,
                orientation: .horizontal,
                position: canvasCenterY,
                range: 0...canvasSize.width
            ))
        }

        // MARK: Rule of Thirds Snapping

        let thirdWidth = canvasSize.width / 3
        let thirdHeight = canvasSize.height / 3

        // Vertical thirds (1/3 and 2/3)
        for i in 1...2 {
            let thirdX = thirdWidth * CGFloat(i)
            if abs(centerX - thirdX) < snapThreshold {
                snappedX = thirdX - size.width / 2
                didSnapX = true
                activeGuides.append(SnapGuide(
                    type: .ruleOfThirds,
                    orientation: .vertical,
                    position: thirdX,
                    range: 0...canvasSize.height
                ))
            }
        }

        // Horizontal thirds (1/3 and 2/3)
        for i in 1...2 {
            let thirdY = thirdHeight * CGFloat(i)
            if abs(centerY - thirdY) < snapThreshold {
                snappedY = thirdY - size.height / 2
                didSnapY = true
                activeGuides.append(SnapGuide(
                    type: .ruleOfThirds,
                    orientation: .horizontal,
                    position: thirdY,
                    range: 0...canvasSize.width
                ))
            }
        }

        // MARK: Instrument-to-Instrument Snapping

        for other in otherInstruments {
            let otherCenterX = other.position.x + other.size.width / 2
            let otherCenterY = other.position.y + other.size.height / 2
            let otherRight = other.position.x + other.size.width
            let otherBottom = other.position.y + other.size.height

            // Horizontal alignment

            // Align left edges
            if !didSnapX && abs(position.x - other.position.x) < snapThreshold {
                snappedX = other.position.x
                didSnapX = true
                let minY = min(position.y, other.position.y)
                let maxY = max(bottom, otherBottom)
                activeGuides.append(SnapGuide(
                    type: .instrumentEdge,
                    orientation: .vertical,
                    position: other.position.x,
                    range: minY...maxY
                ))
            }

            // Align right edges
            if !didSnapX && abs(right - otherRight) < snapThreshold {
                snappedX = otherRight - size.width
                didSnapX = true
                let minY = min(position.y, other.position.y)
                let maxY = max(bottom, otherBottom)
                activeGuides.append(SnapGuide(
                    type: .instrumentEdge,
                    orientation: .vertical,
                    position: otherRight,
                    range: minY...maxY
                ))
            }

            // Align centers horizontally
            if !didSnapX && abs(centerX - otherCenterX) < snapThreshold {
                snappedX = otherCenterX - size.width / 2
                didSnapX = true
                let minY = min(position.y, other.position.y)
                let maxY = max(bottom, otherBottom)
                activeGuides.append(SnapGuide(
                    type: .instrumentCenter,
                    orientation: .vertical,
                    position: otherCenterX,
                    range: minY...maxY
                ))
            }

            // Vertical alignment

            // Align top edges
            if !didSnapY && abs(position.y - other.position.y) < snapThreshold {
                snappedY = other.position.y
                didSnapY = true
                let minX = min(position.x, other.position.x)
                let maxX = max(right, otherRight)
                activeGuides.append(SnapGuide(
                    type: .instrumentEdge,
                    orientation: .horizontal,
                    position: other.position.y,
                    range: minX...maxX
                ))
            }

            // Align bottom edges
            if !didSnapY && abs(bottom - otherBottom) < snapThreshold {
                snappedY = otherBottom - size.height
                didSnapY = true
                let minX = min(position.x, other.position.x)
                let maxX = max(right, otherRight)
                activeGuides.append(SnapGuide(
                    type: .instrumentEdge,
                    orientation: .horizontal,
                    position: otherBottom,
                    range: minX...maxX
                ))
            }

            // Align centers vertically
            if !didSnapY && abs(centerY - otherCenterY) < snapThreshold {
                snappedY = otherCenterY - size.height / 2
                didSnapY = true
                let minX = min(position.x, other.position.x)
                let maxX = max(right, otherRight)
                activeGuides.append(SnapGuide(
                    type: .instrumentCenter,
                    orientation: .horizontal,
                    position: otherCenterY,
                    range: minX...maxX
                ))
            }
        }

        let didSnap = didSnapX || didSnapY
        let snappedPosition = CGPoint(x: snappedX, y: snappedY)

        return SnapResult(
            snappedPosition: snappedPosition,
            activeGuides: activeGuides,
            didSnap: didSnap
        )
    }

    // MARK: - Static Guide Generation

    /// Generate static guide lines for canvas (center and rule of thirds)
    /// - Parameter canvasSize: Size of the canvas
    /// - Returns: Array of guide lines to display
    public static func generateStaticGuides(canvasSize: CGSize) -> [SnapGuide] {
        var guides: [SnapGuide] = []

        // Center guides
        guides.append(SnapGuide(
            type: .center,
            orientation: .vertical,
            position: canvasSize.width / 2,
            range: 0...canvasSize.height
        ))

        guides.append(SnapGuide(
            type: .center,
            orientation: .horizontal,
            position: canvasSize.height / 2,
            range: 0...canvasSize.width
        ))

        // Rule of thirds guides
        let thirdWidth = canvasSize.width / 3
        let thirdHeight = canvasSize.height / 3

        for i in 1...2 {
            guides.append(SnapGuide(
                type: .ruleOfThirds,
                orientation: .vertical,
                position: thirdWidth * CGFloat(i),
                range: 0...canvasSize.height
            ))

            guides.append(SnapGuide(
                type: .ruleOfThirds,
                orientation: .horizontal,
                position: thirdHeight * CGFloat(i),
                range: 0...canvasSize.width
            ))
        }

        return guides
    }
}
