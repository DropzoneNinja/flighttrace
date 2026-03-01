// GMeterDigitalPlugin.swift
// G-force meter instrument plugin (Metal)

import Foundation
import CoreGraphics

#if canImport(AppKit)
import AppKit
import FlightTraceCore
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
public struct GMeterDigitalConfiguration: InstrumentConfiguration, Codable {
    public var id = UUID()

    /// Display style (legacy; digital-only rendering)
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

    public func updatingProperty(key: String, value: Any) -> GMeterDigitalConfiguration? {
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
            return nil
        }

        return updated
    }
}

// MARK: - G-Meter Renderer (Metal)

public struct GMeterDigitalRenderer: InstrumentRenderer {

    public init() {}

    public func render(
        context: MetalRenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        guard let config = configuration as? GMeterDigitalConfiguration else {
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
              let gForce = point.gForce else {
            renderNoData(context: context, config: config, renderer: renderer)
            return
        }

        let textColor = colorForGForce(gForce, config: config)

        renderDigital(context: context, gForce: gForce, textColor: textColor, config: config, renderer: renderer)
    }

    private func colorForGForce(_ g: Double, config: GMeterDigitalConfiguration) -> SerializableColor {
        let absG = abs(g)
        if absG >= config.extremeGThreshold {
            return config.extremeGColor
        } else if absG >= config.highGThreshold {
            return config.highGColor
        } else {
            return config.positiveColor
        }
    }

    private func renderDigital(
        context: MetalRenderContext,
        gForce: Double,
        textColor: SerializableColor,
        config: GMeterDigitalConfiguration,
        renderer: Metal2DRenderer
    ) {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = config.decimalPlaces
        formatter.maximumFractionDigits = config.decimalPlaces
        let gText = formatter.string(from: NSNumber(value: gForce)) ?? "0"
        let displayText = config.showLabel ? "\(gText) G" : gText

        #if canImport(AppKit)
        let scale = max(1.0, context.scale)
        let font = NSFont.monospacedDigitSystemFont(ofSize: config.fontSize, weight: .bold)
        if let (texture, size) = MetalTextRenderer.shared.texture(
            text: displayText,
            font: font,
            color: textColor,
            device: context.device,
            scale: scale,
            extraVerticalPadding: config.fontSize * 0.15
        ) {
            let rect = CGRect(
                x: context.bounds.midX - size.width / 2,
                y: context.bounds.midY - size.height / 1.5,
                width: size.width,
                height: size.height
            )
            renderer.drawTexture(texture, in: rect, tintColor: .white, renderContext: context)
        }
        #endif
    }

    // Gauge and bar styles removed; digital-only rendering.

    private func renderNoData(
        context: MetalRenderContext,
        config: GMeterDigitalConfiguration,
        renderer: Metal2DRenderer
    ) {
        #if canImport(AppKit)
        let scale = max(1.0, context.scale)
        let font = NSFont.systemFont(ofSize: 18, weight: .medium)
        if let (texture, size) = MetalTextRenderer.shared.texture(
            text: "No Data",
            font: font,
            color: config.positiveColor.withAlpha(0.5),
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

// MARK: - G-Meter Plugin

/// G-Meter instrument plugin
///
/// Displays G-force (acceleration) with color-coded warnings for high G levels.
/// Supports multiple display styles: digital, gauge, and bar.
public struct GMeterDigitalPlugin: InstrumentPlugin {

    public init() {}

    public static let metadata = PluginMetadata(
        id: "com.flighttrace.g-meter-digital",
        name: "G-Meter (Digital)",
        description: "Displays G-force with visual warnings",
        version: "1.0.0",
        category: .gauge,
        iconName: "gauge.with.needle.fill"
    )

    public static let dataDependencies: Set<TelemetryDataType> = [.gForce, .timestamp]

    public static let defaultSize = CGSize(width: 200, height: 100)

    public static let minimumSize = CGSize(width: 120, height: 80)

    public func createConfiguration() -> any InstrumentConfiguration {
        GMeterDigitalConfiguration()
    }

    public func createRenderer() -> any InstrumentRenderer {
        GMeterDigitalRenderer()
    }
}
