// SpeedDigitalPlugin.swift
// Digital speed display instrument plugin (Metal)

import Foundation
import CoreGraphics

#if canImport(AppKit)
import AppKit
import FlightTraceCore
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

// MARK: - Speed Digital Configuration

/// Configuration for the Speed Digital instrument
public struct SpeedDigitalConfiguration: InstrumentConfiguration, Codable, Sendable {
    public var id: UUID = UUID()

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

    public func updatingProperty(key: String, value: Any) -> SpeedDigitalConfiguration? {
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
            return nil
        }

        return updated
    }
}

// MARK: - Speed Digital Renderer

/// Renderer for the Speed Digital instrument
public struct SpeedDigitalRenderer: InstrumentRenderer {

    public init() {}

    public func render(
        context: MetalRenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        guard let config = configuration as? SpeedDigitalConfiguration else {
            return
        }

        guard let point = dataProvider.currentPoint(), let speed = point.speed else {
            renderNoData(context: context, config: config)
            return
        }

        let speedValue = config.units.convert(metersPerSecond: speed)

        let renderer = Metal2DRenderer.shared(for: context.device)
        let bounds = context.bounds
        let backgroundRect = bounds.insetBy(dx: config.padding, dy: config.padding)

        renderer.drawRoundedRect(
            in: backgroundRect,
            radius: config.cornerRadius,
            color: config.backgroundColor,
            renderContext: context
        )

        renderSpeedValue(
            context: context,
            bounds: backgroundRect,
            speedValue: speedValue,
            config: config
        )

        if config.showLabel {
            renderUnitLabel(
                context: context,
                bounds: backgroundRect,
                unit: config.units.rawValue,
                config: config
            )
        }
    }

    private func renderSpeedValue(
        context: MetalRenderContext,
        bounds: CGRect,
        speedValue: Double,
        config: SpeedDigitalConfiguration
    ) {
        #if canImport(AppKit)
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = config.decimalPlaces
        formatter.maximumFractionDigits = config.decimalPlaces
        let speedText = formatter.string(from: NSNumber(value: speedValue)) ?? "0"

        let scale = max(1.0, context.scale)
        let font = NSFont.monospacedDigitSystemFont(ofSize: config.fontSize, weight: .bold)

        if let (tex, size) = MetalTextRenderer.shared.texture(
            text: speedText,
            font: font,
            color: config.textColor,
            device: context.device,
            scale: scale,
            extraVerticalPadding: config.fontSize * 0.2
        ) {
            let rect = CGRect(
                x: bounds.midX - size.width / 2,
                y: bounds.midY - size.height / 1.5,
                width: size.width,
                height: size.height
            )
            let renderer = Metal2DRenderer.shared(for: context.device)
            renderer.drawTexture(tex, in: rect, tintColor: .white, renderContext: context)
        }
        #endif
    }

    private func renderUnitLabel(
        context: MetalRenderContext,
        bounds: CGRect,
        unit: String,
        config: SpeedDigitalConfiguration
    ) {
        #if canImport(AppKit)
        let scale = max(1.0, context.scale)
        let font = NSFont.systemFont(ofSize: config.labelFontSize, weight: .medium)

        if let (tex, size) = MetalTextRenderer.shared.texture(
            text: unit,
            font: font,
            color: config.textColor.withAlpha(0.7),
            device: context.device,
            scale: scale,
            extraVerticalPadding: config.labelFontSize * 0.2
        ) {
            let rect = CGRect(
                x: bounds.midX - size.width / 2,
                y: bounds.midY + config.fontSize * 0.35,
                width: size.width,
                height: size.height
            )
            let renderer = Metal2DRenderer.shared(for: context.device)
            renderer.drawTexture(tex, in: rect, tintColor: .white, renderContext: context)
        }
        #endif
    }

    private func renderNoData(context: MetalRenderContext, config: SpeedDigitalConfiguration) {
        let renderer = Metal2DRenderer.shared(for: context.device)
        let bounds = context.bounds
        let backgroundRect = bounds.insetBy(dx: config.padding, dy: config.padding)

        renderer.drawRoundedRect(
            in: backgroundRect,
            radius: config.cornerRadius,
            color: config.backgroundColor,
            renderContext: context
        )

        #if canImport(AppKit)
        let scale = max(1.0, context.scale)
        let font = NSFont.systemFont(ofSize: 18, weight: .medium)
        if let (tex, size) = MetalTextRenderer.shared.texture(
            text: "NO DATA",
            font: font,
            color: config.textColor.withAlpha(0.5),
            device: context.device,
            scale: scale,
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

// MARK: - Speed Digital Plugin

/// Speed Digital instrument plugin
///
/// Displays current speed as a digital readout with configurable units and styling.
public struct SpeedDigitalPlugin: InstrumentPlugin {

    public init() {}

    // MARK: - Plugin Identity

    public static let metadata = PluginMetadata(
        id: "com.flighttrace.speed-digital",
        name: "Speed (Digital)",
        description: "Displays current speed with configurable units",
        version: "1.0.0",
        category: .gauge,
        iconName: "speedometer"
    )

    // MARK: - Data Requirements

    public static let dataDependencies: Set<TelemetryDataType> = [.speed, .timestamp]

    // MARK: - Default Properties

    public static let defaultSize = CGSize(width: 240, height: 120)

    public static let minimumSize = CGSize(width: 140, height: 80)

    // MARK: - Factory Methods

    public func createConfiguration() -> any InstrumentConfiguration {
        SpeedDigitalConfiguration()
    }

    public func createRenderer() -> any InstrumentRenderer {
        SpeedDigitalRenderer()
    }
}

