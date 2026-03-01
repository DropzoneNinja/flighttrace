// SnapGuidesView.swift
// Renders snap guide lines on the canvas

import SwiftUI

/// View that renders snap guide lines
///
/// Displays visual guides for:
/// - Active snap guides during drag operations
/// - Static guides (center, rule of thirds) when enabled
public struct SnapGuidesView: View {

    // MARK: - Properties

    /// Active snap guides to display
    let guides: [SnapGuideEngine.SnapGuide]

    /// Canvas size
    let canvasSize: CGSize

    /// Whether to show static guides
    let showStaticGuides: Bool

    // MARK: - Initialization

    public init(
        guides: [SnapGuideEngine.SnapGuide],
        canvasSize: CGSize,
        showStaticGuides: Bool = false
    ) {
        self.guides = guides
        self.canvasSize = canvasSize
        self.showStaticGuides = showStaticGuides
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Static guides (if enabled)
            if showStaticGuides {
                staticGuidesView
            }

            // Active snap guides
            ForEach(Array(guides.enumerated()), id: \.offset) { _, guide in
                guideView(for: guide)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Static Guides

    private var staticGuidesView: some View {
        let staticGuides = SnapGuideEngine.generateStaticGuides(canvasSize: canvasSize)

        return ForEach(Array(staticGuides.enumerated()), id: \.offset) { _, guide in
            guideLine(
                orientation: guide.orientation,
                position: guide.position,
                range: guide.range,
                color: colorForGuideType(guide.type),
                lineWidth: 1,
                dashPattern: [5, 5]
            )
        }
    }

    // MARK: - Guide View

    @ViewBuilder
    private func guideView(for guide: SnapGuideEngine.SnapGuide) -> some View {
        guideLine(
            orientation: guide.orientation,
            position: guide.position,
            range: guide.range,
            color: colorForGuideType(guide.type),
            lineWidth: lineWidthForGuideType(guide.type),
            dashPattern: dashPatternForGuideType(guide.type)
        )
    }

    // MARK: - Guide Line

    @ViewBuilder
    private func guideLine(
        orientation: SnapGuideEngine.SnapGuide.Orientation,
        position: CGFloat,
        range: ClosedRange<CGFloat>,
        color: Color,
        lineWidth: CGFloat,
        dashPattern: [CGFloat]
    ) -> some View {
        Path { path in
            switch orientation {
            case .horizontal:
                path.move(to: CGPoint(x: range.lowerBound, y: position))
                path.addLine(to: CGPoint(x: range.upperBound, y: position))

            case .vertical:
                path.move(to: CGPoint(x: position, y: range.lowerBound))
                path.addLine(to: CGPoint(x: position, y: range.upperBound))
            }
        }
        .stroke(color, style: StrokeStyle(lineWidth: lineWidth, dash: dashPattern))
    }

    // MARK: - Styling Helpers

    private func colorForGuideType(_ type: SnapGuideEngine.SnapGuide.GuideType) -> Color {
        switch type {
        case .edge:
            return Color.red.opacity(0.6)
        case .center:
            return Color.blue.opacity(0.6)
        case .ruleOfThirds:
            return Color.green.opacity(0.5)
        case .instrumentEdge:
            return Color.purple.opacity(0.6)
        case .instrumentCenter:
            return Color.cyan.opacity(0.6)
        }
    }

    private func lineWidthForGuideType(_ type: SnapGuideEngine.SnapGuide.GuideType) -> CGFloat {
        switch type {
        case .edge, .center:
            return 2
        case .ruleOfThirds:
            return 1.5
        case .instrumentEdge, .instrumentCenter:
            return 2
        }
    }

    private func dashPatternForGuideType(_ type: SnapGuideEngine.SnapGuide.GuideType) -> [CGFloat] {
        switch type {
        case .edge:
            return []  // Solid line
        case .center:
            return [10, 5]
        case .ruleOfThirds:
            return [5, 5]
        case .instrumentEdge:
            return []  // Solid line
        case .instrumentCenter:
            return [10, 5]
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SnapGuidesView_Previews: PreviewProvider {
    static var previews: some View {
        let canvasSize = CGSize(width: 800, height: 600)

        let sampleGuides: [SnapGuideEngine.SnapGuide] = [
            // Center vertical guide
            SnapGuideEngine.SnapGuide(
                type: .center,
                orientation: .vertical,
                position: canvasSize.width / 2,
                range: 0...canvasSize.height
            ),
            // Left edge guide
            SnapGuideEngine.SnapGuide(
                type: .edge,
                orientation: .vertical,
                position: 0,
                range: 100...400
            ),
            // Instrument alignment guide
            SnapGuideEngine.SnapGuide(
                type: .instrumentEdge,
                orientation: .horizontal,
                position: 200,
                range: 100...500
            )
        ]

        return ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .frame(width: canvasSize.width, height: canvasSize.height)

            SnapGuidesView(
                guides: sampleGuides,
                canvasSize: canvasSize,
                showStaticGuides: true
            )
        }
        .frame(width: 900, height: 700)
        .background(Color.gray)
    }
}
#endif
