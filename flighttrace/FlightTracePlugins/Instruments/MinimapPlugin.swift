// MinimapPlugin.swift
// Minimap instrument plugin with track overlay (Metal)

import Foundation
import CoreGraphics
import CoreLocation
import Metal

#if canImport(AppKit)
import AppKit
import FlightTraceCore
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
            } else if let stringValue = value as? String {
                let normalized = stringValue.lowercased()
                if let style = MinimapStyle.allCases.first(where: { $0.rawValue.lowercased() == normalized || String(describing: $0).lowercased() == normalized }) {
                    updated.style = style
                }
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
            return nil
        }

        return updated
    }
}

// MARK: - Minimap Renderer

struct MinimapViewState {
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double
    let paddedBounds: CGRect
    let transform: (Double, Double) -> CGPoint
}

/// Renderer for the Minimap instrument
public struct MinimapRenderer: InstrumentRenderer {

    public init() {}

    private struct TileRenderResult {
        let total: Int
        let loaded: Int
        let inFlight: Int
        let failed: Int
        let timedOut: Int
        let lastError: String?
    }

    private nonisolated(unsafe) static var lastTileWarningTime: TimeInterval = 0
    private static let warningLock = NSLock()

    private nonisolated(unsafe) static var lastDebugLogTime: TimeInterval = 0
    private static let debugLock = NSLock()

    private nonisolated(unsafe) static var lastRefreshRequestTime: TimeInterval = 0
    private static let refreshLock = NSLock()

    public func render(
        context: MetalRenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        guard let config = configuration as? MinimapConfiguration else {
            return
        }

        guard let track = dataProvider.track(), !track.points.isEmpty else {
            renderNoData(context: context, config: config)
            return
        }

        guard let currentPoint = dataProvider.currentPoint() else {
            renderNoData(context: context, config: config)
            return
        }

        renderMap(context: context, track: track, currentPoint: currentPoint, config: config)
    }

    // MARK: - Private Rendering Methods

    private func renderMap(
        context: MetalRenderContext,
        track: TelemetryTrack,
        currentPoint: TelemetryPoint,
        config: MinimapConfiguration
    ) {
        let renderer = Metal2DRenderer.shared(for: context.device)
        let bounds = context.bounds

        renderBackground(renderer: renderer, bounds: bounds, config: config, context: context)
        applyScissor(bounds: bounds, context: context)

        let viewState = calculateViewState(track: track, currentPoint: currentPoint, bounds: bounds, config: config)

        debugLogStatus(config: config, viewState: viewState)

        if config.style == .standard {
            let result = renderTiles(renderer: renderer, viewState: viewState, zoomLevel: config.zoomLevel, context: context)
            if result.loaded == 0 {
                renderLoadingMessage(renderer: renderer, bounds: bounds, result: result, context: context)
            }
            if result.inFlight > 0 || result.failed > 0 || result.timedOut > 0 {
                printTileWarningIfNeeded(result: result)
            }
            if result.inFlight > 0 {
                requestMinimapRefresh()
            }
        }

        if config.showGrid && config.style == .simple {
            renderGrid(renderer: renderer, bounds: bounds, config: config, context: context)
        }

        renderTrack(
            renderer: renderer,
            track: track,
            currentPoint: currentPoint,
            transform: viewState.transform,
            config: config,
            context: context
        )

        if let startPoint = track.points.first {
            renderStartPosition(
                renderer: renderer,
                point: startPoint,
                transform: viewState.transform,
                config: config,
                context: context
            )
        }

        renderCurrentPosition(
            renderer: renderer,
            point: currentPoint,
            transform: viewState.transform,
            config: config,
            context: context
        )

        if config.showScale {
            renderScale(renderer: renderer, bounds: bounds, context: context)
        }

        resetScissor(context: context)
    }

    private func renderBackground(
        renderer: Metal2DRenderer,
        bounds: CGRect,
        config: MinimapConfiguration,
        context: MetalRenderContext
    ) {
        let borderWidth: CGFloat = 2
        let backgroundColor = config.backgroundColor
        renderer.drawRoundedRect(
            in: bounds,
            radius: config.cornerRadius,
            color: config.borderColor,
            renderContext: context
        )

        let inner = bounds.insetBy(dx: borderWidth, dy: borderWidth)
        renderer.drawRoundedRect(
            in: inner,
            radius: max(0, config.cornerRadius - borderWidth),
            color: backgroundColor,
            renderContext: context
        )
    }

    private func renderGrid(
        renderer: Metal2DRenderer,
        bounds: CGRect,
        config: MinimapConfiguration,
        context: MetalRenderContext
    ) {
        let gridSpacing: CGFloat = 40
        let lineWidth: CGFloat = 1

        var x = bounds.minX
        while x <= bounds.maxX {
            renderer.drawLine(
                from: CGPoint(x: x, y: bounds.minY),
                to: CGPoint(x: x, y: bounds.maxY),
                lineWidth: lineWidth,
                color: config.gridColor,
                renderContext: context
            )
            x += gridSpacing
        }

        var y = bounds.minY
        while y <= bounds.maxY {
            renderer.drawLine(
                from: CGPoint(x: bounds.minX, y: y),
                to: CGPoint(x: bounds.maxX, y: y),
                lineWidth: lineWidth,
                color: config.gridColor,
                renderContext: context
            )
            y += gridSpacing
        }
    }

    private func debugLogStatus(config: MinimapConfiguration, viewState: MinimapViewState) {
        let now = Date().timeIntervalSince1970
        MinimapRenderer.debugLock.lock()
        defer { MinimapRenderer.debugLock.unlock() }
        if now - MinimapRenderer.lastDebugLogTime < 2.0 { return }
        MinimapRenderer.lastDebugLogTime = now

//        let tileZoom = MinimapTileCache.tileZoom(for: config.zoomLevel)
//        let tileCount = MinimapTileCache.tilesForBounds(
//            minLat: viewState.minLat,
//            maxLat: viewState.maxLat,
//            minLon: viewState.minLon,
//            maxLon: viewState.maxLon,
//            zoom: tileZoom
//        ).count
    }

    private func calculateViewState(
        track: TelemetryTrack,
        currentPoint: TelemetryPoint,
        bounds: CGRect,
        config: MinimapConfiguration
    ) -> MinimapViewState {
        let padding: CGFloat = 20

        let centerLat: Double
        let centerLon: Double
        var minLat: Double
        var maxLat: Double
        var minLon: Double
        var maxLon: Double

        if config.followCurrentPosition {
            centerLat = currentPoint.coordinate.latitude
            centerLon = currentPoint.coordinate.longitude

            let latRange = 0.01 / config.zoomLevel
            let lonRange = 0.01 / config.zoomLevel

            minLat = centerLat - latRange
            maxLat = centerLat + latRange
            minLon = centerLon - lonRange
            maxLon = centerLon + lonRange
        } else if config.showFullTrack {
            minLat = track.points.map { $0.coordinate.latitude }.min() ?? 0
            maxLat = track.points.map { $0.coordinate.latitude }.max() ?? 0
            minLon = track.points.map { $0.coordinate.longitude }.min() ?? 0
            maxLon = track.points.map { $0.coordinate.longitude }.max() ?? 0

            let latCenter = (minLat + maxLat) / 2
            let lonCenter = (minLon + maxLon) / 2
            let latRange = (maxLat - minLat) / config.zoomLevel
            let lonRange = (maxLon - minLon) / config.zoomLevel

            minLat = latCenter - latRange / 2
            maxLat = latCenter + latRange / 2
            minLon = lonCenter - lonRange / 2
            maxLon = lonCenter + lonRange / 2
        } else {
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

        let transform: (Double, Double) -> CGPoint = { lat, lon in
            let x = paddedBounds.minX + ((lon - minLon) / safeLonRange) * paddedBounds.width
            let y = paddedBounds.maxY - ((lat - minLat) / safeLatRange) * paddedBounds.height
            return CGPoint(x: x, y: y)
        }

        return MinimapViewState(
            minLat: minLat,
            maxLat: maxLat,
            minLon: minLon,
            maxLon: maxLon,
            paddedBounds: paddedBounds,
            transform: transform
        )
    }

    private func renderTiles(
        renderer: Metal2DRenderer,
        viewState: MinimapViewState,
        zoomLevel: Double,
        context: MetalRenderContext
    ) -> TileRenderResult {
        let tileZoom = MinimapTileCache.tileZoom(for: zoomLevel)
        let tiles = MinimapTileCache.tilesForBounds(
            minLat: viewState.minLat,
            maxLat: viewState.maxLat,
            minLon: viewState.minLon,
            maxLon: viewState.maxLon,
            zoom: tileZoom
        )

        var drewAny = 0
        for key in tiles {
            guard let texture = MinimapTileCache.shared.texture(
                for: key,
                device: context.device
            ) else {
                continue
            }

            let rect = MinimapTileCache.tileRect(for: key, viewState: viewState)
            renderer.drawTexture(
                texture,
                in: rect,
                tintColor: .white,
                renderContext: context,
                //flipVertical: false
            )
            drewAny += 1
        }
        let status = MinimapTileCache.shared.status(for: tiles, device: context.device)
        return TileRenderResult(
            total: tiles.count,
            loaded: drewAny,
            inFlight: status.inFlight,
            failed: status.failed,
            timedOut: status.timedOut,
            lastError: status.lastError
        )
    }

    private func renderLoadingMessage(
        renderer: Metal2DRenderer,
        bounds: CGRect,
        result: TileRenderResult,
        context: MetalRenderContext
    ) {
        #if canImport(AppKit)
        let primaryText: String
        if result.timedOut > 0 {
            primaryText = "Map tiles timed out"
        } else if result.failed > 0 && result.inFlight == 0 {
            primaryText = "Map tiles failed to load"
        } else {
            primaryText = "Loading map tiles…"
        }

        var secondaryText = "Loaded \(result.loaded)/\(max(1, result.total)) • In flight \(result.inFlight)"
        if result.failed > 0 {
            secondaryText += " • Failed \(result.failed)"
        }
        if let error = result.lastError, !error.isEmpty {
            let trimmed = error.count > 60 ? String(error.prefix(60)) + "…" : error
            secondaryText = "Error: \(trimmed)"
        }

        let font = NSFont.systemFont(ofSize: 14, weight: .medium)
        if let (tex, size) = MetalTextRenderer.shared.texture(
            text: primaryText,
            font: font,
            color: SerializableColor.white.withAlpha(0.8),
            device: context.device,
            scale: max(1.0, context.scale),
            extraVerticalPadding: 4
        ) {
            let rect = CGRect(
                x: bounds.midX - size.width / 2,
                y: bounds.midY - size.height / 2 - 8,
                width: size.width,
                height: size.height
            )
            renderer.drawTexture(tex, in: rect, tintColor: .white, renderContext: context)
        }

        let secondaryFont = NSFont.systemFont(ofSize: 11, weight: .regular)
        if let (tex, size) = MetalTextRenderer.shared.texture(
            text: secondaryText,
            font: secondaryFont,
            color: SerializableColor.white.withAlpha(0.7),
            device: context.device,
            scale: max(1.0, context.scale),
            extraVerticalPadding: 3
        ) {
            let rect = CGRect(
                x: bounds.midX - size.width / 2,
                y: bounds.midY + 8,
                width: size.width,
                height: size.height
            )
            renderer.drawTexture(tex, in: rect, tintColor: .white, renderContext: context)
        }
        #endif
    }

    private func printTileWarningIfNeeded(result: TileRenderResult) {
        let now = Date().timeIntervalSince1970
        MinimapRenderer.warningLock.lock()
        defer { MinimapRenderer.warningLock.unlock() }
        if now - MinimapRenderer.lastTileWarningTime < 3.0 { return }
        MinimapRenderer.lastTileWarningTime = now
    }

    private func requestMinimapRefresh() {
        let now = Date().timeIntervalSince1970
        MinimapRenderer.refreshLock.lock()
        if now - MinimapRenderer.lastRefreshRequestTime < 0.2 {
            MinimapRenderer.refreshLock.unlock()
            return
        }
        MinimapRenderer.lastRefreshRequestTime = now
        MinimapRenderer.refreshLock.unlock()

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: MinimapTileCache.updateNotification, object: nil)
        }
    }

    private func renderTrack(
        renderer: Metal2DRenderer,
        track: TelemetryTrack,
        currentPoint: TelemetryPoint,
        transform: (Double, Double) -> CGPoint,
        config: MinimapConfiguration,
        context: MetalRenderContext
    ) {
        guard track.points.count > 1 else { return }

        let visiblePoints: [TelemetryPoint]
        if config.showFullTrack {
            if let currentIndex = track.points.firstIndex(where: { $0.timestamp >= currentPoint.timestamp }) {
                visiblePoints = Array(track.points[0...currentIndex])
            } else {
                visiblePoints = track.points
            }
        } else {
            visiblePoints = track.points
        }

        guard visiblePoints.count > 1 else { return }

        let lineWidth = CGFloat(config.trackLineWidth)
        var previous = transform(visiblePoints[0].coordinate.latitude, visiblePoints[0].coordinate.longitude)

        for point in visiblePoints.dropFirst() {
            let next = transform(point.coordinate.latitude, point.coordinate.longitude)
            renderer.drawLine(from: previous, to: next, lineWidth: lineWidth, color: config.trackColor, renderContext: context)
            previous = next
        }
    }

    private func renderStartPosition(
        renderer: Metal2DRenderer,
        point: TelemetryPoint,
        transform: (Double, Double) -> CGPoint,
        config: MinimapConfiguration,
        context: MetalRenderContext
    ) {
        let cgPoint = transform(point.coordinate.latitude, point.coordinate.longitude)
        renderer.drawCircle(center: cgPoint, radius: 6, color: config.startPositionColor, renderContext: context)
        renderer.drawCircleStroke(center: cgPoint, radius: 6, lineWidth: 2, color: .white, renderContext: context)
    }

    private func renderCurrentPosition(
        renderer: Metal2DRenderer,
        point: TelemetryPoint,
        transform: (Double, Double) -> CGPoint,
        config: MinimapConfiguration,
        context: MetalRenderContext
    ) {
        let cgPoint = transform(point.coordinate.latitude, point.coordinate.longitude)

        renderer.drawCircle(center: cgPoint, radius: 12, color: config.currentPositionColor.withAlpha(0.3), renderContext: context)
        renderer.drawCircle(center: cgPoint, radius: 8, color: config.currentPositionColor, renderContext: context)

        if config.showHeading, let heading = point.heading {
            let headingRadians = (heading - 90) * .pi / 180
            let indicatorLength: CGFloat = 15
            let endPoint = CGPoint(
                x: cgPoint.x + cos(headingRadians) * indicatorLength,
                y: cgPoint.y + sin(headingRadians) * indicatorLength
            )
            renderer.drawLine(from: cgPoint, to: endPoint, lineWidth: 2, color: .white, renderContext: context)
        }

        renderer.drawCircle(center: cgPoint, radius: 3, color: .white, renderContext: context)
    }

    private func renderScale(renderer: Metal2DRenderer, bounds: CGRect, context: MetalRenderContext) {
        #if canImport(AppKit)
        let scaleLength: CGFloat = 60
        let scaleY = bounds.maxY - 20
        let scaleStartX = bounds.minX + 20
        let scaleEndX = scaleStartX + scaleLength

        renderer.drawLine(
            from: CGPoint(x: scaleStartX, y: scaleY),
            to: CGPoint(x: scaleEndX, y: scaleY),
            lineWidth: 2,
            color: .white,
            renderContext: context
        )

        renderer.drawLine(
            from: CGPoint(x: scaleStartX, y: scaleY - 4),
            to: CGPoint(x: scaleStartX, y: scaleY + 4),
            lineWidth: 2,
            color: .white,
            renderContext: context
        )
        renderer.drawLine(
            from: CGPoint(x: scaleEndX, y: scaleY - 4),
            to: CGPoint(x: scaleEndX, y: scaleY + 4),
            lineWidth: 2,
            color: .white,
            renderContext: context
        )

        let scaleText = "1 km"
        let font = NSFont.systemFont(ofSize: 10, weight: .medium)
        if let (tex, size) = MetalTextRenderer.shared.texture(
            text: scaleText,
            font: font,
            color: .white,
            device: context.device,
            scale: max(1.0, context.scale),
            extraVerticalPadding: 2
        ) {
            let rect = CGRect(
                x: scaleStartX + scaleLength / 2 - size.width / 2,
                y: scaleY - size.height - 4,
                width: size.width,
                height: size.height
            )
            renderer.drawTexture(tex, in: rect, tintColor: .white, renderContext: context)
        }
        #endif
    }

    private func applyScissor(bounds: CGRect, context: MetalRenderContext) {
        let scale = max(1.0, context.scale)
        let viewportWidth = max(1.0, context.viewportSize.width * scale)
        let viewportHeight = max(1.0, context.viewportSize.height * scale)

        let x = max(0, Int(floor(bounds.minX * scale)))
        let y = max(0, Int(floor(bounds.minY * scale)))
        let width = max(0, Int(ceil(bounds.width * scale)))
        let height = max(0, Int(ceil(bounds.height * scale)))

        let clampedWidth = min(width, Int(viewportWidth) - x)
        let clampedHeight = min(height, Int(viewportHeight) - y)

        guard clampedWidth > 0, clampedHeight > 0 else { return }

        context.renderEncoder.setScissorRect(
            MTLScissorRect(
                x: x,
                y: y,
                width: clampedWidth,
                height: clampedHeight
            )
        )
    }

    private func resetScissor(context: MetalRenderContext) {
        let scale = max(1.0, context.scale)
        let width = Int(max(1.0, context.viewportSize.width * scale))
        let height = Int(max(1.0, context.viewportSize.height * scale))
        context.renderEncoder.setScissorRect(MTLScissorRect(x: 0, y: 0, width: width, height: height))
    }

    private func renderNoData(context: MetalRenderContext, config: MinimapConfiguration) {
        let renderer = Metal2DRenderer.shared(for: context.device)
        let bounds = context.bounds

        renderer.drawRoundedRect(
            in: bounds,
            radius: config.cornerRadius,
            color: config.backgroundColor,
            renderContext: context
        )

        #if canImport(AppKit)
        let font = NSFont.systemFont(ofSize: 18, weight: .medium)
        if let (tex, size) = MetalTextRenderer.shared.texture(
            text: "NO DATA",
            font: font,
            color: config.trackColor.withAlpha(0.5),
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

// MARK: - Minimap Plugin

/// Minimap instrument plugin
///
/// Displays a map with the GPS track overlay and current position.
public struct MinimapPlugin: InstrumentPlugin {

    public init() {}

    // MARK: - Plugin Identity

    public static let metadata = PluginMetadata(
        id: "com.flighttrace.minimap",
        name: "Minimap",
        description: "Displays map with track and current position",
        version: "0.6",
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
