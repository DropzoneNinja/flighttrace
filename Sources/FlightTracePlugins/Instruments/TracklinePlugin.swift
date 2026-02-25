// TracklinePlugin.swift
// Trackline/breadcrumb trail instrument plugin

import Foundation
import CoreGraphics
import CoreLocation
@preconcurrency import FlightTraceCore

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Trackline Style

/// Display style for the trackline
public enum TracklineStyle: String, Sendable, Codable, CaseIterable, Equatable {
    case line = "Continuous Line"
    case dots = "Dots"
    case gradient = "Gradient Line"
    case speedColored = "Speed Colored"
}

// MARK: - Trackline Configuration

/// Configuration for the Trackline/Breadcrumb Trail instrument
public struct TracklineConfiguration: InstrumentConfiguration, Codable {
    public var id = UUID()

    /// Display style for the trail
    public var style: TracklineStyle = .gradient

    /// Number of historical points to display (0 = all)
    public var historyCount: Int = 100

    /// Line width for the track
    public var lineWidth: Double = 3.0

    /// Color for the track line
    public var lineColor: SerializableColor = SerializableColor(red: 0.2, green: 0.6, blue: 1.0)

    /// Color for the current position marker
    public var currentPositionColor: SerializableColor = SerializableColor(red: 1.0, green: 0.3, blue: 0.3)

    /// Background color
    public var backgroundColor: SerializableColor = SerializableColor.black.withAlpha(0.5)

    /// Whether to show current position marker
    public var showCurrentPosition: Bool = true

    /// Whether to fade older points
    public var fadeOlderPoints: Bool = true

    /// Dot size for dot style
    public var dotSize: Double = 4.0

    /// Spacing between dots (for dot style)
    public var dotSpacing: Int = 5

    /// Corner radius for the background
    public var cornerRadius: Double = 8.0

    /// Auto-scale to fit track (vs fixed scale)
    public var autoScale: Bool = true

    /// Padding from edges
    public var padding: Double = 20.0

    public init() {}

    // MARK: - Serialization

    public func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decode(from data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }

    // MARK: - Property Introspection

    public func properties() -> [ConfigurationProperty] {
        [
            .enumeration(
                key: "style",
                value: style,
                options: TracklineStyle.allCases,
                label: "Trail Style"
            ),
            .integer(
                key: "historyCount",
                value: historyCount,
                range: 0...500,
                label: "History Count (0=all)"
            ),
            .slider(
                key: "lineWidth",
                value: lineWidth,
                range: 1.0...10.0,
                step: 0.5,
                label: "Line Width"
            ),
            .color(
                key: "lineColor",
                value: lineColor,
                label: "Line Color"
            ),
            .color(
                key: "currentPositionColor",
                value: currentPositionColor,
                label: "Current Position Color"
            ),
            .color(
                key: "backgroundColor",
                value: backgroundColor,
                label: "Background Color"
            ),
            .boolean(
                key: "showCurrentPosition",
                value: showCurrentPosition,
                label: "Show Current Position"
            ),
            .boolean(
                key: "fadeOlderPoints",
                value: fadeOlderPoints,
                label: "Fade Older Points"
            ),
            .slider(
                key: "dotSize",
                value: dotSize,
                range: 2.0...10.0,
                step: 1.0,
                label: "Dot Size"
            ),
            .slider(
                key: "cornerRadius",
                value: cornerRadius,
                range: 0.0...20.0,
                step: 1.0,
                label: "Corner Radius"
            ),
            .boolean(
                key: "autoScale",
                value: autoScale,
                label: "Auto-scale to Fit"
            ),
            .slider(
                key: "padding",
                value: padding,
                range: 10.0...50.0,
                step: 5.0,
                label: "Padding"
            )
        ]
    }

    // MARK: - Property Updates

    public func updatingProperty(key: String, value: Any) -> TracklineConfiguration? {
        var updated = self

        switch key {
        case "style":
            if let enumValue = value as? TracklineStyle {
                updated.style = enumValue
            } else if let stringValue = value as? String, let style = TracklineStyle(rawValue: stringValue) {
                updated.style = style
            }
        case "historyCount":
            if let intValue = value as? Int {
                updated.historyCount = intValue
            } else if let doubleValue = value as? Double {
                updated.historyCount = Int(doubleValue)
            }
        case "lineWidth":
            if let doubleValue = value as? Double {
                updated.lineWidth = doubleValue
            }
        case "lineColor":
            if let colorValue = value as? SerializableColor {
                updated.lineColor = colorValue
            }
        case "currentPositionColor":
            if let colorValue = value as? SerializableColor {
                updated.currentPositionColor = colorValue
            }
        case "backgroundColor":
            if let colorValue = value as? SerializableColor {
                updated.backgroundColor = colorValue
            }
        case "showCurrentPosition":
            if let boolValue = value as? Bool {
                updated.showCurrentPosition = boolValue
            }
        case "fadeOlderPoints":
            if let boolValue = value as? Bool {
                updated.fadeOlderPoints = boolValue
            }
        case "dotSize":
            if let doubleValue = value as? Double {
                updated.dotSize = doubleValue
            }
        case "cornerRadius":
            if let doubleValue = value as? Double {
                updated.cornerRadius = doubleValue
            }
        case "autoScale":
            if let boolValue = value as? Bool {
                updated.autoScale = boolValue
            }
        case "padding":
            if let doubleValue = value as? Double {
                updated.padding = doubleValue
            }
        default:
            return nil // Unknown property
        }

        return updated
    }
}

// MARK: - Trackline Renderer

/// Renderer for the Trackline/Breadcrumb Trail instrument
public struct TracklineRenderer: InstrumentRenderer {

    public init() {}

    public func render(
        context: CGContext,
        renderContext: RenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        guard let config = configuration as? TracklineConfiguration else {
            return
        }

        // Get current point
        guard let currentPoint = dataProvider.currentPoint() else {
            renderNoData(context: context, renderContext: renderContext, config: config)
            return
        }

        // Get historical points
        let historyPoints: [TelemetryPoint]
        if config.historyCount > 0 {
            historyPoints = dataProvider.lastPoints(config.historyCount)
        } else {
            // Get all points up to current
            if let track = dataProvider.track(),
               let currentIndex = track.points.firstIndex(where: { $0.timestamp >= currentPoint.timestamp }) {
                historyPoints = Array(track.points[0...currentIndex])
            } else {
                historyPoints = []
            }
        }

        guard !historyPoints.isEmpty else {
            renderNoData(context: context, renderContext: renderContext, config: config)
            return
        }

        // Render background
        renderBackground(context: context, bounds: renderContext.bounds, config: config)

        // Calculate coordinate transform
        let transform = calculateTransform(
            points: historyPoints,
            bounds: renderContext.bounds,
            padding: config.padding
        )

        // Render trail based on style
        switch config.style {
        case .line:
            renderLinePath(
                context: context,
                points: historyPoints,
                transform: transform,
                config: config
            )
        case .dots:
            renderDots(
                context: context,
                points: historyPoints,
                transform: transform,
                config: config
            )
        case .gradient:
            renderGradientPath(
                context: context,
                points: historyPoints,
                transform: transform,
                config: config
            )
        case .speedColored:
            renderSpeedColoredPath(
                context: context,
                points: historyPoints,
                transform: transform,
                config: config
            )
        }

        // Render current position marker
        if config.showCurrentPosition {
            renderCurrentPosition(
                context: context,
                point: currentPoint,
                transform: transform,
                config: config
            )
        }
    }

    // MARK: - Private Rendering Methods

    private func renderBackground(context: CGContext, bounds: CGRect, config: TracklineConfiguration) {
        let path: CGPath

        if config.cornerRadius > 0 {
            path = CGPath(
                roundedRect: bounds,
                cornerWidth: config.cornerRadius,
                cornerHeight: config.cornerRadius,
                transform: nil
            )
        } else {
            path = CGPath(rect: bounds, transform: nil)
        }

        context.setFillColor(config.backgroundColor.cgColor)
        context.addPath(path)
        context.fillPath()
    }

    private func calculateTransform(
        points: [TelemetryPoint],
        bounds: CGRect,
        padding: Double
    ) -> (Double, Double) -> CGPoint {
        // Find bounding box
        var minLat = Double.infinity
        var maxLat = -Double.infinity
        var minLon = Double.infinity
        var maxLon = -Double.infinity

        for point in points {
            minLat = min(minLat, point.coordinate.latitude)
            maxLat = max(maxLat, point.coordinate.latitude)
            minLon = min(minLon, point.coordinate.longitude)
            maxLon = max(maxLon, point.coordinate.longitude)
        }

        // Add padding
        let paddedBounds = CGRect(
            x: bounds.minX + padding,
            y: bounds.minY + padding,
            width: bounds.width - 2 * padding,
            height: bounds.height - 2 * padding
        )

        let latRange = maxLat - minLat
        let lonRange = maxLon - minLon

        // Avoid division by zero
        let safeLatRange = latRange > 0 ? latRange : 0.0001
        let safeLonRange = lonRange > 0 ? lonRange : 0.0001

        return { lat, lon in
            let x = paddedBounds.minX + ((lon - minLon) / safeLonRange) * paddedBounds.width
            // Flip Y axis (screen coordinates are top-down)
            let y = paddedBounds.maxY - ((lat - minLat) / safeLatRange) * paddedBounds.height
            return CGPoint(x: x, y: y)
        }
    }

    private func renderLinePath(
        context: CGContext,
        points: [TelemetryPoint],
        transform: (Double, Double) -> CGPoint,
        config: TracklineConfiguration
    ) {
        guard points.count > 1 else { return }

        context.setStrokeColor(config.lineColor.cgColor)
        context.setLineWidth(config.lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        let firstPoint = transform(points[0].coordinate.latitude, points[0].coordinate.longitude)
        context.move(to: firstPoint)

        for point in points.dropFirst() {
            let cgPoint = transform(point.coordinate.latitude, point.coordinate.longitude)
            context.addLine(to: cgPoint)
        }

        context.strokePath()
    }

    private func renderDots(
        context: CGContext,
        points: [TelemetryPoint],
        transform: (Double, Double) -> CGPoint,
        config: TracklineConfiguration
    ) {
        context.setFillColor(config.lineColor.cgColor)

        for (index, point) in points.enumerated() {
            // Skip points based on spacing
            if config.dotSpacing > 1 && index % config.dotSpacing != 0 {
                continue
            }

            let cgPoint = transform(point.coordinate.latitude, point.coordinate.longitude)

            // Apply fade if enabled
            var alpha = 1.0
            if config.fadeOlderPoints {
                alpha = Double(index) / Double(max(points.count - 1, 1))
            }

            context.setFillColor(config.lineColor.withAlpha(alpha).cgColor)
            context.addArc(
                center: cgPoint,
                radius: config.dotSize / 2,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: false
            )
            context.fillPath()
        }
    }

    private func renderGradientPath(
        context: CGContext,
        points: [TelemetryPoint],
        transform: (Double, Double) -> CGPoint,
        config: TracklineConfiguration
    ) {
        guard points.count > 1 else { return }

        context.setLineWidth(config.lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Draw segments with increasing opacity
        for i in 0..<(points.count - 1) {
            let startPoint = transform(points[i].coordinate.latitude, points[i].coordinate.longitude)
            let endPoint = transform(points[i + 1].coordinate.latitude, points[i + 1].coordinate.longitude)

            var alpha = 1.0
            if config.fadeOlderPoints {
                alpha = Double(i) / Double(max(points.count - 1, 1))
                alpha = 0.2 + alpha * 0.8 // Min alpha 0.2
            }

            context.setStrokeColor(config.lineColor.withAlpha(alpha).cgColor)
            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.strokePath()
        }
    }

    private func renderSpeedColoredPath(
        context: CGContext,
        points: [TelemetryPoint],
        transform: (Double, Double) -> CGPoint,
        config: TracklineConfiguration
    ) {
        guard points.count > 1 else { return }

        // Find speed range
        let speeds = points.compactMap { $0.speed }
        guard !speeds.isEmpty else {
            // Fall back to regular line if no speed data
            renderLinePath(context: context, points: points, transform: transform, config: config)
            return
        }

        let minSpeed = speeds.min() ?? 0
        let maxSpeed = speeds.max() ?? 1
        let speedRange = maxSpeed - minSpeed

        context.setLineWidth(config.lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Draw segments with color based on speed
        for i in 0..<(points.count - 1) {
            let startPoint = transform(points[i].coordinate.latitude, points[i].coordinate.longitude)
            let endPoint = transform(points[i + 1].coordinate.latitude, points[i + 1].coordinate.longitude)

            // Get speed and normalize
            let speed = points[i].speed ?? minSpeed
            let normalizedSpeed = speedRange > 0 ? (speed - minSpeed) / speedRange : 0.5

            // Color gradient: blue (slow) to red (fast)
            let color = SerializableColor(
                red: normalizedSpeed,
                green: 0.3,
                blue: 1.0 - normalizedSpeed
            )

            context.setStrokeColor(color.cgColor)
            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.strokePath()
        }
    }

    private func renderCurrentPosition(
        context: CGContext,
        point: TelemetryPoint,
        transform: (Double, Double) -> CGPoint,
        config: TracklineConfiguration
    ) {
        let cgPoint = transform(point.coordinate.latitude, point.coordinate.longitude)

        // Draw outer circle
        context.setFillColor(config.currentPositionColor.withAlpha(0.3).cgColor)
        context.addArc(center: cgPoint, radius: 12, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        context.fillPath()

        // Draw inner circle
        context.setFillColor(config.currentPositionColor.cgColor)
        context.addArc(center: cgPoint, radius: 6, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        context.fillPath()

        // Draw white center
        context.setFillColor(SerializableColor.white.cgColor)
        context.addArc(center: cgPoint, radius: 2, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        context.fillPath()
    }

    private func renderNoData(
        context: CGContext,
        renderContext: RenderContext,
        config: TracklineConfiguration
    ) {
        // Render background
        renderBackground(context: context, bounds: renderContext.bounds, config: config)

        // Render "No Data" message
        #if canImport(AppKit)
        let font = NSFont.systemFont(ofSize: 18, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: config.lineColor.nsColor.withAlphaComponent(0.5)
        ]
        let message = "No Data"
        let attributedString = NSAttributedString(string: message, attributes: attributes)

        let textSize = attributedString.size()
        let textRect = CGRect(
            x: renderContext.bounds.midX - textSize.width / 2,
            y: renderContext.bounds.midY - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )

        attributedString.draw(in: textRect)
        #endif
    }
}

// MARK: - Trackline Plugin

/// Trackline/Breadcrumb Trail instrument plugin
///
/// Displays the historical path traveled with various visualization styles.
/// Supports continuous lines, dots, gradient fading, and speed-colored trails.
public struct TracklinePlugin: InstrumentPlugin {

    public init() {}

    // MARK: - Plugin Identity

    public static let metadata = PluginMetadata(
        id: "com.flighttrace.trackline",
        name: "Trackline/Trail",
        description: "Displays breadcrumb trail of traveled path",
        version: "1.0.0",
        category: .visual,
        iconName: "point.3.connected.trianglepath.dotted"
    )

    // MARK: - Data Requirements

    public static let dataDependencies: Set<TelemetryDataType> = [.coordinate, .timestamp, .speed]

    // MARK: - Default Properties

    public static let defaultSize = CGSize(width: 300, height: 200)

    public static let minimumSize = CGSize(width: 150, height: 100)

    // MARK: - Factory Methods

    public func createConfiguration() -> any InstrumentConfiguration {
        TracklineConfiguration()
    }

    public func createRenderer() -> any InstrumentRenderer {
        TracklineRenderer()
    }
}
