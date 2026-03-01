// HeadingPlugin.swift
// Heading/compass instrument plugin (Metal)

import Foundation
import CoreGraphics

#if canImport(AppKit)
import AppKit
import FlightTraceCore
#endif

// MARK: - Heading Style

/// Display style for heading/compass
public enum HeadingStyle: String, Sendable, Codable, CaseIterable, Equatable {
    case digital = "Digital"
    case compass = "Compass"
    case arc = "Arc"
}

// MARK: - Heading Configuration

/// Configuration for the Heading/Compass instrument
public struct HeadingConfiguration: InstrumentConfiguration, Codable {
    public var id = UUID()

    /// Display style
    public var style: HeadingStyle = .compass

    /// Whether to show cardinal directions (N, S, E, W)
    public var showCardinalDirections: Bool = true

    /// Whether to show degree value
    public var showDegrees: Bool = true

    /// Text color for heading value
    public var textColor: SerializableColor = .white

    /// Color for compass needle
    public var needleColor: SerializableColor = SerializableColor(red: 1.0, green: 0.3, blue: 0.3)

    /// Background color
    public var backgroundColor: SerializableColor = SerializableColor.black.withAlpha(0.7)

    /// Font size for the heading value
    public var fontSize: Double = 48.0

    /// Font size for cardinal directions
    public var cardinalFontSize: Double = 24.0

    /// Corner radius for the background
    public var cornerRadius: Double = 8.0

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
                options: HeadingStyle.allCases,
                label: "Display Style"
            ),
            .boolean(
                key: "showCardinalDirections",
                value: showCardinalDirections,
                label: "Show Cardinal Directions"
            ),
            .boolean(
                key: "showDegrees",
                value: showDegrees,
                label: "Show Degrees"
            ),
            .color(
                key: "textColor",
                value: textColor,
                label: "Text Color"
            ),
            .color(
                key: "needleColor",
                value: needleColor,
                label: "Needle Color"
            ),
            .color(
                key: "backgroundColor",
                value: backgroundColor,
                label: "Background Color"
            ),
            .slider(
                key: "fontSize",
                value: fontSize,
                range: 24.0...96.0,
                step: 4.0,
                label: "Font Size"
            ),
            .slider(
                key: "cardinalFontSize",
                value: cardinalFontSize,
                range: 12.0...48.0,
                step: 2.0,
                label: "Cardinal Font Size"
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

    public func updatingProperty(key: String, value: Any) -> HeadingConfiguration? {
        var updated = self

        switch key {
        case "style":
            if let enumValue = value as? HeadingStyle {
                updated.style = enumValue
            } else if let stringValue = value as? String, let style = HeadingStyle(rawValue: stringValue) {
                updated.style = style
            }
        case "showCardinalDirections":
            if let boolValue = value as? Bool {
                updated.showCardinalDirections = boolValue
            }
        case "showDegrees":
            if let boolValue = value as? Bool {
                updated.showDegrees = boolValue
            }
        case "textColor":
            if let colorValue = value as? SerializableColor {
                updated.textColor = colorValue
            }
        case "needleColor":
            if let colorValue = value as? SerializableColor {
                updated.needleColor = colorValue
            }
        case "backgroundColor":
            if let colorValue = value as? SerializableColor {
                updated.backgroundColor = colorValue
            }
        case "fontSize":
            if let doubleValue = value as? Double {
                updated.fontSize = doubleValue
            }
        case "cardinalFontSize":
            if let doubleValue = value as? Double {
                updated.cardinalFontSize = doubleValue
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

// MARK: - Heading Renderer (Metal)

public struct HeadingRenderer: InstrumentRenderer {

    public init() {}

    public func render(
        context: MetalRenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        guard let config = configuration as? HeadingConfiguration else {
            return
        }

        let renderer = Metal2DRenderer.shared(for: context.device)

        // Background
        renderer.drawRoundedRect(
            in: context.bounds,
            radius: CGFloat(config.cornerRadius),
            color: config.backgroundColor,
            renderContext: context
        )

        guard let point = dataProvider.currentPoint(),
              let heading = point.heading else {
            renderNoData(context: context, config: config, renderer: renderer)
            return
        }

        switch config.style {
        case .digital:
            renderDigital(context: context, heading: heading, config: config, renderer: renderer)
        case .compass, .arc:
            renderCompass(context: context, heading: heading, config: config, renderer: renderer)
        }
    }

    private func cardinalDirection(for heading: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((heading + 22.5) / 45.0) % 8
        return directions[index]
    }

    private func renderDigital(
        context: MetalRenderContext,
        heading: Double,
        config: HeadingConfiguration,
        renderer: Metal2DRenderer
    ) {
        #if canImport(AppKit)
        let scale = max(1.0, context.scale)
        var yOffset: CGFloat = 0

        if config.showCardinalDirections {
            let direction = cardinalDirection(for: heading)
            let font = NSFont.systemFont(ofSize: config.cardinalFontSize, weight: .bold)
            if let (texture, size) = MetalTextRenderer.shared.texture(
                text: direction,
                font: font,
                color: config.textColor,
                device: context.device,
                scale: scale,
                extraVerticalPadding: config.cardinalFontSize * 0.2
            ) {
                let rect = CGRect(
                    x: context.bounds.midX - size.width / 2,
                    y: context.bounds.midY - CGFloat(config.fontSize) / 2 - size.height - 5,
                    width: size.width,
                    height: size.height
                )
                renderer.drawTexture(texture, in: rect, tintColor: .white, renderContext: context)
                yOffset = 10
            }
        }

        if config.showDegrees {
            let headingText = String(format: "%03.0f°", heading)
            let font = NSFont.monospacedDigitSystemFont(ofSize: config.fontSize, weight: .bold)
            if let (texture, size) = MetalTextRenderer.shared.texture(
                text: headingText,
                font: font,
                color: config.textColor,
                device: context.device,
                scale: scale,
                extraVerticalPadding: config.fontSize * 0.15
            ) {
                let rect = CGRect(
                    x: context.bounds.midX - size.width / 2,
                    y: context.bounds.midY - size.height / 2 + yOffset,
                    width: size.width,
                    height: size.height
                )
                renderer.drawTexture(texture, in: rect, tintColor: .white, renderContext: context)
            }
        }
        #endif
    }

    private func renderCompass(
        context: MetalRenderContext,
        heading: Double,
        config: HeadingConfiguration,
        renderer: Metal2DRenderer
    ) {
        let center = CGPoint(x: context.bounds.midX, y: context.bounds.midY)
        let radius = min(context.bounds.width, context.bounds.height) * 0.35

        renderer.drawCircleStroke(
            center: center,
            radius: radius,
            lineWidth: 2,
            color: config.textColor.withAlpha(0.3),
            renderContext: context
        )

        #if canImport(AppKit)
        let scale = max(1.0, context.scale)
        if config.showCardinalDirections {
            let directions = ["N", "E", "S", "W"]
            let angles: [Double] = [0, 90, 180, 270]
            let font = NSFont.systemFont(ofSize: config.cardinalFontSize * 0.7, weight: .bold)
            for (direction, angle) in zip(directions, angles) {
                let radians = (angle - 90) * .pi / 180
                let x = center.x + cos(radians) * (radius + 15)
                let y = center.y + sin(radians) * (radius + 15)
                if let (texture, size) = MetalTextRenderer.shared.texture(
                    text: direction,
                    font: font,
                    color: config.textColor,
                    device: context.device,
                    scale: scale,
                    extraVerticalPadding: config.cardinalFontSize * 0.2
                ) {
                    let rect = CGRect(
                        x: x - size.width / 2,
                        y: y - size.height / 2,
                        width: size.width,
                        height: size.height
                    )
                    renderer.drawTexture(texture, in: rect, tintColor: .white, renderContext: context)
                }
            }
        }
        #endif

        let headingRadians = (heading - 90) * .pi / 180
        let needleLength = radius * 0.8
        let needleEnd = CGPoint(
            x: center.x + cos(headingRadians) * needleLength,
            y: center.y + sin(headingRadians) * needleLength
        )

        renderer.drawLine(
            from: center,
            to: needleEnd,
            lineWidth: 3,
            color: config.needleColor,
            renderContext: context
        )

        renderer.drawCircle(
            center: center,
            radius: 4,
            color: config.needleColor,
            renderContext: context
        )

        if config.showDegrees {
            #if canImport(AppKit)
            let scale = max(1.0, context.scale)
            let headingText = String(format: "%03.0f°", heading)
            let font = NSFont.monospacedDigitSystemFont(ofSize: config.fontSize * 0.4, weight: .bold)
            if let (texture, size) = MetalTextRenderer.shared.texture(
                text: headingText,
                font: font,
                color: config.textColor,
                device: context.device,
                scale: scale,
                extraVerticalPadding: config.fontSize * 0.1
            ) {
                let rect = CGRect(
                    x: context.bounds.midX - size.width / 2,
                    y: center.y + radius * 0.35 - 22,
                    width: size.width,
                    height: size.height
                )
                renderer.drawTexture(texture, in: rect, tintColor: .white, renderContext: context)
            }
            #endif
        }
    }

    private func renderNoData(
        context: MetalRenderContext,
        config: HeadingConfiguration,
        renderer: Metal2DRenderer
    ) {
        #if canImport(AppKit)
        let scale = max(1.0, context.scale)
        let font = NSFont.systemFont(ofSize: 18, weight: .medium)
        if let (texture, size) = MetalTextRenderer.shared.texture(
            text: "No Data",
            font: font,
            color: config.textColor.withAlpha(0.5),
            device: context.device,
            scale: scale,
            extraVerticalPadding: 4
        ) {
            let rect = CGRect(
                x: context.bounds.midX - size.width / 2,
                y: context.bounds.midY - size.height / 2,
                width: size.width,
                height: size.height
            )
            renderer.drawTexture(texture, in: rect, tintColor: .white, renderContext: context)
        }
        #endif
    }
}

// MARK: - Heading Plugin

/// Heading/Compass instrument plugin
///
/// Displays current heading/course with optional cardinal directions.
/// Supports digital, compass, and arc display styles.
public struct HeadingPlugin: InstrumentPlugin {

    public init() {}

    public static let metadata = PluginMetadata(
        id: "com.flighttrace.heading",
        name: "Heading/Compass",
        description: "Displays current heading with compass visualization",
        version: "1.0.0",
        category: .indicator,
        iconName: "location.north.circle.fill"
    )

    public static let dataDependencies: Set<TelemetryDataType> = [.heading, .timestamp]

    public static let defaultSize = CGSize(width: 200, height: 200)

    public static let minimumSize = CGSize(width: 120, height: 120)

    public func createConfiguration() -> any InstrumentConfiguration {
        HeadingConfiguration()
    }

    public func createRenderer() -> any InstrumentRenderer {
        HeadingRenderer()
    }
}
