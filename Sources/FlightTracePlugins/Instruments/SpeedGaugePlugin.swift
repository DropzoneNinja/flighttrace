// SpeedGaugePlugin.swift
// Digital speed display instrument plugin

import Foundation
import CoreGraphics

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Speed Unit

/// Units for displaying speed
public enum SpeedUnit: String, Sendable, Codable, CaseIterable, Equatable {
    case metersPerSecond = "m/s"
    case kilometersPerHour = "km/h"
    case milesPerHour = "mph"
    case knots = "kts"

    /// Convert meters per second to this unit
    public func convert(metersPerSecond: Double) -> Double {
        switch self {
        case .metersPerSecond:
            return metersPerSecond
        case .kilometersPerHour:
            return metersPerSecond * 3.6
        case .milesPerHour:
            return metersPerSecond * 2.23694
        case .knots:
            return metersPerSecond * 1.94384
        }
    }
}

// MARK: - Speed Gauge Configuration

/// Configuration for the Speed Gauge instrument
public struct SpeedGaugeConfiguration: InstrumentConfiguration, Codable {
    public var id = UUID()

    /// The unit to display speed in
    public var units: SpeedUnit = .milesPerHour

    /// Number of decimal places to display
    public var decimalPlaces: Int = 1

    /// Text color for the speed value
    public var textColor: SerializableColor = .white

    /// Background color
    public var backgroundColor: SerializableColor = SerializableColor.black.withAlpha(0.7)

    /// Whether to show the unit label
    public var showLabel: Bool = true

    /// Font size for the speed value
    public var fontSize: Double = 48.0

    /// Font size for the unit label
    public var labelFontSize: Double = 18.0

    /// Corner radius for the background
    public var cornerRadius: Double = 8.0

    /// Padding inside the gauge
    public var padding: Double = 12.0

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
                options: SpeedUnit.allCases,
                label: "Speed Unit"
            ),
            .integer(
                key: "decimalPlaces",
                value: decimalPlaces,
                range: 0...3,
                label: "Decimal Places"
            ),
            .color(
                key: "textColor",
                value: textColor,
                label: "Text Color"
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

    public func updatingProperty(key: String, value: Any) -> SpeedGaugeConfiguration? {
        var updated = self

        switch key {
        case "units":
            if let enumValue = value as? SpeedUnit {
                updated.units = enumValue
            } else if let stringValue = value as? String, let unit = SpeedUnit(rawValue: stringValue) {
                updated.units = unit
            }
        case "decimalPlaces":
            if let intValue = value as? Int {
                updated.decimalPlaces = intValue
            } else if let doubleValue = value as? Double {
                updated.decimalPlaces = Int(doubleValue)
            }
        case "textColor":
            if let colorValue = value as? SerializableColor {
                updated.textColor = colorValue
            }
        case "backgroundColor":
            if let colorValue = value as? SerializableColor {
                updated.backgroundColor = colorValue
            }
        case "showLabel":
            if let boolValue = value as? Bool {
                updated.showLabel = boolValue
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

// MARK: - Speed Gauge Renderer

/// Renderer for the Speed Gauge instrument
public struct SpeedGaugeRenderer: InstrumentRenderer {

    public init() {}

    public func render(
        context: CGContext,
        renderContext: RenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        guard let config = configuration as? SpeedGaugeConfiguration else {
            return
        }

        // Get current telemetry data
        guard let point = dataProvider.currentPoint(),
              let speed = point.speed else {
            // Render "No Data" message
            renderNoData(context: context, renderContext: renderContext, config: config)
            return
        }

        // Convert speed to configured units
        let speedValue = config.units.convert(metersPerSecond: speed)

        // Render background
        renderBackground(context: context, bounds: renderContext.bounds, config: config)

        // Render speed value
        renderSpeedValue(
            context: context,
            bounds: renderContext.bounds,
            speedValue: speedValue,
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

    private func renderBackground(context: CGContext, bounds: CGRect, config: SpeedGaugeConfiguration) {
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

    private func renderSpeedValue(
        context: CGContext,
        bounds: CGRect,
        speedValue: Double,
        config: SpeedGaugeConfiguration
    ) {
        // Format the speed value
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = config.decimalPlaces
        formatter.maximumFractionDigits = config.decimalPlaces
        let speedText = formatter.string(from: NSNumber(value: speedValue)) ?? "0"

        // Create attributed string with font
        #if canImport(AppKit)
        let font = NSFont.monospacedDigitSystemFont(
            ofSize: config.fontSize,
            weight: .bold
        )
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: config.textColor.nsColor
        ]
        let attributedString = NSAttributedString(string: speedText, attributes: attributes)

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

    private func renderUnitLabel(
        context: CGContext,
        bounds: CGRect,
        unit: String,
        config: SpeedGaugeConfiguration
    ) {
        #if canImport(AppKit)
        let font = NSFont.systemFont(ofSize: config.labelFontSize, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: config.textColor.nsColor.withAlphaComponent(0.7)
        ]
        let attributedString = NSAttributedString(string: unit, attributes: attributes)

        // Calculate text size and position
        let textSize = attributedString.size()

        // Position label below the speed value
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
        config: SpeedGaugeConfiguration
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

// MARK: - Speed Gauge Plugin

/// Speed Gauge instrument plugin
///
/// Displays current speed as a digital readout with configurable units and styling.
/// Supports multiple speed units: m/s, km/h, mph, and knots.
public struct SpeedGaugePlugin: InstrumentPlugin {

    public init() {}

    // MARK: - Plugin Identity

    public static let metadata = PluginMetadata(
        id: "com.flighttrace.speed-gauge",
        name: "Speed Gauge",
        description: "Displays current speed with configurable units",
        version: "1.0.0",
        category: .gauge,
        iconName: "gauge.with.dots.needle.33percent"
    )

    // MARK: - Data Requirements

    public static let dataDependencies: Set<TelemetryDataType> = [.speed, .timestamp]

    // MARK: - Default Properties

    public static let defaultSize = CGSize(width: 200, height: 100)

    public static let minimumSize = CGSize(width: 120, height: 60)

    // MARK: - Factory Methods

    public func createConfiguration() -> any InstrumentConfiguration {
        SpeedGaugeConfiguration()
    }

    public func createRenderer() -> any InstrumentRenderer {
        SpeedGaugeRenderer()
    }
}
