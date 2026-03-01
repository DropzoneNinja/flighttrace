// AltitudeDigitalPlugin.swift
// Digital altitude display instrument plugin (Metal)

import Foundation
import CoreGraphics

#if canImport(AppKit)
import AppKit
import FlightTraceCore
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
public struct AltitudeDigitalConfiguration: InstrumentConfiguration, Codable {
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

    public func updatingProperty(key: String, value: Any) -> AltitudeDigitalConfiguration? {
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

// MARK: - Altitude Gauge Renderer (Metal)

public struct AltitudeDigitalRenderer: InstrumentRenderer {

    public init() {}

    public func render(
        context: MetalRenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        guard let config = configuration as? AltitudeDigitalConfiguration else {
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

        guard let point = dataProvider.currentPoint(), let elevation = point.elevation else {
            renderNoData(context: context, config: config, renderer: renderer)
            return
        }

        let altitudeValue = config.units.convert(meters: elevation)
        let altitudeText = formattedAltitude(value: altitudeValue, decimals: config.decimalPlaces)

        #if canImport(AppKit)
        let valueFont = NSFont.monospacedDigitSystemFont(
            ofSize: config.fontSize,
            weight: .bold
        )
        let labelFont = NSFont.systemFont(
            ofSize: config.labelFontSize,
            weight: .medium
        )

        let scale = max(1.0, context.scale)

        let verticalPadding = max(2.0, config.fontSize * 0.15)
        if let (valueTexture, valueSize) = MetalTextRenderer.shared.texture(
            text: altitudeText,
            font: valueFont,
            color: config.textColor,
            device: context.device,
            scale: scale,
            extraVerticalPadding: verticalPadding
        ) {
            let yOffset = config.showLabel ? -(config.labelFontSize * 0.75) : 0
            var valueRect = CGRect(
                x: context.bounds.midX - valueSize.width / 2,
                y: context.bounds.midY - valueSize.height / 2 + yOffset,
                width: valueSize.width,
                height: valueSize.height
            )
            let minY = context.bounds.minY + config.padding
            if valueRect.minY < minY {
                valueRect.origin.y = minY
            }
            renderer.drawTexture(valueTexture, in: valueRect, tintColor: .white, renderContext: context)
        }

        if config.showLabel {
            let unitText = config.units.rawValue
            if let (labelTexture, labelSize) = MetalTextRenderer.shared.texture(
                text: unitText,
                font: labelFont,
                color: config.textColor.withAlpha(0.7),
                device: context.device,
                scale: scale
            ) {
                let labelRect = CGRect(
                    x: context.bounds.midX - labelSize.width / 2,
                    y: context.bounds.midY + config.fontSize / 3.0,
                    width: labelSize.width,
                    height: labelSize.height
                )
                renderer.drawTexture(labelTexture, in: labelRect, tintColor: .white, renderContext: context)
            }
        }
        #endif
    }

    private func formattedAltitude(value: Double, decimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }

    private func renderNoData(
        context: MetalRenderContext,
        config: AltitudeDigitalConfiguration,
        renderer: Metal2DRenderer
    ) {
        #if canImport(AppKit)
        let font = NSFont.systemFont(ofSize: 18, weight: .medium)
        let scale = max(1.0, context.scale)
        if let (texture, size) = MetalTextRenderer.shared.texture(
            text: "No Data",
            font: font,
            color: config.textColor.withAlpha(0.5),
            device: context.device,
            scale: scale
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

// MARK: - Altitude Gauge Plugin

/// Altitude Gauge instrument plugin
///
/// Displays current altitude/elevation as a digital readout with configurable units and styling.
/// Supports meters and feet.
public struct AltitudeDigitalPlugin: InstrumentPlugin {

    public init() {}

    public static let metadata = PluginMetadata(
        id: "com.flighttrace.altitude-digital",
        name: "Altitude (Digital)",
        description: "Digital altitude display",
        version: "1.0.0",
        category: .gauge,
        iconName: "mountain.2.fill"
    )

    public static let dataDependencies: Set<TelemetryDataType> = [.elevation, .timestamp]

    public static let defaultSize = CGSize(width: 240, height: 120)

    public func createConfiguration() -> any InstrumentConfiguration {
        AltitudeDigitalConfiguration()
    }

    public func createRenderer() -> any InstrumentRenderer {
        AltitudeDigitalRenderer()
    }
}
