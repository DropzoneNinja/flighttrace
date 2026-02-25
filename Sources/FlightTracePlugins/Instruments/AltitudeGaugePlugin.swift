// AltitudeGaugePlugin.swift
// Digital altitude display instrument plugin

import Foundation
import CoreGraphics
import CoreText

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Altitude Unit

/// Units for displaying altitude
public enum AltitudeUnit: String, Sendable, Codable, CaseIterable, Equatable {
    case meters = "m"
    case feet = "ft"

    /// Convert meters to this unit
    public func convert(meters: Double) -> Double {
        switch self {
        case .meters:
            return meters
        case .feet:
            return meters * 3.28084
        }
    }
}

// MARK: - Altitude Gauge Configuration

/// Configuration for the Altitude Gauge instrument
public struct AltitudeGaugeConfiguration: InstrumentConfiguration, Codable {
    public var id = UUID()

    /// The unit to display altitude in
    public var units: AltitudeUnit = .feet

    /// Number of decimal places to display
    public var decimalPlaces: Int = 0

    /// Text color for the altitude value
    public var textColor: SerializableColor = .white

    /// Background color
    public var backgroundColor: SerializableColor = SerializableColor.black.withAlpha(0.7)

    /// Whether to show the unit label
    public var showLabel: Bool = true

    /// Font size for the altitude value
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
                options: AltitudeUnit.allCases,
                label: "Altitude Unit"
            ),
            .integer(
                key: "decimalPlaces",
                value: decimalPlaces,
                range: 0...2,
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

    public func updatingProperty(key: String, value: Any) -> AltitudeGaugeConfiguration? {
        var updated = self

        switch key {
        case "units":
            if let enumValue = value as? AltitudeUnit {
                updated.units = enumValue
            } else if let stringValue = value as? String, let unit = AltitudeUnit(rawValue: stringValue) {
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

// MARK: - Altitude Gauge Renderer

/// Renderer for the Altitude Gauge instrument
public struct AltitudeGaugeRenderer: InstrumentRenderer {

    public init() {}

    public func render(
        context: CGContext,
        renderContext: RenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        // Version marker to confirm new code is running
        print("🚨 AltitudeGauge.render: VERSION 2.0 - NEW DEBUG CODE RUNNING 🚨")
        print("AltitudeGauge.render: Called with configuration type: \(type(of: configuration))")

        guard let config = configuration as? AltitudeGaugeConfiguration else {
            print("AltitudeGauge.render: ERROR - Configuration cast failed!")
            return
        }

        print("AltitudeGauge.render: Configuration cast succeeded (v2.0)")

        // Get current telemetry data
        let point = dataProvider.currentPoint()

        // Debug logging
        if point == nil {
            print("AltitudeGauge: No telemetry point available - rendering No Data")
            renderNoData(context: context, renderContext: renderContext, config: config)
            return
        } else if point?.elevation == nil {
            print("AltitudeGauge: Point exists but no elevation data (lat: \(point!.coordinate.latitude), lon: \(point!.coordinate.longitude)) - rendering No Data")
            renderNoData(context: context, renderContext: renderContext, config: config)
            return
        }

        // If we got here, we have valid data!
        let elevation = point!.elevation!
        print("AltitudeGauge: Rendering with elevation: \(elevation) meters at bounds: \(renderContext.bounds)")

        // Convert altitude to configured units
        let altitudeValue = config.units.convert(meters: elevation)
        print("AltitudeGauge: Converted to \(altitudeValue) \(config.units.rawValue)")

        // Render background
        print("AltitudeGauge: About to render background")
        renderBackground(context: context, bounds: renderContext.bounds, config: config)
        print("AltitudeGauge: Finished rendering background")

        // Render altitude value
        print("AltitudeGauge: About to render altitude value text: \(altitudeValue) ft")
        renderAltitudeValue(
            context: context,
            bounds: renderContext.bounds,
            altitudeValue: altitudeValue,
            config: config
        )
        print("AltitudeGauge: Finished rendering altitude value text")

        // Render unit label if enabled
        if config.showLabel {
            print("AltitudeGauge: About to render unit label")
            renderUnitLabel(
                context: context,
                bounds: renderContext.bounds,
                unit: config.units.rawValue,
                config: config
            )
        }
    }

    // MARK: - Private Rendering Methods

    private func renderBackground(context: CGContext, bounds: CGRect, config: AltitudeGaugeConfiguration) {
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

    private func renderAltitudeValue(
        context: CGContext,
        bounds: CGRect,
        altitudeValue: Double,
        config: AltitudeGaugeConfiguration
    ) {
        print("  → renderAltitudeValue: Starting with value=\(altitudeValue), bounds=\(bounds)")

        // Format the altitude value
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = config.decimalPlaces
        formatter.maximumFractionDigits = config.decimalPlaces
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        let altitudeText = formatter.string(from: NSNumber(value: altitudeValue)) ?? "0"

        print("  → renderAltitudeValue: Formatted text='\(altitudeText)', fontSize=\(config.fontSize), textColor=\(config.textColor)")

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
        let attributedString = NSAttributedString(string: altitudeText, attributes: attributes)

        // Calculate text size and position
        let textSize = attributedString.size()
        print("  → renderAltitudeValue: Text size=\(textSize)")

        // Position text in center (or slightly above center if label is shown)
        let yOffset = config.showLabel ? -config.labelFontSize / 2 : 0
        let textRect = CGRect(
            x: bounds.midX - textSize.width / 2,
            y: bounds.midY - textSize.height / 2 + yOffset,
            width: textSize.width,
            height: textSize.height
        )

        print("  → renderAltitudeValue: textRect=\(textRect), yOffset=\(yOffset)")
        print("  → renderAltitudeValue: About to draw text using Core Text")

        // Use Core Text to draw in CGContext (NSAttributedString.draw doesn't work in export context)
        context.saveGState()

        // Flip coordinate system for text (Core Text uses different Y orientation)
        context.textMatrix = .identity
        context.translateBy(x: textRect.origin.x, y: textRect.origin.y + textSize.height)
        context.scaleBy(x: 1.0, y: -1.0)

        // Create CTLine and draw
        let line = CTLineCreateWithAttributedString(attributedString)
        CTLineDraw(line, context)

        context.restoreGState()

        print("  → renderAltitudeValue: Finished drawing text using Core Text")
        #endif
    }

    private func renderUnitLabel(
        context: CGContext,
        bounds: CGRect,
        unit: String,
        config: AltitudeGaugeConfiguration
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

        // Position label below the altitude value
        let textRect = CGRect(
            x: bounds.midX - textSize.width / 2,
            y: bounds.midY + config.fontSize / 3,
            width: textSize.width,
            height: textSize.height
        )

        // Use Core Text to draw in CGContext (NSAttributedString.draw doesn't work in export context)
        context.saveGState()

        // Flip coordinate system for text (Core Text uses different Y orientation)
        context.textMatrix = .identity
        context.translateBy(x: textRect.origin.x, y: textRect.origin.y + textSize.height)
        context.scaleBy(x: 1.0, y: -1.0)

        // Create CTLine and draw
        let line = CTLineCreateWithAttributedString(attributedString)
        CTLineDraw(line, context)

        context.restoreGState()
        #endif
    }

    private func renderNoData(
        context: CGContext,
        renderContext: RenderContext,
        config: AltitudeGaugeConfiguration
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

// MARK: - Altitude Gauge Plugin

/// Altitude Gauge instrument plugin
///
/// Displays current altitude/elevation as a digital readout with configurable units and styling.
/// Supports meters and feet.
public struct AltitudeGaugePlugin: InstrumentPlugin {

    public init() {}

    // MARK: - Plugin Identity

    public static let metadata = PluginMetadata(
        id: "com.flighttrace.altitude-gauge",
        name: "Altitude Gauge",
        description: "Displays current altitude with configurable units",
        version: "1.0.0",
        category: .gauge,
        iconName: "mountain.2.fill"
    )

    // MARK: - Data Requirements

    public static let dataDependencies: Set<TelemetryDataType> = [.elevation, .timestamp]

    // MARK: - Default Properties

    public static let defaultSize = CGSize(width: 200, height: 100)

    public static let minimumSize = CGSize(width: 120, height: 60)

    // MARK: - Factory Methods

    public func createConfiguration() -> any InstrumentConfiguration {
        AltitudeGaugeConfiguration()
    }

    public func createRenderer() -> any InstrumentRenderer {
        AltitudeGaugeRenderer()
    }
}
