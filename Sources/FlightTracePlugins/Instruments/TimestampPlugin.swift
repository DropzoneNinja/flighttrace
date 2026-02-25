// TimestampPlugin.swift
// Timestamp display instrument plugin

import Foundation
import CoreGraphics

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Timestamp Format

/// Format for displaying timestamp
public enum TimestampFormat: String, Sendable, Codable, CaseIterable, Equatable {
    case time12Hour = "12-Hour Time"
    case time24Hour = "24-Hour Time"
    case timeWithSeconds = "Time with Seconds"
    case dateTime = "Date & Time"
    case elapsed = "Elapsed Time"
    case iso8601 = "ISO 8601"
}

// MARK: - Timestamp Configuration

/// Configuration for the Timestamp Display instrument
public struct TimestampConfiguration: InstrumentConfiguration, Codable {
    public var id = UUID()

    /// Format for displaying the timestamp
    public var format: TimestampFormat = .time12Hour

    /// Text color for the timestamp
    public var textColor: SerializableColor = .white

    /// Background color
    public var backgroundColor: SerializableColor = SerializableColor.black.withAlpha(0.7)

    /// Whether to show date
    public var showDate: Bool = false

    /// Whether to show time zone
    public var showTimeZone: Bool = false

    /// Font size for the timestamp value
    public var fontSize: Double = 36.0

    /// Font size for the date (if shown)
    public var dateFontSize: Double = 18.0

    /// Corner radius for the background
    public var cornerRadius: Double = 8.0

    /// Padding inside the display
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
                key: "format",
                value: format,
                options: TimestampFormat.allCases,
                label: "Time Format"
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
                key: "showDate",
                value: showDate,
                label: "Show Date"
            ),
            .boolean(
                key: "showTimeZone",
                value: showTimeZone,
                label: "Show Time Zone"
            ),
            .slider(
                key: "fontSize",
                value: fontSize,
                range: 18.0...72.0,
                step: 2.0,
                label: "Font Size"
            ),
            .slider(
                key: "dateFontSize",
                value: dateFontSize,
                range: 12.0...36.0,
                step: 2.0,
                label: "Date Font Size"
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

    public func updatingProperty(key: String, value: Any) -> TimestampConfiguration? {
        var updated = self

        switch key {
        case "format":
            if let enumValue = value as? TimestampFormat {
                updated.format = enumValue
            } else if let stringValue = value as? String, let format = TimestampFormat(rawValue: stringValue) {
                updated.format = format
            }
        case "textColor":
            if let colorValue = value as? SerializableColor {
                updated.textColor = colorValue
            }
        case "backgroundColor":
            if let colorValue = value as? SerializableColor {
                updated.backgroundColor = colorValue
            }
        case "showDate":
            if let boolValue = value as? Bool {
                updated.showDate = boolValue
            }
        case "showTimeZone":
            if let boolValue = value as? Bool {
                updated.showTimeZone = boolValue
            }
        case "fontSize":
            if let doubleValue = value as? Double {
                updated.fontSize = doubleValue
            }
        case "dateFontSize":
            if let doubleValue = value as? Double {
                updated.dateFontSize = doubleValue
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

// MARK: - Timestamp Renderer

/// Renderer for the Timestamp Display instrument
public struct TimestampRenderer: InstrumentRenderer {

    public init() {}

    public func render(
        context: CGContext,
        renderContext: RenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        guard let config = configuration as? TimestampConfiguration else {
            return
        }

        // Get current telemetry data
        guard let point = dataProvider.currentPoint() else {
            // Render "No Data" message
            renderNoData(context: context, renderContext: renderContext, config: config)
            return
        }

        let timestamp = point.timestamp

        // Render background
        renderBackground(context: context, bounds: renderContext.bounds, config: config)

        // Format and render timestamp
        renderTimestamp(
            context: context,
            bounds: renderContext.bounds,
            timestamp: timestamp,
            config: config,
            dataProvider: dataProvider
        )
    }

    // MARK: - Private Rendering Methods

    private func renderBackground(context: CGContext, bounds: CGRect, config: TimestampConfiguration) {
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

    private func formatTimestamp(_ timestamp: Date, config: TimestampConfiguration, startTime: Date?) -> String {
        let formatter = DateFormatter()

        switch config.format {
        case .time12Hour:
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: timestamp)

        case .time24Hour:
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: timestamp)

        case .timeWithSeconds:
            formatter.dateFormat = "HH:mm:ss"
            return formatter.string(from: timestamp)

        case .dateTime:
            formatter.dateFormat = config.showTimeZone ? "MMM d, h:mm a z" : "MMM d, h:mm a"
            return formatter.string(from: timestamp)

        case .elapsed:
            guard let start = startTime else {
                return "00:00:00"
            }
            let elapsed = timestamp.timeIntervalSince(start)
            let hours = Int(elapsed) / 3600
            let minutes = (Int(elapsed) % 3600) / 60
            let seconds = Int(elapsed) % 60
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)

        case .iso8601:
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            return formatter.string(from: timestamp)
        }
    }

    private func renderTimestamp(
        context: CGContext,
        bounds: CGRect,
        timestamp: Date,
        config: TimestampConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        #if canImport(AppKit)
        // Get start time for elapsed time calculation
        let startTime = dataProvider.track()?.startTime

        // Format timestamp
        let timeText = formatTimestamp(timestamp, config: config, startTime: startTime)

        // Create attributed string for time
        let font = NSFont.monospacedDigitSystemFont(
            ofSize: config.fontSize,
            weight: .medium
        )
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: config.textColor.nsColor
        ]
        let attributedString = NSAttributedString(string: timeText, attributes: attributes)

        // Calculate text size and position
        let textSize = attributedString.size()

        var yOffset: CGFloat = 0
        if config.showDate && config.format != .dateTime && config.format != .elapsed {
            yOffset = -config.dateFontSize / 2 - 5
        }

        let textRect = CGRect(
            x: bounds.midX - textSize.width / 2,
            y: bounds.midY - textSize.height / 2 + yOffset,
            width: textSize.width,
            height: textSize.height
        )

        // Draw time text
        attributedString.draw(in: textRect)

        // Draw date if enabled
        if config.showDate && config.format != .dateTime && config.format != .elapsed {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEEE, MMM d, yyyy"
            let dateText = dateFormatter.string(from: timestamp)

            let dateFont = NSFont.systemFont(ofSize: config.dateFontSize, weight: .regular)
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: dateFont,
                .foregroundColor: config.textColor.nsColor.withAlphaComponent(0.8)
            ]
            let dateAttributedString = NSAttributedString(string: dateText, attributes: dateAttributes)
            let dateSize = dateAttributedString.size()

            let dateRect = CGRect(
                x: bounds.midX - dateSize.width / 2,
                y: textRect.maxY + 5,
                width: dateSize.width,
                height: dateSize.height
            )

            dateAttributedString.draw(in: dateRect)
        }
        #endif
    }

    private func renderNoData(
        context: CGContext,
        renderContext: RenderContext,
        config: TimestampConfiguration
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

// MARK: - Timestamp Plugin

/// Timestamp Display instrument plugin
///
/// Displays the current time from GPS data in various formats.
/// Supports 12/24-hour time, elapsed time, and date display.
public struct TimestampPlugin: InstrumentPlugin {

    public init() {}

    // MARK: - Plugin Identity

    public static let metadata = PluginMetadata(
        id: "com.flighttrace.timestamp",
        name: "Timestamp",
        description: "Displays current time or elapsed time",
        version: "1.0.0",
        category: .information,
        iconName: "clock.fill"
    )

    // MARK: - Data Requirements

    public static let dataDependencies: Set<TelemetryDataType> = [.timestamp]

    // MARK: - Default Properties

    public static let defaultSize = CGSize(width: 250, height: 80)

    public static let minimumSize = CGSize(width: 150, height: 50)

    // MARK: - Factory Methods

    public func createConfiguration() -> any InstrumentConfiguration {
        TimestampConfiguration()
    }

    public func createRenderer() -> any InstrumentRenderer {
        TimestampRenderer()
    }
}
