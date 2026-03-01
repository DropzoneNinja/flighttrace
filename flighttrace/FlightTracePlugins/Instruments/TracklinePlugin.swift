// TracklinePlugin.swift
// Trackline/breadcrumb trail instrument plugin (Metal)

import Foundation
import CoreGraphics
import CoreLocation

#if canImport(AppKit)
import AppKit
import FlightTraceCore
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
            return nil
        }

        return updated
    }
}

// MARK: - Trackline Renderer

/// Renderer for the Trackline/Breadcrumb Trail instrument
public struct TracklineRenderer: InstrumentRenderer {

    public init() {}

    public func render(
        context: MetalRenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        guard let config = configuration as? TracklineConfiguration else {
            return
        }

        guard let currentPoint = dataProvider.currentPoint() else {
            renderNoData(context: context, config: config)
            return
        }

        let historyPoints: [TelemetryPoint]
        if config.historyCount > 0 {
            historyPoints = dataProvider.lastPoints(config.historyCount)
        } else {
            if let track = dataProvider.track(),
               let currentIndex = track.points.firstIndex(where: { $0.timestamp >= currentPoint.timestamp }) {
                historyPoints = Array(track.points[0...currentIndex])
            } else {
                historyPoints = []
            }
        }

        guard !historyPoints.isEmpty else {
            renderNoData(context: context, config: config)
            return
        }

        let renderer = Metal2DRenderer.shared(for: context.device)
        let bounds = context.bounds

        renderBackground(renderer: renderer, bounds: bounds, config: config, context: context)

        let transform = calculateTransform(
            points: historyPoints,
            bounds: bounds,
            padding: config.padding
        )

        switch config.style {
        case .line:
            renderLinePath(
                renderer: renderer,
                points: historyPoints,
                transform: transform,
                config: config,
                context: context
            )
        case .dots:
            renderDots(
                renderer: renderer,
                points: historyPoints,
                transform: transform,
                config: config,
                context: context
            )
        case .gradient:
            renderGradientPath(
                renderer: renderer,
                points: historyPoints,
                transform: transform,
                config: config,
                context: context
            )
        case .speedColored:
            renderSpeedColoredPath(
                renderer: renderer,
                points: historyPoints,
                transform: transform,
                config: config,
                context: context
            )
        }

        if config.showCurrentPosition {
            renderCurrentPosition(
                renderer: renderer,
                point: currentPoint,
                transform: transform,
                config: config,
                context: context
            )
        }
    }

    // MARK: - Private Rendering Methods

    private func renderBackground(
        renderer: Metal2DRenderer,
        bounds: CGRect,
        config: TracklineConfiguration,
        context: MetalRenderContext
    ) {
        renderer.drawRoundedRect(
            in: bounds,
            radius: config.cornerRadius,
            color: config.backgroundColor,
            renderContext: context
        )
    }

    private func calculateTransform(
        points: [TelemetryPoint],
        bounds: CGRect,
        padding: Double
    ) -> (Double, Double) -> CGPoint {
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

        let paddedBounds = CGRect(
            x: bounds.minX + padding,
            y: bounds.minY + padding,
            width: bounds.width - 2 * padding,
            height: bounds.height - 2 * padding
        )

        let latRange = maxLat - minLat
        let lonRange = maxLon - minLon

        let safeLatRange = latRange > 0 ? latRange : 0.0001
        let safeLonRange = lonRange > 0 ? lonRange : 0.0001

        return { lat, lon in
            let x = paddedBounds.minX + ((lon - minLon) / safeLonRange) * paddedBounds.width
            let y = paddedBounds.maxY - ((lat - minLat) / safeLatRange) * paddedBounds.height
            return CGPoint(x: x, y: y)
        }
    }

    private func renderLinePath(
        renderer: Metal2DRenderer,
        points: [TelemetryPoint],
        transform: (Double, Double) -> CGPoint,
        config: TracklineConfiguration,
        context: MetalRenderContext
    ) {
        guard points.count > 1 else { return }

        let lineWidth = CGFloat(config.lineWidth)
        var previous = transform(points[0].coordinate.latitude, points[0].coordinate.longitude)
        for point in points.dropFirst() {
            let next = transform(point.coordinate.latitude, point.coordinate.longitude)
            renderer.drawLine(from: previous, to: next, lineWidth: lineWidth, color: config.lineColor, renderContext: context)
            previous = next
        }
    }

    private func renderDots(
        renderer: Metal2DRenderer,
        points: [TelemetryPoint],
        transform: (Double, Double) -> CGPoint,
        config: TracklineConfiguration,
        context: MetalRenderContext
    ) {
        for (index, point) in points.enumerated() {
            if config.dotSpacing > 1 && index % config.dotSpacing != 0 {
                continue
            }

            let cgPoint = transform(point.coordinate.latitude, point.coordinate.longitude)

            var alpha = 1.0
            if config.fadeOlderPoints {
                alpha = Double(index) / Double(max(points.count - 1, 1))
            }

            renderer.drawCircle(
                center: cgPoint,
                radius: CGFloat(config.dotSize / 2),
                color: config.lineColor.withAlpha(alpha),
                renderContext: context
            )
        }
    }

    private func renderGradientPath(
        renderer: Metal2DRenderer,
        points: [TelemetryPoint],
        transform: (Double, Double) -> CGPoint,
        config: TracklineConfiguration,
        context: MetalRenderContext
    ) {
        guard points.count > 1 else { return }

        let lineWidth = CGFloat(config.lineWidth)

        for i in 0..<(points.count - 1) {
            let startPoint = transform(points[i].coordinate.latitude, points[i].coordinate.longitude)
            let endPoint = transform(points[i + 1].coordinate.latitude, points[i + 1].coordinate.longitude)

            var alpha = 1.0
            if config.fadeOlderPoints {
                alpha = Double(i) / Double(max(points.count - 1, 1))
                alpha = 0.2 + alpha * 0.8
            }

            renderer.drawLine(
                from: startPoint,
                to: endPoint,
                lineWidth: lineWidth,
                color: config.lineColor.withAlpha(alpha),
                renderContext: context
            )
        }
    }

    private func renderSpeedColoredPath(
        renderer: Metal2DRenderer,
        points: [TelemetryPoint],
        transform: (Double, Double) -> CGPoint,
        config: TracklineConfiguration,
        context: MetalRenderContext
    ) {
        guard points.count > 1 else { return }

        let speeds = points.compactMap { $0.speed }
        guard !speeds.isEmpty else {
            renderLinePath(renderer: renderer, points: points, transform: transform, config: config, context: context)
            return
        }

        let minSpeed = speeds.min() ?? 0
        let maxSpeed = speeds.max() ?? 1
        let speedRange = maxSpeed - minSpeed

        let lineWidth = CGFloat(config.lineWidth)

        for i in 0..<(points.count - 1) {
            let startPoint = transform(points[i].coordinate.latitude, points[i].coordinate.longitude)
            let endPoint = transform(points[i + 1].coordinate.latitude, points[i + 1].coordinate.longitude)

            let speed = points[i].speed ?? minSpeed
            let normalizedSpeed = speedRange > 0 ? (speed - minSpeed) / speedRange : 0.5

            let color = SerializableColor(
                red: normalizedSpeed,
                green: 0.3,
                blue: 1.0 - normalizedSpeed
            )

            renderer.drawLine(
                from: startPoint,
                to: endPoint,
                lineWidth: lineWidth,
                color: color,
                renderContext: context
            )
        }
    }

    private func renderCurrentPosition(
        renderer: Metal2DRenderer,
        point: TelemetryPoint,
        transform: (Double, Double) -> CGPoint,
        config: TracklineConfiguration,
        context: MetalRenderContext
    ) {
        let cgPoint = transform(point.coordinate.latitude, point.coordinate.longitude)

        renderer.drawCircle(
            center: cgPoint,
            radius: 12,
            color: config.currentPositionColor.withAlpha(0.3),
            renderContext: context
        )
        renderer.drawCircle(
            center: cgPoint,
            radius: 6,
            color: config.currentPositionColor,
            renderContext: context
        )
        renderer.drawCircle(
            center: cgPoint,
            radius: 2,
            color: .white,
            renderContext: context
        )
    }

    private func renderNoData(context: MetalRenderContext, config: TracklineConfiguration) {
        let renderer = Metal2DRenderer.shared(for: context.device)
        let bounds = context.bounds
        renderBackground(renderer: renderer, bounds: bounds, config: config, context: context)

        #if canImport(AppKit)
        let font = NSFont.systemFont(ofSize: 18, weight: .medium)
        if let (tex, size) = MetalTextRenderer.shared.texture(
            text: "NO DATA",
            font: font,
            color: config.lineColor.withAlpha(0.5),
            device: context.device,
            scale: max(1.0, context.scale),
            extraVerticalPadding: 4
        ) {
            let rect = CGRect(
                x: bounds.midX - size.width / 2,
                y: bounds.midY - size.height / 2,
                width: size.width,
                height: size.height
            )
            renderer.drawTexture(tex, in: rect, tintColor: .white, renderContext: context)
        }
        #endif
    }
}

// MARK: - Trackline Plugin

/// Trackline/Breadcrumb Trail instrument plugin
///
/// Displays the historical path traveled with various visualization styles.
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
