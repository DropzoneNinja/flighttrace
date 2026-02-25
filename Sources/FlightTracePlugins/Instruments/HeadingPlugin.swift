// HeadingPlugin.swift
// Heading/compass instrument plugin

import Foundation
import CoreGraphics

#if canImport(AppKit)
import AppKit
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

// MARK: - Heading Renderer

/// Renderer for the Heading/Compass instrument
public struct HeadingRenderer: InstrumentRenderer {

    public init() {}

    public func render(
        context: CGContext,
        renderContext: RenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        guard let config = configuration as? HeadingConfiguration else {
            return
        }

        // Get current telemetry data
        guard let point = dataProvider.currentPoint(),
              let heading = point.heading else {
            // Render "No Data" message
            renderNoData(context: context, renderContext: renderContext, config: config)
            return
        }

        // Render background
        renderBackground(context: context, bounds: renderContext.bounds, config: config)

        // Render based on style
        switch config.style {
        case .digital:
            renderDigital(
                context: context,
                bounds: renderContext.bounds,
                heading: heading,
                config: config
            )
        case .compass:
            renderCompass(
                context: context,
                bounds: renderContext.bounds,
                heading: heading,
                config: config
            )
        case .arc:
            renderArc(
                context: context,
                bounds: renderContext.bounds,
                heading: heading,
                config: config
            )
        }
    }

    // MARK: - Private Rendering Methods

    private func renderBackground(context: CGContext, bounds: CGRect, config: HeadingConfiguration) {
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

    private func cardinalDirection(for heading: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((heading + 22.5) / 45.0) % 8
        return directions[index]
    }

    private func renderDigital(
        context: CGContext,
        bounds: CGRect,
        heading: Double,
        config: HeadingConfiguration
    ) {
        #if canImport(AppKit)
        var yOffset: CGFloat = 0

        // Render cardinal direction if enabled
        if config.showCardinalDirections {
            let direction = cardinalDirection(for: heading)
            let font = NSFont.systemFont(ofSize: config.cardinalFontSize, weight: .bold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: config.textColor.nsColor
            ]
            let attributedString = NSAttributedString(string: direction, attributes: attributes)
            let textSize = attributedString.size()
            let textRect = CGRect(
                x: bounds.midX - textSize.width / 2,
                y: bounds.midY - CGFloat(config.fontSize) / 2 - textSize.height - 5,
                width: textSize.width,
                height: textSize.height
            )
            attributedString.draw(in: textRect)
            yOffset = 10
        }

        // Render degree value if enabled
        if config.showDegrees {
            let headingText = String(format: "%03.0f°", heading)
            let font = NSFont.monospacedDigitSystemFont(ofSize: config.fontSize, weight: .bold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: config.textColor.nsColor
            ]
            let attributedString = NSAttributedString(string: headingText, attributes: attributes)
            let textSize = attributedString.size()
            let textRect = CGRect(
                x: bounds.midX - textSize.width / 2,
                y: bounds.midY - textSize.height / 2 + yOffset,
                width: textSize.width,
                height: textSize.height
            )
            attributedString.draw(in: textRect)
        }
        #endif
    }

    private func renderCompass(
        context: CGContext,
        bounds: CGRect,
        heading: Double,
        config: HeadingConfiguration
    ) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) * 0.35

        // Draw compass circle
        context.setStrokeColor(config.textColor.withAlpha(0.3).cgColor)
        context.setLineWidth(2)
        context.addArc(
            center: center,
            radius: radius,
            startAngle: 0,
            endAngle: CGFloat.pi * 2,
            clockwise: false
        )
        context.strokePath()

        #if canImport(AppKit)
        // Draw cardinal directions
        if config.showCardinalDirections {
            let directions = ["N", "E", "S", "W"]
            let angles: [Double] = [0, 90, 180, 270]
            let font = NSFont.systemFont(ofSize: config.cardinalFontSize * 0.7, weight: .bold)

            for (direction, angle) in zip(directions, angles) {
                let radians = (angle - 90) * .pi / 180
                let x = center.x + cos(radians) * (radius + 15)
                let y = center.y + sin(radians) * (radius + 15)

                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: config.textColor.nsColor
                ]
                let attributedString = NSAttributedString(string: direction, attributes: attributes)
                let textSize = attributedString.size()
                let textRect = CGRect(
                    x: x - textSize.width / 2,
                    y: y - textSize.height / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                attributedString.draw(in: textRect)
            }
        }
        #endif

        // Draw heading needle
        let headingRadians = (heading - 90) * .pi / 180
        let needleLength = radius * 0.8
        let needleEnd = CGPoint(
            x: center.x + cos(headingRadians) * needleLength,
            y: center.y + sin(headingRadians) * needleLength
        )

        context.setStrokeColor(config.needleColor.cgColor)
        context.setLineWidth(3)
        context.move(to: center)
        context.addLine(to: needleEnd)
        context.strokePath()

        // Draw center dot
        context.setFillColor(config.needleColor.cgColor)
        context.addArc(center: center, radius: 4, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: false)
        context.fillPath()

        // Draw heading value
        if config.showDegrees {
            #if canImport(AppKit)
            let headingText = String(format: "%03.0f°", heading)
            let font = NSFont.monospacedDigitSystemFont(ofSize: config.fontSize * 0.4, weight: .bold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: config.textColor.nsColor
            ]
            let attributedString = NSAttributedString(string: headingText, attributes: attributes)
            let textSize = attributedString.size()
            let textRect = CGRect(
                x: bounds.midX - textSize.width / 2,
                y: bounds.maxY - textSize.height - 10,
                width: textSize.width,
                height: textSize.height
            )
            attributedString.draw(in: textRect)
            #endif
        }
    }

    private func renderArc(
        context: CGContext,
        bounds: CGRect,
        heading: Double,
        config: HeadingConfiguration
    ) {
        // For now, render as compass
        // TODO: Implement arc-style heading tape
        renderCompass(context: context, bounds: bounds, heading: heading, config: config)
    }

    private func renderNoData(
        context: CGContext,
        renderContext: RenderContext,
        config: HeadingConfiguration
    ) {
        // Render background
        renderBackground(context: context, bounds: renderContext.bounds, config: config)

        // Render "No Data" message
        #if canImport(AppKit)
        let font = NSFont.systemFont(ofSize: 18, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: config.textColor.nsColor.withAlphaComponent(0.5)
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

// MARK: - Heading Plugin

/// Heading/Compass instrument plugin
///
/// Displays current heading/course with optional cardinal directions.
/// Supports digital, compass, and arc display styles.
public struct HeadingPlugin: InstrumentPlugin {

    public init() {}

    // MARK: - Plugin Identity

    public static let metadata = PluginMetadata(
        id: "com.flighttrace.heading",
        name: "Heading/Compass",
        description: "Displays current heading with compass visualization",
        version: "1.0.0",
        category: .indicator,
        iconName: "location.north.circle.fill"
    )

    // MARK: - Data Requirements

    public static let dataDependencies: Set<TelemetryDataType> = [.heading, .timestamp]

    // MARK: - Default Properties

    public static let defaultSize = CGSize(width: 200, height: 200)

    public static let minimumSize = CGSize(width: 120, height: 120)

    // MARK: - Factory Methods

    public func createConfiguration() -> any InstrumentConfiguration {
        HeadingConfiguration()
    }

    public func createRenderer() -> any InstrumentRenderer {
        HeadingRenderer()
    }
}
