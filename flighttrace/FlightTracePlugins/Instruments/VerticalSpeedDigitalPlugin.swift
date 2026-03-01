// VerticalSpeedDigitalPlugin.swift
// Vertical speed indicator (climb/descent rate) instrument plugin (Metal)

import Foundation
import CoreGraphics

#if canImport(AppKit)
import AppKit
import FlightTraceCore
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
            return metersPerSecond * 196.85
        case .metersPerMinute:
            return metersPerSecond * 60.0
        }
    }
}

// MARK: - Vertical Speed Digital Configuration

/// Configuration for the Vertical Speed Digital instrument
public struct VerticalSpeedDigitalConfiguration: InstrumentConfiguration, Codable, Sendable {
    public var id: UUID = UUID()

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

    /// Padding inside the display
    public var padding: Double = 12.0

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
            ),
            .slider(
                key: "padding",
                value: padding,
                range: 0.0...24.0,
                step: 1.0,
                label: "Padding"
            )
        ]
    }

    // MARK: - Property Updates

    public func updatingProperty(key: String, value: Any) -> VerticalSpeedDigitalConfiguration? {
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
        case "padding":
            if let doubleValue = value as? Double {
                updated.padding = doubleValue
            }
        default:
            return nil
        }

        return updated
    }
}

// MARK: - Vertical Speed Digital Renderer

/// Renderer for the Vertical Speed Digital instrument
public struct VerticalSpeedDigitalRenderer: InstrumentRenderer {

    public init() {}

    public func render(
        context: MetalRenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        guard let config = configuration as? VerticalSpeedDigitalConfiguration else {
            return
        }

        guard let point = dataProvider.currentPoint(), let verticalSpeed = point.verticalSpeed else {
            renderNoData(context: context, config: config)
            return
        }

        let vsValue = config.units.convert(metersPerSecond: verticalSpeed)

        let renderer = Metal2DRenderer.shared(for: context.device)
        let bounds = context.bounds
        let backgroundRect = bounds.insetBy(dx: config.padding, dy: config.padding)

        renderer.drawRoundedRect(
            in: backgroundRect,
            radius: config.cornerRadius,
            color: config.backgroundColor,
            renderContext: context
        )

        let textColor = colorForVerticalSpeed(verticalSpeed, config: config)

        renderVerticalSpeedValue(
            context: context,
            bounds: backgroundRect,
            vsValue: vsValue,
            verticalSpeed: verticalSpeed,
            textColor: textColor,
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

    private func colorForVerticalSpeed(_ vs: Double, config: VerticalSpeedDigitalConfiguration) -> SerializableColor {
        if abs(vs) <= config.levelThreshold {
            return config.levelColor
        } else if vs > 0 {
            return config.climbColor
        } else {
            return config.descentColor
        }
    }

    private func renderVerticalSpeedValue(
        context: MetalRenderContext,
        bounds: CGRect,
        vsValue: Double,
        verticalSpeed: Double,
        textColor: SerializableColor,
        config: VerticalSpeedDigitalConfiguration
    ) {
        #if canImport(AppKit)
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = config.decimalPlaces
        formatter.maximumFractionDigits = config.decimalPlaces
        formatter.positivePrefix = "+"
        let vsText = formatter.string(from: NSNumber(value: vsValue)) ?? "0"

        let arrow = config.showArrow ? arrowForVerticalSpeed(verticalSpeed, config: config) : ""
        let displayText = arrow.isEmpty ? vsText : "\(arrow) \(vsText)"

        let scale = max(1.0, context.scale)
        let font = NSFont.monospacedDigitSystemFont(ofSize: config.fontSize, weight: .bold)

        if let (tex, size) = MetalTextRenderer.shared.texture(
            text: displayText,
            font: font,
            color: textColor,
            device: context.device,
            scale: scale,
            extraVerticalPadding: config.fontSize * 0.2
        ) {
            let yOffset = config.showLabel ? -config.labelFontSize * 0.4 : 0
            let rect = CGRect(
                x: bounds.midX - size.width / 2,
                y: bounds.midY - size.height / 2 + yOffset,
                width: size.width,
                height: size.height
            )
            let renderer = Metal2DRenderer.shared(for: context.device)
            renderer.drawTexture(tex, in: rect, tintColor: .white, renderContext: context)
        }
        #endif
    }

    private func arrowForVerticalSpeed(_ vs: Double, config: VerticalSpeedDigitalConfiguration) -> String {
        if abs(vs) <= config.levelThreshold {
            return "→"
        } else if vs > 0 {
            return "↑"
        } else {
            return "↓"
        }
    }

    private func renderUnitLabel(
        context: MetalRenderContext,
        bounds: CGRect,
        unit: String,
        config: VerticalSpeedDigitalConfiguration
    ) {
        #if canImport(AppKit)
        let scale = max(1.0, context.scale)
        let font = NSFont.systemFont(ofSize: config.labelFontSize, weight: .medium)

        if let (tex, size) = MetalTextRenderer.shared.texture(
            text: unit,
            font: font,
            color: config.levelColor.withAlpha(0.7),
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

    private func renderNoData(context: MetalRenderContext, config: VerticalSpeedDigitalConfiguration) {
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
            color: config.levelColor.withAlpha(0.5),
            device: context.device,
            scale: scale,
            extraVerticalPadding: 4
        ) {
            let rect = CGRect(
                x: bounds.midX - size.width / 2,
                y: bounds.midY - size.height / 1.5,
                width: size.width,
                height: size.height
            )
            renderer.drawTexture(tex, in: rect, tintColor: .white, renderContext: context)
        }
        #endif
    }
}

// MARK: - Vertical Speed Digital Plugin

/// Vertical Speed Digital instrument plugin
public struct VerticalSpeedDigitalPlugin: InstrumentPlugin {

    public init() {}

    // MARK: - Plugin Identity

    public static let metadata = PluginMetadata(
        id: "com.flighttrace.vertical-speed-digital",
        name: "Vertical Speed (Digital)",
        description: "Displays rate of climb or descent",
        version: "1.0.0",
        category: .indicator,
        iconName: "arrow.up.arrow.down"
    )

    // MARK: - Data Requirements

    public static let dataDependencies: Set<TelemetryDataType> = [.verticalSpeed, .timestamp]

    // MARK: - Default Properties

    public static let defaultSize = CGSize(width: 240, height: 120)

    public static let minimumSize = CGSize(width: 140, height: 80)

    // MARK: - Factory Methods

    public func createConfiguration() -> any InstrumentConfiguration {
        VerticalSpeedDigitalConfiguration()
    }

    public func createRenderer() -> any InstrumentRenderer {
        VerticalSpeedDigitalRenderer()
    }
}

