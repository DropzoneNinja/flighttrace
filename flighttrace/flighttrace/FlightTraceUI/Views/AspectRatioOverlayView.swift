// AspectRatioOverlayView.swift
// Displays safe area overlays for common aspect ratios

import SwiftUI

/// View that displays safe area overlays for common aspect ratios
///
/// Helps users position instruments within specific aspect ratio bounds
/// for common video formats (16:9, 9:16, 1:1, etc.)
public struct AspectRatioOverlayView: View {

    // MARK: - Properties

    /// Canvas size
    let canvasSize: CGSize

    /// Selected aspect ratio to display
    let aspectRatio: AspectRatio?

    // MARK: - Aspect Ratio Definition

    public enum AspectRatio: String, CaseIterable, Identifiable {
        case landscape16x9 = "16:9 Landscape"
        case landscape4x3 = "4:3 Landscape"
        case landscape21x9 = "21:9 Ultrawide"
        case portrait9x16 = "9:16 Portrait"
        case portrait3x4 = "3:4 Portrait"
        case square1x1 = "1:1 Square"
        case custom = "Custom"

        public var id: String { rawValue }

        /// Calculate the ratio as width/height
        var ratio: CGFloat {
            switch self {
            case .landscape16x9:
                return 16.0 / 9.0
            case .landscape4x3:
                return 4.0 / 3.0
            case .landscape21x9:
                return 21.0 / 9.0
            case .portrait9x16:
                return 9.0 / 16.0
            case .portrait3x4:
                return 3.0 / 4.0
            case .square1x1:
                return 1.0
            case .custom:
                return 1.0  // Fallback
            }
        }

        /// Calculate safe area bounds within canvas
        func bounds(for canvasSize: CGSize) -> CGRect {
            let canvasRatio = canvasSize.width / canvasSize.height
            let targetRatio = ratio

            var safeWidth: CGFloat
            var safeHeight: CGFloat

            if canvasRatio > targetRatio {
                // Canvas is wider - constrain by height
                safeHeight = canvasSize.height
                safeWidth = safeHeight * targetRatio
            } else {
                // Canvas is taller - constrain by width
                safeWidth = canvasSize.width
                safeHeight = safeWidth / targetRatio
            }

            let x = (canvasSize.width - safeWidth) / 2
            let y = (canvasSize.height - safeHeight) / 2

            return CGRect(x: x, y: y, width: safeWidth, height: safeHeight)
        }
    }

    // MARK: - Initialization

    public init(canvasSize: CGSize, aspectRatio: AspectRatio?) {
        self.canvasSize = canvasSize
        self.aspectRatio = aspectRatio
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            if let aspectRatio = aspectRatio {
                let bounds = aspectRatio.bounds(for: canvasSize)

                // Dimmed outer area
                outerDimmedArea(bounds: bounds)

                // Safe area border
                safeAreaBorder(bounds: bounds)

                // Minor guide lines
                minorGuides(bounds: bounds)

                // Corner markers
                cornerMarkers(bounds: bounds)

                // Label
                aspectRatioLabel(aspectRatio: aspectRatio, bounds: bounds)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Outer Dimmed Area

    @ViewBuilder
    private func outerDimmedArea(bounds: CGRect) -> some View {
        // Top
        if bounds.minY > 0 {
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .frame(width: canvasSize.width, height: bounds.minY)
                .position(x: canvasSize.width / 2, y: bounds.minY / 2)
        }

        // Bottom
        if bounds.maxY < canvasSize.height {
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .frame(width: canvasSize.width, height: canvasSize.height - bounds.maxY)
                .position(
                    x: canvasSize.width / 2,
                    y: bounds.maxY + (canvasSize.height - bounds.maxY) / 2
                )
        }

        // Left
        if bounds.minX > 0 {
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .frame(width: bounds.minX, height: bounds.height)
                .position(x: bounds.minX / 2, y: canvasSize.height / 2)
        }

        // Right
        if bounds.maxX < canvasSize.width {
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .frame(width: canvasSize.width - bounds.maxX, height: bounds.height)
                .position(
                    x: bounds.maxX + (canvasSize.width - bounds.maxX) / 2,
                    y: canvasSize.height / 2
                )
        }
    }

    // MARK: - Safe Area Border

    @ViewBuilder
    private func safeAreaBorder(bounds: CGRect) -> some View {
        Rectangle()
            .strokeBorder(Color.yellow, lineWidth: 2)
            .frame(width: bounds.width, height: bounds.height)
            .position(x: bounds.midX, y: bounds.midY)
    }

    // MARK: - Minor Guides

    @ViewBuilder
    private func minorGuides(bounds: CGRect) -> some View {
        let midColor = Color.blue.opacity(0.35)
        let thirdColor = Color.green.opacity(0.35)
        let lineWidth: CGFloat = 1
        let hFractions: [CGFloat] = [0.5, 1.0 / 3.0, 2.0 / 3.0]
        let vFractions: [CGFloat] = [0.5, 1.0 / 3.0, 2.0 / 3.0]

        // Horizontal lines
        ForEach(hFractions, id: \.self) { f in
            let y = bounds.minY + bounds.height * f
            let color = f == 0.5 ? midColor : thirdColor
            Path { path in
                path.move(to: CGPoint(x: bounds.minX, y: y))
                path.addLine(to: CGPoint(x: bounds.maxX, y: y))
            }
            .stroke(
                color,
                style: StrokeStyle(lineWidth: lineWidth, dash: [6, 6])
            )
        }

        // Vertical lines
        ForEach(vFractions, id: \.self) { f in
            let x = bounds.minX + bounds.width * f
            let color = f == 0.5 ? midColor : thirdColor
            Path { path in
                path.move(to: CGPoint(x: x, y: bounds.minY))
                path.addLine(to: CGPoint(x: x, y: bounds.maxY))
            }
            .stroke(
                color,
                style: StrokeStyle(lineWidth: lineWidth, dash: [6, 6])
            )
        }
    }

    // MARK: - Corner Markers

    @ViewBuilder
    private func cornerMarkers(bounds: CGRect) -> some View {
        let markerLength: CGFloat = 20
        let markerWidth: CGFloat = 3

        // Top-left
        cornerMarker(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            length: markerLength,
            width: markerWidth,
            horizontal: .right,
            vertical: .down
        )

        // Top-right
        cornerMarker(
            at: CGPoint(x: bounds.maxX, y: bounds.minY),
            length: markerLength,
            width: markerWidth,
            horizontal: .left,
            vertical: .down
        )

        // Bottom-left
        cornerMarker(
            at: CGPoint(x: bounds.minX, y: bounds.maxY),
            length: markerLength,
            width: markerWidth,
            horizontal: .right,
            vertical: .up
        )

        // Bottom-right
        cornerMarker(
            at: CGPoint(x: bounds.maxX, y: bounds.maxY),
            length: markerLength,
            width: markerWidth,
            horizontal: .left,
            vertical: .up
        )
    }

    @ViewBuilder
    private func cornerMarker(
        at point: CGPoint,
        length: CGFloat,
        width: CGFloat,
        horizontal: HorizontalDirection,
        vertical: VerticalDirection
    ) -> some View {
        let horizontalOffset = horizontal == .right ? length / 2 : -length / 2
        let verticalOffset = vertical == .down ? length / 2 : -length / 2

        // Horizontal line
        Rectangle()
            .fill(Color.yellow)
            .frame(width: length, height: width)
            .position(x: point.x + horizontalOffset, y: point.y)

        // Vertical line
        Rectangle()
            .fill(Color.yellow)
            .frame(width: width, height: length)
            .position(x: point.x, y: point.y + verticalOffset)
    }

    enum HorizontalDirection {
        case left, right
    }

    enum VerticalDirection {
        case up, down
    }

    // MARK: - Aspect Ratio Label

    @ViewBuilder
    private func aspectRatioLabel(aspectRatio: AspectRatio, bounds: CGRect) -> some View {
        Text(aspectRatio.rawValue)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.yellow)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.7))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.yellow, lineWidth: 1)
            )
            .position(x: bounds.midX, y: bounds.minY - 20)
    }
}

// MARK: - Preview

#if DEBUG
struct AspectRatioOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        let canvasSize = CGSize(width: 1920, height: 1080)

        VStack(spacing: 20) {
            // 16:9 Landscape
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: canvasSize.width, height: canvasSize.height)

                AspectRatioOverlayView(
                    canvasSize: canvasSize,
                    aspectRatio: .landscape16x9
                )
            }
            .frame(width: 800, height: 450)

            // 9:16 Portrait on landscape canvas
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: canvasSize.width, height: canvasSize.height)

                AspectRatioOverlayView(
                    canvasSize: canvasSize,
                    aspectRatio: .portrait9x16
                )
            }
            .frame(width: 800, height: 450)

            // 1:1 Square
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: canvasSize.width, height: canvasSize.height)

                AspectRatioOverlayView(
                    canvasSize: canvasSize,
                    aspectRatio: .square1x1
                )
            }
            .frame(width: 800, height: 450)
        }
        .padding()
        .background(Color.black)
    }
}
#endif
