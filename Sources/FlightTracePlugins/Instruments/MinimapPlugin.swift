// MinimapPlugin.swift
// Minimap instrument plugin with track overlay

import Foundation
import CoreGraphics
import CoreLocation
@preconcurrency import FlightTraceCore

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Minimap Style

/// Display style for the minimap
public enum MinimapStyle: String, Sendable, Codable, CaseIterable, Equatable {
    case terrain = "Terrain"
    case satellite = "Satellite"
    case standard = "Standard"
    case simple = "Simple"
}

// MARK: - Minimap Configuration

/// Configuration for the Minimap instrument
public struct MinimapConfiguration: InstrumentConfiguration, Codable {
    public var id = UUID()

    /// Map display style
    public var style: MinimapStyle = .simple

    /// Zoom level (higher = more zoomed in)
    public var zoomLevel: Double = 1.0

    /// Whether to show the entire track
    public var showFullTrack: Bool = true

    /// Whether to follow current position
    public var followCurrentPosition: Bool = true

    /// Color for the track line
    public var trackColor: SerializableColor = SerializableColor(red: 0.2, green: 0.6, blue: 1.0)

    /// Color for the current position marker
    public var currentPositionColor: SerializableColor = SerializableColor(red: 1.0, green: 0.3, blue: 0.3)

    /// Color for start position marker
    public var startPositionColor: SerializableColor = SerializableColor(red: 0.3, green: 1.0, blue: 0.3)

    /// Background color (for simple style)
    public var backgroundColor: SerializableColor = SerializableColor(red: 0.15, green: 0.2, blue: 0.15)

    /// Grid color (for simple style)
    public var gridColor: SerializableColor = SerializableColor.white.withAlpha(0.1)

    /// Border color
    public var borderColor: SerializableColor = SerializableColor.white.withAlpha(0.3)

    /// Track line width
    public var trackLineWidth: Double = 2.0

    /// Whether to show heading indicator
    public var showHeading: Bool = true

    /// Whether to show scale bar
    public var showScale: Bool = true

    /// Corner radius for the background
    public var cornerRadius: Double = 8.0

    /// Whether to show grid (for simple style)
    public var showGrid: Bool = true

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
                options: MinimapStyle.allCases,
                label: "Map Style"
            ),
            .slider(
                key: "zoomLevel",
                value: zoomLevel,
                range: 0.1...3.0,
                step: 0.1,
                label: "Zoom Level"
            ),
            .boolean(
                key: "showFullTrack",
                value: showFullTrack,
                label: "Show Full Track"
            ),
            .boolean(
                key: "followCurrentPosition",
                value: followCurrentPosition,
                label: "Follow Current Position"
            ),
            .color(
                key: "trackColor",
                value: trackColor,
                label: "Track Color"
            ),
            .color(
                key: "currentPositionColor",
                value: currentPositionColor,
                label: "Current Position Color"
            ),
            .color(
                key: "startPositionColor",
                value: startPositionColor,
                label: "Start Position Color"
            ),
            .color(
                key: "backgroundColor",
                value: backgroundColor,
                label: "Background Color"
            ),
            .color(
                key: "gridColor",
                value: gridColor,
                label: "Grid Color"
            ),
            .color(
                key: "borderColor",
                value: borderColor,
                label: "Border Color"
            ),
            .slider(
                key: "trackLineWidth",
                value: trackLineWidth,
                range: 1.0...5.0,
                step: 0.5,
                label: "Track Line Width"
            ),
            .boolean(
                key: "showHeading",
                value: showHeading,
                label: "Show Heading"
            ),
            .boolean(
                key: "showScale",
                value: showScale,
                label: "Show Scale Bar"
            ),
            .boolean(
                key: "showGrid",
                value: showGrid,
                label: "Show Grid"
            ),
            .slider(
                key: "cornerRadius",
                value: cornerRadius,
                range: 0.0...20.0,
                step: 1.0,
                label: "Corner Radius"
            )
        ]
    }

    // MARK: - Property Updates

    public func updatingProperty(key: String, value: Any) -> MinimapConfiguration? {
        var updated = self

        switch key {
        case "style":
            if let enumValue = value as? MinimapStyle {
                updated.style = enumValue
            } else if let stringValue = value as? String, let style = MinimapStyle(rawValue: stringValue) {
                updated.style = style
            }
        case "zoomLevel":
            if let doubleValue = value as? Double {
                updated.zoomLevel = doubleValue
            }
        case "showFullTrack":
            if let boolValue = value as? Bool {
                updated.showFullTrack = boolValue
            }
        case "followCurrentPosition":
            if let boolValue = value as? Bool {
                updated.followCurrentPosition = boolValue
            }
        case "trackColor":
            if let colorValue = value as? SerializableColor {
                updated.trackColor = colorValue
            }
        case "currentPositionColor":
            if let colorValue = value as? SerializableColor {
                updated.currentPositionColor = colorValue
            }
        case "startPositionColor":
            if let colorValue = value as? SerializableColor {
                updated.startPositionColor = colorValue
            }
        case "backgroundColor":
            if let colorValue = value as? SerializableColor {
                updated.backgroundColor = colorValue
            }
        case "gridColor":
            if let colorValue = value as? SerializableColor {
                updated.gridColor = colorValue
            }
        case "borderColor":
            if let colorValue = value as? SerializableColor {
                updated.borderColor = colorValue
            }
        case "trackLineWidth":
            if let doubleValue = value as? Double {
                updated.trackLineWidth = doubleValue
            }
        case "showHeading":
            if let boolValue = value as? Bool {
                updated.showHeading = boolValue
            }
        case "showScale":
            if let boolValue = value as? Bool {
                updated.showScale = boolValue
            }
        case "showGrid":
            if let boolValue = value as? Bool {
                updated.showGrid = boolValue
            }
        case "cornerRadius":
            if let doubleValue = value as? Double {
                updated.cornerRadius = doubleValue
            }
        default:
            return nil // Unknown property
        }

        return updated
    }
}

// MARK: - Minimap Renderer

/// Renderer for the Minimap instrument
public struct MinimapRenderer: InstrumentRenderer {

    public init() {}

    public func render(
        context: CGContext,
        renderContext: RenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        guard let config = configuration as? MinimapConfiguration else {
            return
        }

        // Get track data
        guard let track = dataProvider.track(),
              !track.points.isEmpty else {
            renderNoData(context: context, renderContext: renderContext, config: config)
            return
        }

        guard let currentPoint = dataProvider.currentPoint() else {
            renderNoData(context: context, renderContext: renderContext, config: config)
            return
        }

        // Render based on style
        switch config.style {
        case .simple:
            renderSimpleMap(
                context: context,
                bounds: renderContext.bounds,
                track: track,
                currentPoint: currentPoint,
                config: config
            )
        case .terrain, .satellite, .standard:
            // For now, render as simple map
            // TODO: Integrate actual map tiles or MapKit rendering
            renderSimpleMap(
                context: context,
                bounds: renderContext.bounds,
                track: track,
                currentPoint: currentPoint,
                config: config
            )
        }
    }

    // MARK: - Private Rendering Methods

    private func renderSimpleMap(
        context: CGContext,
        bounds: CGRect,
        track: TelemetryTrack,
        currentPoint: TelemetryPoint,
        config: MinimapConfiguration
    ) {
        // Render background
        renderBackground(context: context, bounds: bounds, config: config)

        // Calculate transform
        let transform = calculateTransform(
            track: track,
            currentPoint: currentPoint,
            bounds: bounds,
            config: config
        )

        // Render grid if enabled
        if config.showGrid {
            renderGrid(context: context, bounds: bounds, config: config)
        }

        // Render track
        renderTrack(
            context: context,
            track: track,
            currentPoint: currentPoint,
            transform: transform,
            config: config
        )

        // Render start position
        if let startPoint = track.points.first {
            renderStartPosition(
                context: context,
                point: startPoint,
                transform: transform,
                config: config
            )
        }

        // Render current position
        renderCurrentPosition(
            context: context,
            point: currentPoint,
            transform: transform,
            config: config
        )

        // Render border
        renderBorder(context: context, bounds: bounds, config: config)

        // Render scale if enabled
        if config.showScale {
            renderScale(context: context, bounds: bounds, config: config)
        }
    }

    private func renderBackground(context: CGContext, bounds: CGRect, config: MinimapConfiguration) {
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

    private func renderGrid(context: CGContext, bounds: CGRect, config: MinimapConfiguration) {
        context.setStrokeColor(config.gridColor.cgColor)
        context.setLineWidth(1)

        let gridSpacing: CGFloat = 40

        // Vertical lines
        var x = bounds.minX
        while x <= bounds.maxX {
            context.move(to: CGPoint(x: x, y: bounds.minY))
            context.addLine(to: CGPoint(x: x, y: bounds.maxY))
            x += gridSpacing
        }

        // Horizontal lines
        var y = bounds.minY
        while y <= bounds.maxY {
            context.move(to: CGPoint(x: bounds.minX, y: y))
            context.addLine(to: CGPoint(x: bounds.maxX, y: y))
            y += gridSpacing
        }

        context.strokePath()
    }

    private func calculateTransform(
        track: TelemetryTrack,
        currentPoint: TelemetryPoint,
        bounds: CGRect,
        config: MinimapConfiguration
    ) -> (Double, Double) -> CGPoint {
        let padding: CGFloat = 20

        // Determine center and bounds
        let centerLat: Double
        let centerLon: Double
        var minLat: Double
        var maxLat: Double
        var minLon: Double
        var maxLon: Double

        if config.followCurrentPosition {
            // Center on current position
            centerLat = currentPoint.coordinate.latitude
            centerLon = currentPoint.coordinate.longitude

            // Calculate visible range based on zoom
            let latRange = 0.01 / config.zoomLevel
            let lonRange = 0.01 / config.zoomLevel

            minLat = centerLat - latRange
            maxLat = centerLat + latRange
            minLon = centerLon - lonRange
            maxLon = centerLon + lonRange
        } else if config.showFullTrack {
            // Show entire track
            minLat = track.points.map { $0.coordinate.latitude }.min() ?? 0
            maxLat = track.points.map { $0.coordinate.latitude }.max() ?? 0
            minLon = track.points.map { $0.coordinate.longitude }.min() ?? 0
            maxLon = track.points.map { $0.coordinate.longitude }.max() ?? 0

            // Apply zoom
            let latCenter = (minLat + maxLat) / 2
            let lonCenter = (minLon + maxLon) / 2
            let latRange = (maxLat - minLat) / config.zoomLevel
            let lonRange = (maxLon - minLon) / config.zoomLevel

            minLat = latCenter - latRange / 2
            maxLat = latCenter + latRange / 2
            minLon = lonCenter - lonRange / 2
            maxLon = lonCenter + lonRange / 2
        } else {
            // Default to full track
            minLat = track.points.map { $0.coordinate.latitude }.min() ?? 0
            maxLat = track.points.map { $0.coordinate.latitude }.max() ?? 0
            minLon = track.points.map { $0.coordinate.longitude }.min() ?? 0
            maxLon = track.points.map { $0.coordinate.longitude }.max() ?? 0
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

    private func renderTrack(
        context: CGContext,
        track: TelemetryTrack,
        currentPoint: TelemetryPoint,
        transform: (Double, Double) -> CGPoint,
        config: MinimapConfiguration
    ) {
        guard track.points.count > 1 else { return }

        // Determine which points to show
        let visiblePoints: [TelemetryPoint]
        if config.showFullTrack {
            // Show all points up to current
            if let currentIndex = track.points.firstIndex(where: { $0.timestamp >= currentPoint.timestamp }) {
                visiblePoints = Array(track.points[0...currentIndex])
            } else {
                visiblePoints = track.points
            }
        } else {
            visiblePoints = track.points
        }

        guard visiblePoints.count > 1 else { return }

        context.setStrokeColor(config.trackColor.cgColor)
        context.setLineWidth(config.trackLineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        let firstPoint = transform(
            visiblePoints[0].coordinate.latitude,
            visiblePoints[0].coordinate.longitude
        )
        context.move(to: firstPoint)

        for point in visiblePoints.dropFirst() {
            let cgPoint = transform(point.coordinate.latitude, point.coordinate.longitude)
            context.addLine(to: cgPoint)
        }

        context.strokePath()
    }

    private func renderStartPosition(
        context: CGContext,
        point: TelemetryPoint,
        transform: (Double, Double) -> CGPoint,
        config: MinimapConfiguration
    ) {
        let cgPoint = transform(point.coordinate.latitude, point.coordinate.longitude)

        // Draw green circle for start
        context.setFillColor(config.startPositionColor.cgColor)
        context.addArc(center: cgPoint, radius: 6, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        context.fillPath()

        // Draw white border
        context.setStrokeColor(SerializableColor.white.cgColor)
        context.setLineWidth(2)
        context.addArc(center: cgPoint, radius: 6, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        context.strokePath()
    }

    private func renderCurrentPosition(
        context: CGContext,
        point: TelemetryPoint,
        transform: (Double, Double) -> CGPoint,
        config: MinimapConfiguration
    ) {
        let cgPoint = transform(point.coordinate.latitude, point.coordinate.longitude)

        // Draw outer circle
        context.setFillColor(config.currentPositionColor.withAlpha(0.3).cgColor)
        context.addArc(center: cgPoint, radius: 12, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        context.fillPath()

        // Draw main circle
        context.setFillColor(config.currentPositionColor.cgColor)
        context.addArc(center: cgPoint, radius: 8, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        context.fillPath()

        // Draw heading indicator if enabled
        if config.showHeading, let heading = point.heading {
            let headingRadians = (heading - 90) * .pi / 180
            let indicatorLength: CGFloat = 15
            let endPoint = CGPoint(
                x: cgPoint.x + cos(headingRadians) * indicatorLength,
                y: cgPoint.y + sin(headingRadians) * indicatorLength
            )

            context.setStrokeColor(SerializableColor.white.cgColor)
            context.setLineWidth(2)
            context.move(to: cgPoint)
            context.addLine(to: endPoint)
            context.strokePath()
        }

        // Draw white center
        context.setFillColor(SerializableColor.white.cgColor)
        context.addArc(center: cgPoint, radius: 3, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        context.fillPath()
    }

    private func renderBorder(context: CGContext, bounds: CGRect, config: MinimapConfiguration) {
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

        context.setStrokeColor(config.borderColor.cgColor)
        context.setLineWidth(2)
        context.addPath(path)
        context.strokePath()
    }

    private func renderScale(context: CGContext, bounds: CGRect, config: MinimapConfiguration) {
        #if canImport(AppKit)
        // Render a simple scale bar in bottom-left corner
        let scaleLength: CGFloat = 60
        let scaleY = bounds.maxY - 20
        let scaleStartX = bounds.minX + 20
        let scaleEndX = scaleStartX + scaleLength

        // Draw scale bar
        context.setStrokeColor(SerializableColor.white.cgColor)
        context.setLineWidth(2)
        context.move(to: CGPoint(x: scaleStartX, y: scaleY))
        context.addLine(to: CGPoint(x: scaleEndX, y: scaleY))
        context.strokePath()

        // Draw end caps
        context.move(to: CGPoint(x: scaleStartX, y: scaleY - 4))
        context.addLine(to: CGPoint(x: scaleStartX, y: scaleY + 4))
        context.move(to: CGPoint(x: scaleEndX, y: scaleY - 4))
        context.addLine(to: CGPoint(x: scaleEndX, y: scaleY + 4))
        context.strokePath()

        // Draw scale label (approximate)
        let scaleText = "1 km"
        let font = NSFont.systemFont(ofSize: 10, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let attributedString = NSAttributedString(string: scaleText, attributes: attributes)
        let textSize = attributedString.size()
        let textRect = CGRect(
            x: scaleStartX + scaleLength / 2 - textSize.width / 2,
            y: scaleY - textSize.height - 4,
            width: textSize.width,
            height: textSize.height
        )
        attributedString.draw(in: textRect)
        #endif
    }

    private func renderNoData(
        context: CGContext,
        renderContext: RenderContext,
        config: MinimapConfiguration
    ) {
        // Render background
        renderBackground(context: context, bounds: renderContext.bounds, config: config)

        // Render "No Data" message
        #if canImport(AppKit)
        let font = NSFont.systemFont(ofSize: 18, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: config.trackColor.nsColor.withAlphaComponent(0.5)
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

// MARK: - Minimap Plugin

/// Minimap instrument plugin
///
/// Displays a map with the GPS track overlay and current position.
/// Supports various map styles and zoom levels.
public struct MinimapPlugin: InstrumentPlugin {

    public init() {}

    // MARK: - Plugin Identity

    public static let metadata = PluginMetadata(
        id: "com.flighttrace.minimap",
        name: "Minimap",
        description: "Displays map with track and current position",
        version: "1.0.0",
        category: .map,
        iconName: "map.fill"
    )

    // MARK: - Data Requirements

    public static let dataDependencies: Set<TelemetryDataType> = [.coordinate, .heading, .timestamp]

    // MARK: - Default Properties

    public static let defaultSize = CGSize(width: 300, height: 300)

    public static let minimumSize = CGSize(width: 150, height: 150)

    // MARK: - Factory Methods

    public func createConfiguration() -> any InstrumentConfiguration {
        MinimapConfiguration()
    }

    public func createRenderer() -> any InstrumentRenderer {
        MinimapRenderer()
    }
}
