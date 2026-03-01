// DistanceDigitalPlugin.swift
// Distance traveled instrument plugin (Metal)

import Foundation
import CoreGraphics

#if canImport(AppKit)
import AppKit
import FlightTraceCore
#endif

// MARK: - Distance Unit

/// Units for displaying distance
public enum DistanceUnit: String, Sendable, Codable, CaseIterable, Equatable {
    case meters = "m"
    case kilometers = "km"
    case miles = "mi"
    case nauticalMiles = "nm"
    case feet = "ft"

    /// Convert meters to this unit
    public func convert(meters: Double) -> Double {
        switch self {
        case .meters:
            return meters
        case .kilometers:
            return meters / 1000.0
        case .miles:
            return meters / 1609.34
        case .nauticalMiles:
            return meters / 1852.0
        case .feet:
            return meters * 3.28084
        }
    }
}

// MARK: - Distance Mode

/// Mode for distance calculation
public enum DistanceMode: String, Sendable, Codable, CaseIterable, Equatable {
    case total = "Total Distance"
    case fromStart = "From Start"
    case remaining = "Remaining"
}

// MARK: - Distance Configuration

/// Configuration for the Distance Traveled instrument
public struct DistanceDigitalConfiguration: InstrumentConfiguration, Codable, Sendable {
    public var id: UUID = UUID()

    /// The unit to display distance in
    public var units: DistanceUnit = .kilometers

    /// Distance calculation mode
    public var mode: DistanceMode = .fromStart

    /// Number of decimal places to display
    public var decimalPlaces: Int = 2

    /// Whether to auto-scale units (e.g., m to km)
    public var autoScale: Bool = true

    /// Text color for the distance value
    public var textColor: SerializableColor = .white

    /// Background color
    public var backgroundColor: SerializableColor = SerializableColor.black.withAlpha(0.7)

    /// Whether to show the unit label
    public var showLabel: Bool = true

    /// Whether to show the mode label
    public var showModeLabel: Bool = true

    /// Font size for the distance value
    public var fontSize: Double = 48.0

    /// Font size for labels
    public var labelFontSize: Double = 18.0

    /// Corner radius for the background
    public var cornerRadius: Double = 8.0

    public init(
        id: UUID = UUID(),
        units: DistanceUnit = .kilometers,
        mode: DistanceMode = .fromStart,
        decimalPlaces: Int = 2,
        autoScale: Bool = true,
        textColor: SerializableColor = .white,
        backgroundColor: SerializableColor = SerializableColor.black.withAlpha(0.7),
        showLabel: Bool = true,
        showModeLabel: Bool = true,
        fontSize: Double = 48.0,
        labelFontSize: Double = 18.0,
        cornerRadius: Double = 8.0
    ) {
        self.id = id
        self.units = units
        self.mode = mode
        self.decimalPlaces = decimalPlaces
        self.autoScale = autoScale
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.showLabel = showLabel
        self.showModeLabel = showModeLabel
        self.fontSize = fontSize
        self.labelFontSize = labelFontSize
        self.cornerRadius = cornerRadius
    }

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
                key: "mode",
                value: mode,
                options: DistanceMode.allCases,
                label: "Distance Mode"
            ),
            .enumeration(
                key: "units",
                value: units,
                options: DistanceUnit.allCases,
                label: "Distance Unit"
            ),
            .integer(
                key: "decimalPlaces",
                value: decimalPlaces,
                range: 0...3,
                label: "Decimal Places"
            ),
            .boolean(
                key: "autoScale",
                value: autoScale,
                label: "Auto-scale Units"
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
            .boolean(
                key: "showModeLabel",
                value: showModeLabel,
                label: "Show Mode Label"
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

    public func updatingProperty(key: String, value: Any) -> DistanceDigitalConfiguration? {
        var updated = self

        switch key {
        case "mode":
            if let enumValue = value as? DistanceMode {
                updated.mode = enumValue
            } else if let stringValue = value as? String, let mode = DistanceMode(rawValue: stringValue) {
                updated.mode = mode
            }
        case "units":
            if let enumValue = value as? DistanceUnit {
                updated.units = enumValue
            } else if let stringValue = value as? String, let unit = DistanceUnit(rawValue: stringValue) {
                updated.units = unit
            }
        case "decimalPlaces":
            if let intValue = value as? Int {
                updated.decimalPlaces = intValue
            } else if let doubleValue = value as? Double {
                updated.decimalPlaces = Int(doubleValue)
            }
        case "autoScale":
            if let boolValue = value as? Bool {
                updated.autoScale = boolValue
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
        case "showModeLabel":
            if let boolValue = value as? Bool {
                updated.showModeLabel = boolValue
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

// MARK: - Distance Renderer (Metal)

public struct DistanceDigitalRenderer: InstrumentRenderer {

    public init() {}

    public func render(
        context: MetalRenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        guard let config = configuration as? DistanceDigitalConfiguration else {
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

        guard let distanceMeters = calculateDistanceMeters(config: config, dataProvider: dataProvider) else {
            renderNoData(context: context, config: config, renderer: renderer)
            return
        }

        renderDistance(
            context: context,
            distanceInMeters: distanceMeters,
            config: config,
            renderer: renderer
        )
    }

    // MARK: - Distance Calculation

    /// Calculates traveled distance along the track (not just distance from origin).
    private func calculateDistanceMeters(
        config: DistanceDigitalConfiguration,
        dataProvider: TelemetryDataProvider
    ) -> Double? {
        guard let track = dataProvider.track(),
              let stats = dataProvider.trackStatistics() else {
            return nil
        }

        switch config.mode {
        case .total:
            return stats.totalDistance
        case .fromStart:
            guard let currentPoint = dataProvider.currentPoint(),
                  let currentIndex = track.points.firstIndex(where: { $0.timestamp >= currentPoint.timestamp }) else {
                return nil
            }
            return track.points[0...currentIndex].compactMap { $0.distanceFromPrevious }.reduce(0, +)
        case .remaining:
            guard let currentPoint = dataProvider.currentPoint(),
                  let currentIndex = track.points.firstIndex(where: { $0.timestamp >= currentPoint.timestamp }) else {
                return nil
            }
            return track.points[currentIndex...].compactMap { $0.distanceFromPrevious }.reduce(0, +)
        }
    }

    // MARK: - Rendering

    private func renderDistance(
        context: MetalRenderContext,
        distanceInMeters: Double,
        config: DistanceDigitalConfiguration,
        renderer: Metal2DRenderer
    ) {
        // Determine unit and convert
        var unit = config.units
        if config.autoScale {
            if distanceInMeters < 1000 {
                unit = .meters
            } else if distanceInMeters < 10000 {
                unit = .kilometers
            } else {
                unit = config.units
            }
        }

        let distanceValue = unit.convert(meters: distanceInMeters)
        let distanceText = formattedDistance(value: distanceValue, decimals: config.decimalPlaces)

        #if canImport(AppKit)
        let scale = max(1.0, context.scale)
        // var modeLabelSize: CGSize?

        let font = NSFont.monospacedDigitSystemFont(ofSize: config.fontSize, weight: .bold)
        if let (valueTex, valueSize) = MetalTextRenderer.shared.texture(
            text: distanceText,
            font: font,
            color: config.textColor,
            device: context.device,
            scale: scale,
            extraVerticalPadding: config.fontSize * 0.15
        ) {
            // Center the value exactly: midY - (textHeight / 2)
            let valueRect = CGRect(
                x: context.bounds.midX - valueSize.width / 2,
                y: context.bounds.midY - valueSize.height / 1.5,
                width: valueSize.width,
                height: valueSize.height
            )
            renderer.drawTexture(valueTex, in: valueRect, tintColor: .white, renderContext: context)

            if config.showModeLabel {
                let modeLabel: String
                switch config.mode {
                case .total:
                    modeLabel = "TOTAL"
                case .fromStart:
                    modeLabel = "FROM START"
                case .remaining:
                    modeLabel = "REMAINING"
                }
                let modeFont = NSFont.systemFont(ofSize: config.labelFontSize * 0.7, weight: .semibold)
                if let (modeTex, modeSize) = MetalTextRenderer.shared.texture(
                    text: modeLabel,
                    font: modeFont,
                    color: config.textColor.withAlpha(0.6),
                    device: context.device,
                    scale: scale,
                    extraVerticalPadding: 0
                ) {
                    let modeRect = CGRect(
                        x: context.bounds.midX - modeSize.width / 2,
                        y: valueRect.minY - modeSize.height + 13,
                        width: modeSize.width,
                        height: modeSize.height
                    )
                    renderer.drawTexture(modeTex, in: modeRect, tintColor: .white, renderContext: context)
                }
            }

            if config.showLabel {
                let unitFont = NSFont.systemFont(ofSize: config.labelFontSize, weight: .medium)
                if let (unitTex, unitSize) = MetalTextRenderer.shared.texture(
                    text: unit.rawValue,
                    font: unitFont,
                    color: config.textColor.withAlpha(0.7),
                    device: context.device,
                    scale: scale,
                    extraVerticalPadding: config.labelFontSize * 0.2
                ) {
                    let unitRect = CGRect(
                        x: context.bounds.midX - unitSize.width / 2,
                        y: valueRect.maxY - 14,
                        width: unitSize.width,
                        height: unitSize.height
                    )
                    renderer.drawTexture(unitTex, in: unitRect, tintColor: .white, renderContext: context)
                }
            }
        }
        #endif
    }

    private func renderNoData(
        context: MetalRenderContext,
        config: DistanceDigitalConfiguration,
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

    private func formattedDistance(value: Double, decimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
}

// MARK: - Distance Plugin

/// Distance Traveled instrument plugin
///
/// Displays total distance traveled, distance from start, or remaining distance.
/// Supports multiple distance units with auto-scaling.
public struct DistanceDigitalPlugin: InstrumentPlugin {

    public init() {}

    public static let metadata = PluginMetadata(
        id: "com.flighttrace.distance-digital",
        name: "Distance (Digital)",
        description: "Displays distance traveled or remaining",
        version: "1.0.0",
        category: .information,
        iconName: "point.topleft.down.curvedto.point.bottomright.up"
    )

    public static let dataDependencies: Set<TelemetryDataType> = [.coordinate, .distance, .timestamp]

    public static let defaultSize = CGSize(width: 240, height: 120)

    public static let minimumSize = CGSize(width: 160, height: 90)

    public func createConfiguration() -> any InstrumentConfiguration {
        DistanceDigitalConfiguration()
    }

    public func createRenderer() -> any InstrumentRenderer {
        DistanceDigitalRenderer()
    }
}

