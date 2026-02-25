// VerticalSpeedPlugin.swift
// Vertical speed indicator (climb/descent rate) instrument plugin

import Foundation
import CoreGraphics

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Vertical Speed Unit

/// Units for displaying vertical speed
public enum VerticalSpeedUnit: String, Sendable, Codable, CaseIterable, Equatable {
    case metersPerSecond = "m/s"
    case feetPerMinute = "ft/min"
    case metersPerMinute = "m/min"

    /// Convert meters per second to this unit
    public func convert(metersPerSecond: Double) -> Double {
        switch self {
        case .metersPerSecond:
            return metersPerSecond
        case .feetPerMinute:
            return metersPerSecond * 196.85 // m/s to ft/min
        case .metersPerMinute:
            return metersPerSecond * 60.0
        }
    }
}

// MARK: - Vertical Speed Configuration

/// Configuration for the Vertical Speed Indicator instrument
public struct VerticalSpeedConfiguration: InstrumentConfiguration, Codable {
    public var id = UUID()

    /// The unit to display vertical speed in
    public var units: VerticalSpeedUnit = .feetPerMinute

    /// Number of decimal places to display
    public var decimalPlaces: Int = 0

    /// Text color for positive (climbing) values
    public var climbColor: SerializableColor = SerializableColor(red: 0.2, green: 0.8, blue: 0.2)

    /// Text color for negative (descending) values
    public var descentColor: SerializableColor = SerializableColor(red: 0.8, green: 0.3, blue: 0.3)

    /// Text color for level flight (near zero)
    public var levelColor: SerializableColor = .white

    /// Background color
    public var backgroundColor: SerializableColor = SerializableColor.black.withAlpha(0.7)

    /// Whether to show the unit label
    public var showLabel: Bool = true

    /// Whether to show up/down arrow indicators
    public var showArrow: Bool = true

    /// Font size for the vertical speed value
    public var fontSize: Double = 48.0

    /// Font size for the unit label
    public var labelFontSize: Double = 18.0

    /// Corner radius for the background
    public var cornerRadius: Double = 8.0

    /// Threshold for "level" flight (no color change) in m/s
    public var levelThreshold: Double = 0.5

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
                key: "units",
                value: units,
                options: VerticalSpeedUnit.allCases,
                label: "Vertical Speed Unit"
            ),
            .integer(
                key: "decimalPlaces",
                value: decimalPlaces,
                range: 0...2,
                label: "Decimal Places"
            ),
            .color(
                key: "climbColor",
                value: climbColor,
                label: "Climb Color"
            ),
            .color(
                key: "descentColor",
                value: descentColor,
                label: "Descent Color"
            ),
            .color(
                key: "levelColor",
                value: levelColor,
                label: "Level Color"
            ),
            .color(
                key: "backgroundColor",
                value: backgroundColor,
                label: "Background Color"
            ),
            .boolean(
                key: "showLabel",
                value: showLabel,
                label: "Show Unit Label"
            ),
            .boolean(
                key: "showArrow",
                value: showArrow,
                label: "Show Arrow Indicator"
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
            )
        ]
    }

    // MARK: - Property Updates

    public func updatingProperty(key: String, value: Any) -> VerticalSpeedConfiguration? {
        var updated = self

        switch key {
        case "units":
            if let enumValue = value as? VerticalSpeedUnit {
                updated.units = enumValue
            } else if let stringValue = value as? String, let unit = VerticalSpeedUnit(rawValue: stringValue) {
                updated.units = unit
            }
        case "decimalPlaces":
            if let intValue = value as? Int {
                updated.decimalPlaces = intValue
            } else if let doubleValue = value as? Double {
                updated.decimalPlaces = Int(doubleValue)
            }
        case "climbColor":
            if let colorValue = value as? SerializableColor {
                updated.climbColor = colorValue
            }
        case "descentColor":
            if let colorValue = value as? SerializableColor {
                updated.descentColor = colorValue
            }
        case "levelColor":
            if let colorValue = value as? SerializableColor {
                updated.levelColor = colorValue
            }
        case "backgroundColor":
            if let colorValue = value as? SerializableColor {
                updated.backgroundColor = colorValue
            }
        case "showLabel":
            if let boolValue = value as? Bool {
                updated.showLabel = boolValue
            }
        case "showArrow":
            if let boolValue = value as? Bool {
                updated.showArrow = boolValue
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
        default:
            return nil // Unknown property
        }

        return updated
    }
}

// MARK: - Vertical Speed Renderer

/// Renderer for the Vertical Speed Indicator instrument
public struct VerticalSpeedRenderer: InstrumentRenderer {

    public init() {}

    public func render(
        context: CGContext,
        renderContext: RenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        guard let config = configuration as? VerticalSpeedConfiguration else {
            return
        }

        // Get current telemetry data
        guard let point = dataProvider.currentPoint(),
              let verticalSpeed = point.verticalSpeed else {
            // Render "No Data" message
            renderNoData(context: context, renderContext: renderContext, config: config)
            return
        }

        // Convert vertical speed to configured units
        let vsValue = config.units.convert(metersPerSecond: verticalSpeed)

        // Render background
        renderBackground(context: context, bounds: renderContext.bounds, config: config)

        // Determine color based on climb/descent/level
        let textColor = colorForVerticalSpeed(verticalSpeed, config: config)

        // Render vertical speed value
        renderVerticalSpeedValue(
            context: context,
            bounds: renderContext.bounds,
            vsValue: vsValue,
            verticalSpeed: verticalSpeed,
            textColor: textColor,
            config: config
        )

        // Render unit label if enabled
        if config.showLabel {
            renderUnitLabel(
                context: context,
                bounds: renderContext.bounds,
                unit: config.units.rawValue,
                config: config
            )
        }
    }

    // MARK: - Private Rendering Methods

    private func colorForVerticalSpeed(_ vs: Double, config: VerticalSpeedConfiguration) -> SerializableColor {
        if abs(vs) <= config.levelThreshold {
            return config.levelColor
        } else if vs > 0 {
            return config.climbColor
        } else {
            return config.descentColor
        }
    }

    private func renderBackground(context: CGContext, bounds: CGRect, config: VerticalSpeedConfiguration) {
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

    private func renderVerticalSpeedValue(
        context: CGContext,
        bounds: CGRect,
        vsValue: Double,
        verticalSpeed: Double,
        textColor: SerializableColor,
        config: VerticalSpeedConfiguration
    ) {
        // Format the vertical speed value
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = config.decimalPlaces
        formatter.maximumFractionDigits = config.decimalPlaces
        formatter.positivePrefix = "+"
        let vsText = formatter.string(from: NSNumber(value: vsValue)) ?? "0"

        // Add arrow if enabled
        let arrow = config.showArrow ? arrowForVerticalSpeed(verticalSpeed, config: config) : ""
        let displayText = arrow.isEmpty ? vsText : "\(arrow) \(vsText)"

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

        // Position text in center (or slightly above center if label is shown)
        let yOffset = config.showLabel ? -config.labelFontSize / 2 : 0
        let textRect = CGRect(
            x: bounds.midX - textSize.width / 2,
            y: bounds.midY - textSize.height / 2 + yOffset,
            width: textSize.width,
            height: textSize.height
        )

        // Draw text
        attributedString.draw(in: textRect)
        #endif
    }

    private func arrowForVerticalSpeed(_ vs: Double, config: VerticalSpeedConfiguration) -> String {
        if abs(vs) <= config.levelThreshold {
            return "→"
        } else if vs > 0 {
            return "↑"
        } else {
            return "↓"
        }
    }

    private func renderUnitLabel(
        context: CGContext,
        bounds: CGRect,
        unit: String,
        config: VerticalSpeedConfiguration
    ) {
        #if canImport(AppKit)
        let font = NSFont.systemFont(ofSize: config.labelFontSize, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: config.levelColor.nsColor.withAlphaComponent(0.7)
        ]
        let attributedString = NSAttributedString(string: unit, attributes: attributes)

        // Calculate text size and position
        let textSize = attributedString.size()

        // Position label below the vertical speed value
        let textRect = CGRect(
            x: bounds.midX - textSize.width / 2,
            y: bounds.midY + config.fontSize / 3,
            width: textSize.width,
            height: textSize.height
        )

        // Draw text
        attributedString.draw(in: textRect)
        #endif
    }

    private func renderNoData(
        context: CGContext,
        renderContext: RenderContext,
        config: VerticalSpeedConfiguration
    ) {
        // Render background
        renderBackground(context: context, bounds: renderContext.bounds, config: config)

        // Render "No Data" message
        #if canImport(AppKit)
        let font = NSFont.systemFont(ofSize: 18, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: config.levelColor.nsColor.withAlphaComponent(0.5)
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

// MARK: - Vertical Speed Plugin

/// Vertical Speed Indicator instrument plugin
///
/// Displays vertical speed (rate of climb/descent) with color-coded indicators.
/// Positive values indicate climbing, negative values indicate descending.
public struct VerticalSpeedPlugin: InstrumentPlugin {

    public init() {}

    // MARK: - Plugin Identity

    public static let metadata = PluginMetadata(
        id: "com.flighttrace.vertical-speed",
        name: "Vertical Speed",
        description: "Displays rate of climb or descent",
        version: "1.0.0",
        category: .indicator,
        iconName: "arrow.up.arrow.down"
    )

    // MARK: - Data Requirements

    public static let dataDependencies: Set<TelemetryDataType> = [.verticalSpeed, .timestamp]

    // MARK: - Default Properties

    public static let defaultSize = CGSize(width: 200, height: 100)

    public static let minimumSize = CGSize(width: 120, height: 60)

    // MARK: - Factory Methods

    public func createConfiguration() -> any InstrumentConfiguration {
        VerticalSpeedConfiguration()
    }

    public func createRenderer() -> any InstrumentRenderer {
        VerticalSpeedRenderer()
    }
}
