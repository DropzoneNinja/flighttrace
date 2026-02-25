// DistancePlugin.swift
// Distance traveled instrument plugin

import Foundation
import CoreGraphics
import CoreLocation

#if canImport(AppKit)
import AppKit
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

    /// Get appropriate unit for distance value (auto-scaling)
    public static func appropriate(forMeters meters: Double) -> DistanceUnit {
        if meters < 1000 {
            return .meters
        } else {
            return .kilometers
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
public struct DistanceConfiguration: InstrumentConfiguration, Codable {
    public var id = UUID()

    /// The unit to display distance in
    public var units: DistanceUnit = .kilometers

    /// Distance calculation mode
    public var mode: DistanceMode = .total

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

    public func updatingProperty(key: String, value: Any) -> DistanceConfiguration? {
        var updated = self

        switch key {
        case "mode":
            if let enumValue = value as? DistanceMode {
                print("🔍 DistanceConfiguration: updating mode to \(enumValue.rawValue)")
                updated.mode = enumValue
            } else if let stringValue = value as? String, let mode = DistanceMode(rawValue: stringValue) {
                print("🔍 DistanceConfiguration: updating mode from string '\(stringValue)' to \(mode.rawValue)")
                updated.mode = mode
            } else {
                print("🔍 DistanceConfiguration: ERROR - could not parse mode from value: \(value) (type: \(type(of: value)))")
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
            return nil // Unknown property
        }

        return updated
    }
}

// MARK: - Distance Renderer

/// Renderer for the Distance Traveled instrument
public struct DistanceRenderer: InstrumentRenderer {

    public init() {}

    public func render(
        context: CGContext,
        renderContext: RenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        guard let config = configuration as? DistanceConfiguration else {
            print("🔍 DistancePlugin: ERROR - configuration is not DistanceConfiguration type!")
            return
        }

        print("🔍 DistancePlugin.render(): mode=\(config.mode.rawValue)")

        // Get track statistics
        guard let stats = dataProvider.trackStatistics() else {
            // Render "No Data" message
            renderNoData(context: context, renderContext: renderContext, config: config)
            return
        }

        print("🔍 DistancePlugin: mode=\(config.mode), totalDistance=\(stats.totalDistance)")

        // Calculate distance based on mode
        let distanceInMeters: Double
        switch config.mode {
        case .total:
            distanceInMeters = stats.totalDistance
            print("🔍 DistancePlugin [TOTAL]: using total distance = \(distanceInMeters)")
        case .fromStart:
            // Calculate accumulated distance from start to current position
            if let currentPoint = dataProvider.currentPoint(),
               let track = dataProvider.track(),
               let currentIndex = track.points.firstIndex(where: { $0.timestamp >= currentPoint.timestamp }) {
                print("🔍 DistancePlugin [FROM_START]: currentPoint.timestamp=\(currentPoint.timestamp), currentIndex=\(currentIndex)/\(track.points.count)")

                // Sum all distances from start up to (and including) current position
                distanceInMeters = track.points[0...currentIndex].compactMap { $0.distanceFromPrevious }.reduce(0, +)
                print("🔍 DistancePlugin [FROM_START]: accumulated distance = \(distanceInMeters)")
            } else {
                print("🔍 DistancePlugin [FROM_START]: ERROR - could not find current point or track")
                print("🔍   - currentPoint: \(dataProvider.currentPoint()?.timestamp.description ?? "nil")")
                print("🔍   - track: \(dataProvider.track() != nil ? "exists" : "nil")")
                distanceInMeters = 0
            }
        case .remaining:
            // Calculate remaining distance to end
            if let currentPoint = dataProvider.currentPoint(),
               let track = dataProvider.track(),
               let currentIndex = track.points.firstIndex(where: { $0.timestamp >= currentPoint.timestamp }) {
                print("🔍 DistancePlugin [REMAINING]: currentPoint.timestamp=\(currentPoint.timestamp), currentIndex=\(currentIndex)/\(track.points.count)")

                // Sum remaining segments from current position to end
                distanceInMeters = track.points[currentIndex...].compactMap { $0.distanceFromPrevious }.reduce(0, +)
                print("🔍 DistancePlugin [REMAINING]: remaining distance = \(distanceInMeters)")
            } else {
                print("🔍 DistancePlugin [REMAINING]: ERROR - could not find current point or track")
                distanceInMeters = 0
            }
        }

        // Render background
        renderBackground(context: context, bounds: renderContext.bounds, config: config)

        // Render distance value
        renderDistance(
            context: context,
            bounds: renderContext.bounds,
            distanceInMeters: distanceInMeters,
            config: config
        )
    }

    // MARK: - Private Rendering Methods

    private func renderBackground(context: CGContext, bounds: CGRect, config: DistanceConfiguration) {
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

    private func renderDistance(
        context: CGContext,
        bounds: CGRect,
        distanceInMeters: Double,
        config: DistanceConfiguration
    ) {
        // Determine unit and convert
        var unit = config.units
        if config.autoScale {
            // Auto-scale based on distance
            if distanceInMeters < 1000 {
                unit = .meters
            } else if distanceInMeters < 10000 {
                unit = .kilometers
            } else {
                unit = config.units
            }
        }

        let distanceValue = unit.convert(meters: distanceInMeters)

        // Format the distance value
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = config.decimalPlaces
        formatter.maximumFractionDigits = config.decimalPlaces
        formatter.numberStyle = .decimal
        let distanceText = formatter.string(from: NSNumber(value: distanceValue)) ?? "0"

        #if canImport(AppKit)
        var yOffset: CGFloat = 0

        // Render mode label if enabled
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

            let font = NSFont.systemFont(ofSize: config.labelFontSize * 0.7, weight: .semibold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: config.textColor.nsColor.withAlphaComponent(0.6)
            ]
            let attributedString = NSAttributedString(string: modeLabel, attributes: attributes)
            let textSize = attributedString.size()
            let textRect = CGRect(
                x: bounds.midX - textSize.width / 2,
                y: bounds.minY + 10,
                width: textSize.width,
                height: textSize.height
            )
            attributedString.draw(in: textRect)
            yOffset = 15
        }

        // Create attributed string with font
        let font = NSFont.monospacedDigitSystemFont(
            ofSize: config.fontSize,
            weight: .bold
        )
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: config.textColor.nsColor
        ]
        let attributedString = NSAttributedString(string: distanceText, attributes: attributes)

        // Calculate text size and position
        let textSize = attributedString.size()

        // Position text in center (or slightly below if mode label is shown)
        let textRect = CGRect(
            x: bounds.midX - textSize.width / 2,
            y: bounds.midY - textSize.height / 2 + yOffset,
            width: textSize.width,
            height: textSize.height
        )

        // Draw text
        attributedString.draw(in: textRect)

        // Render unit label if enabled
        if config.showLabel {
            let unitFont = NSFont.systemFont(ofSize: config.labelFontSize, weight: .medium)
            let unitAttributes: [NSAttributedString.Key: Any] = [
                .font: unitFont,
                .foregroundColor: config.textColor.nsColor.withAlphaComponent(0.7)
            ]
            let unitString = NSAttributedString(string: unit.rawValue, attributes: unitAttributes)

            let unitSize = unitString.size()
            let unitRect = CGRect(
                x: bounds.midX - unitSize.width / 2,
                y: textRect.maxY + 5,
                width: unitSize.width,
                height: unitSize.height
            )

            unitString.draw(in: unitRect)
        }
        #endif
    }

    private func renderNoData(
        context: CGContext,
        renderContext: RenderContext,
        config: DistanceConfiguration
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

// MARK: - Distance Plugin

/// Distance Traveled instrument plugin
///
/// Displays total distance traveled, distance from start, or remaining distance.
/// Supports multiple distance units with auto-scaling.
public struct DistancePlugin: InstrumentPlugin {

    public init() {}

    // MARK: - Plugin Identity

    public static let metadata = PluginMetadata(
        id: "com.flighttrace.distance",
        name: "Distance Traveled",
        description: "Displays distance traveled or remaining",
        version: "1.0.0",
        category: .information,
        iconName: "point.topleft.down.curvedto.point.bottomright.up"
    )

    // MARK: - Data Requirements

    public static let dataDependencies: Set<TelemetryDataType> = [.coordinate, .distance, .timestamp]

    // MARK: - Default Properties

    public static let defaultSize = CGSize(width: 220, height: 120)

    public static let minimumSize = CGSize(width: 150, height: 80)

    // MARK: - Factory Methods

    public func createConfiguration() -> any InstrumentConfiguration {
        DistanceConfiguration()
    }

    public func createRenderer() -> any InstrumentRenderer {
        DistanceRenderer()
    }
}
