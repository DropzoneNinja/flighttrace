// GMeterPlugin.swift
// G-force meter instrument plugin

import Foundation
import CoreGraphics

#if canImport(AppKit)
import AppKit
#endif

// MARK: - G-Meter Style

/// Display style for G-force meter
public enum GMeterStyle: String, Sendable, Codable, CaseIterable, Equatable {
    case digital = "Digital"
    case gauge = "Gauge"
    case bar = "Bar"
}

// MARK: - G-Meter Configuration

/// Configuration for the G-Meter instrument
public struct GMeterConfiguration: InstrumentConfiguration, Codable {
    public var id = UUID()

    /// Display style
    public var style: GMeterStyle = .digital

    /// Number of decimal places to display
    public var decimalPlaces: Int = 2

    /// Text color for positive G-forces
    public var positiveColor: SerializableColor = .white

    /// Text color for high G-forces (warning)
    public var highGColor: SerializableColor = SerializableColor(red: 1.0, green: 0.6, blue: 0.0)

    /// Text color for extreme G-forces (danger)
    public var extremeGColor: SerializableColor = SerializableColor(red: 1.0, green: 0.2, blue: 0.2)

    /// Background color
    public var backgroundColor: SerializableColor = SerializableColor.black.withAlpha(0.7)

    /// Whether to show the G label
    public var showLabel: Bool = true

    /// Whether to show min/max G values
    public var showMinMax: Bool = false

    /// Font size for the G-force value
    public var fontSize: Double = 48.0

    /// Font size for the label
    public var labelFontSize: Double = 18.0

    /// Corner radius for the background
    public var cornerRadius: Double = 8.0

    /// Threshold for "high G" warning (in Gs)
    public var highGThreshold: Double = 3.0

    /// Threshold for "extreme G" danger (in Gs)
    public var extremeGThreshold: Double = 5.0

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
                options: GMeterStyle.allCases,
                label: "Display Style"
            ),
            .integer(
                key: "decimalPlaces",
                value: decimalPlaces,
                range: 0...3,
                label: "Decimal Places"
            ),
            .color(
                key: "positiveColor",
                value: positiveColor,
                label: "Normal Color"
            ),
            .color(
                key: "highGColor",
                value: highGColor,
                label: "High G Color"
            ),
            .color(
                key: "extremeGColor",
                value: extremeGColor,
                label: "Extreme G Color"
            ),
            .color(
                key: "backgroundColor",
                value: backgroundColor,
                label: "Background Color"
            ),
            .boolean(
                key: "showLabel",
                value: showLabel,
                label: "Show Label"
            ),
            .boolean(
                key: "showMinMax",
                value: showMinMax,
                label: "Show Min/Max"
            ),
            .slider(
                key: "fontSize",
                value: fontSize,
                range: 24.0...96.0,
                step: 4.0,
                label: "Font Size"
            ),
            .slider(
                key: "labelFontSize",
                value: labelFontSize,
                range: 12.0...36.0,
                step: 2.0,
                label: "Label Font Size"
            ),
            .slider(
                key: "cornerRadius",
                value: cornerRadius,
                range: 0.0...20.0,
                step: 1.0,
                label: "Corner Radius"
            ),
            .slider(
                key: "highGThreshold",
                value: highGThreshold,
                range: 2.0...6.0,
                step: 0.5,
                label: "High G Threshold"
            ),
            .slider(
                key: "extremeGThreshold",
                value: extremeGThreshold,
                range: 4.0...10.0,
                step: 0.5,
                label: "Extreme G Threshold"
            )
        ]
    }

    // MARK: - Property Updates

    public func updatingProperty(key: String, value: Any) -> GMeterConfiguration? {
        var updated = self

        switch key {
        case "style":
            if let enumValue = value as? GMeterStyle {
                updated.style = enumValue
            } else if let stringValue = value as? String, let style = GMeterStyle(rawValue: stringValue) {
                updated.style = style
            }
        case "decimalPlaces":
            if let intValue = value as? Int {
                updated.decimalPlaces = intValue
            } else if let doubleValue = value as? Double {
                updated.decimalPlaces = Int(doubleValue)
            }
        case "positiveColor":
            if let colorValue = value as? SerializableColor {
                updated.positiveColor = colorValue
            }
        case "highGColor":
            if let colorValue = value as? SerializableColor {
                updated.highGColor = colorValue
            }
        case "extremeGColor":
            if let colorValue = value as? SerializableColor {
                updated.extremeGColor = colorValue
            }
        case "backgroundColor":
            if let colorValue = value as? SerializableColor {
                updated.backgroundColor = colorValue
            }
        case "showLabel":
            if let boolValue = value as? Bool {
                updated.showLabel = boolValue
            }
        case "showMinMax":
            if let boolValue = value as? Bool {
                updated.showMinMax = boolValue
            }
        case "fontSize":
            if let doubleValue = value as? Double {
                updated.fontSize = doubleValue
            }
        case "labelFontSize":
            if let doubleValue = value as? Double {
                updated.labelFontSize = doubleValue
            }
        case "cornerRadius":
            if let doubleValue = value as? Double {
                updated.cornerRadius = doubleValue
            }
        case "highGThreshold":
            if let doubleValue = value as? Double {
                updated.highGThreshold = doubleValue
            }
        case "extremeGThreshold":
            if let doubleValue = value as? Double {
                updated.extremeGThreshold = doubleValue
            }
        default:
            return nil // Unknown property
        }

        return updated
    }
}

// MARK: - G-Meter Renderer

/// Renderer for the G-Meter instrument
public struct GMeterRenderer: InstrumentRenderer {

    public init() {}

    public func render(
        context: CGContext,
        renderContext: RenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        guard let config = configuration as? GMeterConfiguration else {
            return
        }

        // Get current telemetry data
        guard let point = dataProvider.currentPoint() else {
            print("🔍 GMeterPlugin: No current point available")
            renderNoData(context: context, renderContext: renderContext, config: config)
            return
        }

        guard let gForce = point.gForce else {
            print("🔍 GMeterPlugin: Current point has no gForce data (speed=\(point.speed ?? -999))")
            // Render "No Data" message
            renderNoData(context: context, renderContext: renderContext, config: config)
            return
        }

        print("🔍 GMeterPlugin: Rendering G-force = \(gForce)")

        // Render background
        renderBackground(context: context, bounds: renderContext.bounds, config: config)

        // Determine color based on G-force level
        let textColor = colorForGForce(gForce, config: config)

        // Render based on style
        switch config.style {
        case .digital:
            renderDigital(
                context: context,
                bounds: renderContext.bounds,
                gForce: gForce,
                textColor: textColor,
                config: config
            )
        case .gauge:
            renderGauge(
                context: context,
                bounds: renderContext.bounds,
                gForce: gForce,
                textColor: textColor,
                config: config
            )
        case .bar:
            renderBar(
                context: context,
                bounds: renderContext.bounds,
                gForce: gForce,
                textColor: textColor,
                config: config
            )
        }
    }

    // MARK: - Private Rendering Methods

    private func colorForGForce(_ g: Double, config: GMeterConfiguration) -> SerializableColor {
        let absG = abs(g)
        if absG >= config.extremeGThreshold {
            return config.extremeGColor
        } else if absG >= config.highGThreshold {
            return config.highGColor
        } else {
            return config.positiveColor
        }
    }

    private func renderBackground(context: CGContext, bounds: CGRect, config: GMeterConfiguration) {
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

    private func renderDigital(
        context: CGContext,
        bounds: CGRect,
        gForce: Double,
        textColor: SerializableColor,
        config: GMeterConfiguration
    ) {
        // Format the G-force value
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = config.decimalPlaces
        formatter.maximumFractionDigits = config.decimalPlaces
        let gText = formatter.string(from: NSNumber(value: gForce)) ?? "0"

        let displayText = config.showLabel ? "\(gText) G" : gText

        // Create attributed string with font
        #if canImport(AppKit)
        let font = NSFont.monospacedDigitSystemFont(
            ofSize: config.fontSize,
            weight: .bold
        )
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor.nsColor
        ]
        let attributedString = NSAttributedString(string: displayText, attributes: attributes)

        // Calculate text size and position
        let textSize = attributedString.size()
        let textRect = CGRect(
            x: bounds.midX - textSize.width / 2,
            y: bounds.midY - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )

        // Draw text
        attributedString.draw(in: textRect)
        #endif
    }

    private func renderGauge(
        context: CGContext,
        bounds: CGRect,
        gForce: Double,
        textColor: SerializableColor,
        config: GMeterConfiguration
    ) {
        // For now, render as digital with gauge styling
        // TODO: Implement circular gauge visualization
        renderDigital(context: context, bounds: bounds, gForce: gForce, textColor: textColor, config: config)
    }

    private func renderBar(
        context: CGContext,
        bounds: CGRect,
        gForce: Double,
        textColor: SerializableColor,
        config: GMeterConfiguration
    ) {
        #if canImport(AppKit)
        // Draw vertical bar meter
        let barWidth: CGFloat = 40
        let barHeight = bounds.height * 0.6
        let barX = bounds.midX - barWidth / 2
        let barY = bounds.midY - barHeight / 2

        // Draw bar background
        let barBackground = CGRect(x: barX, y: barY, width: barWidth, height: barHeight)
        context.setFillColor(SerializableColor.white.withAlpha(0.2).cgColor)
        context.fill(barBackground)

        // Draw filled portion based on G-force (scale 0-6G)
        let maxG: CGFloat = 6.0
        let normalizedG = min(max(CGFloat(gForce), 0), maxG) / maxG
        let filledHeight = barHeight * normalizedG
        let filledY = barY + (barHeight - filledHeight)
        let filledBar = CGRect(x: barX, y: filledY, width: barWidth, height: filledHeight)
        context.setFillColor(textColor.cgColor)
        context.fill(filledBar)

        // Draw G-force value below bar
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = config.decimalPlaces
        formatter.maximumFractionDigits = config.decimalPlaces
        let gText = formatter.string(from: NSNumber(value: gForce)) ?? "0"
        let displayText = "\(gText) G"

        let font = NSFont.monospacedDigitSystemFont(ofSize: config.fontSize * 0.4, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor.nsColor
        ]
        let attributedString = NSAttributedString(string: displayText, attributes: attributes)
        let textSize = attributedString.size()
        let textRect = CGRect(
            x: bounds.midX - textSize.width / 2,
            y: barY + barHeight + 10,
            width: textSize.width,
            height: textSize.height
        )
        attributedString.draw(in: textRect)
        #endif
    }

    private func renderNoData(
        context: CGContext,
        renderContext: RenderContext,
        config: GMeterConfiguration
    ) {
        // Render background
        renderBackground(context: context, bounds: renderContext.bounds, config: config)

        // Render "No Data" message
        #if canImport(AppKit)
        let font = NSFont.systemFont(ofSize: 18, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: config.positiveColor.nsColor.withAlphaComponent(0.5)
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

// MARK: - G-Meter Plugin

/// G-Meter instrument plugin
///
/// Displays G-force (acceleration) with color-coded warnings for high G levels.
/// Supports multiple display styles: digital, gauge, and bar.
public struct GMeterPlugin: InstrumentPlugin {

    public init() {}

    // MARK: - Plugin Identity

    public static let metadata = PluginMetadata(
        id: "com.flighttrace.g-meter",
        name: "G-Meter",
        description: "Displays G-force with visual warnings",
        version: "1.0.0",
        category: .gauge,
        iconName: "gauge.with.needle.fill"
    )

    // MARK: - Data Requirements

    public static let dataDependencies: Set<TelemetryDataType> = [.gForce, .timestamp]

    // MARK: - Default Properties

    public static let defaultSize = CGSize(width: 200, height: 100)

    public static let minimumSize = CGSize(width: 120, height: 80)

    // MARK: - Factory Methods

    public func createConfiguration() -> any InstrumentConfiguration {
        GMeterConfiguration()
    }

    public func createRenderer() -> any InstrumentRenderer {
        GMeterRenderer()
    }
}
