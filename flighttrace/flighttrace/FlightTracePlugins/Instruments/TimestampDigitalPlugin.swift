// TimestampDigitalPlugin.swift
// Timestamp display instrument plugin (Metal)

import Foundation
import CoreGraphics

#if canImport(AppKit)
import AppKit
import FlightTraceCore
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

// MARK: - Timestamp Digital Configuration

/// Configuration for the Timestamp Digital instrument
public struct TimestampDigitalConfiguration: InstrumentConfiguration, Codable {
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

    public func updatingProperty(key: String, value: Any) -> TimestampDigitalConfiguration? {
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
            return nil
        }

        return updated
    }
}

// MARK: - Timestamp Digital Renderer

/// Renderer for the Timestamp Digital instrument
public struct TimestampDigitalRenderer: InstrumentRenderer {

    public init() {}

    public func render(
        context: MetalRenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        guard let config = configuration as? TimestampDigitalConfiguration else {
            return
        }

        guard let point = dataProvider.currentPoint() else {
            renderNoData(context: context, config: config)
            return
        }

        let timestamp = point.timestamp

        let renderer = Metal2DRenderer.shared(for: context.device)
        let bounds = context.bounds
        let backgroundRect = bounds.insetBy(dx: config.padding, dy: config.padding)

        renderer.drawRoundedRect(
            in: backgroundRect,
            radius: config.cornerRadius,
            color: config.backgroundColor,
            renderContext: context
        )

        renderTimestamp(
            context: context,
            bounds: backgroundRect,
            timestamp: timestamp,
            config: config,
            dataProvider: dataProvider
        )
    }

    private func formatTimestamp(_ timestamp: Date, config: TimestampDigitalConfiguration, startTime: Date?) -> String {
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
        context: MetalRenderContext,
        bounds: CGRect,
        timestamp: Date,
        config: TimestampDigitalConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        #if canImport(AppKit)
        let startTime = dataProvider.track()?.startTime
        let timeText = formatTimestamp(timestamp, config: config, startTime: startTime)

        let scale = max(1.0, context.scale)
        let font = NSFont.monospacedDigitSystemFont(ofSize: config.fontSize, weight: .medium)
        if let (tex, size) = MetalTextRenderer.shared.texture(
            text: timeText,
            font: font,
            color: config.textColor,
            device: context.device,
            scale: scale,
            extraVerticalPadding: config.fontSize * 0.2
        ) {
//            if config.showDate && config.format != .dateTime && config.format != .elapsed {
//                yOffset = -config.dateFontSize * 0.6
//            }

            let rect = CGRect(
                x: bounds.midX - size.width / 2,
                y: bounds.midY - size.height / 1.5,
                width: size.width,
                height: size.height
            )
            let renderer = Metal2DRenderer.shared(for: context.device)
            renderer.drawTexture(tex, in: rect, tintColor: .white, renderContext: context)

            if config.showDate && config.format != .dateTime && config.format != .elapsed {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "EEEE, MMM d, yyyy"
                let dateText = dateFormatter.string(from: timestamp)
                let dateFont = NSFont.systemFont(ofSize: config.dateFontSize, weight: .regular)

                if let (dateTex, dateSize) = MetalTextRenderer.shared.texture(
                    text: dateText,
                    font: dateFont,
                    color: config.textColor.withAlpha(0.8),
                    device: context.device,
                    scale: scale,
                    extraVerticalPadding: config.dateFontSize * 0.2
                ) {
                    let dateRect = CGRect(
                        x: bounds.midX - dateSize.width / 2,
                        y: rect.maxY - 5,
                        width: dateSize.width,
                        height: dateSize.height
                    )
                    renderer.drawTexture(dateTex, in: dateRect, tintColor: .white, renderContext: context)
                }
            }
        }
        #endif
    }

    private func renderNoData(context: MetalRenderContext, config: TimestampDigitalConfiguration) {
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

// MARK: - Timestamp Digital Plugin

/// Timestamp Digital instrument plugin
///
/// Displays the current time from GPS data in various formats.
public struct TimestampDigitalPlugin: InstrumentPlugin {

    public init() {}

    // MARK: - Plugin Identity

    public static let metadata = PluginMetadata(
        id: "com.flighttrace.timestamp-digital",
        name: "Timestamp (Digital)",
        description: "Displays current time or elapsed time",
        version: "1.0.0",
        category: .information,
        iconName: "clock"
    )

    // MARK: - Data Requirements

    public static let dataDependencies: Set<TelemetryDataType> = [.timestamp]

    // MARK: - Default Properties

    public static let defaultSize = CGSize(width: 260, height: 90)

    public static let minimumSize = CGSize(width: 160, height: 60)

    // MARK: - Factory Methods

    public func createConfiguration() -> any InstrumentConfiguration {
        TimestampDigitalConfiguration()
    }

    public func createRenderer() -> any InstrumentRenderer {
        TimestampDigitalRenderer()
    }
}
