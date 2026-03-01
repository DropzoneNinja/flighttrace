// AltitudeGraphPlugin.swift
// Altitude graph instrument plugin (Metal)

import Foundation
import CoreGraphics
import Metal

#if canImport(AppKit)
import AppKit
import FlightTraceCore
#endif

// MARK: - Altitude Graph Style

public enum AltitudeGraphStyle: String, Sendable, Codable, CaseIterable, Equatable {
    case bars = "Bars"
    case line = "Line"
}

// MARK: - Altitude Graph Configuration

/// Configuration for the Altitude Graph instrument
public struct AltitudeGraphConfiguration: InstrumentConfiguration, Codable {
    public var id = UUID()

    /// Graph style
    public var style: AltitudeGraphStyle = .bars

    /// Altitude units
    public var units: AltitudeUnit = .feet

    /// Decimal places for the max height label
    public var decimalPlaces: Int = 0

    /// Bar color
    public var barColor: SerializableColor = SerializableColor(red: 0.2, green: 0.8, blue: 1.0)

    /// Background color
    public var backgroundColor: SerializableColor = SerializableColor.black.withAlpha(0.6)

    /// Axis line color
    public var axisColor: SerializableColor = SerializableColor.white.withAlpha(0.6)

    /// Label color for the max height value
    public var labelColor: SerializableColor = .white

    /// Label font size
    public var fontSize: Double = 14.0

    /// Padding around content
    public var padding: Double = 12.0

    /// Space between the label and the graph
    public var labelPadding: Double = 6.0

    /// Target bar width (actual width adjusts to fit)
    public var targetBarWidth: Double = 3.0

    /// Spacing between bars
    public var barSpacing: Double = 1.0

    /// Line width for plot style
    public var lineWidth: Double = 2.0

    /// Minimum number of bars
    public var minBarCount: Int = 24

    /// Maximum number of bars
    public var maxBarCount: Int = 400

    /// Minimum alpha for bars that are ahead of the timeline
    public var minBarAlpha: Double = 0.25

    /// Brightness ramp window (fraction of total timeline)
    public var brightnessRamp: Double = 0.06

    /// Rounded corner radius for the background
    public var cornerRadius: Double = 8.0

    /// Whether to draw a background
    public var showBackground: Bool = true

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
                key: "style",
                value: style,
                options: AltitudeGraphStyle.allCases,
                label: "Graph Style"
            ),
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
                key: "barColor",
                value: barColor,
                label: "Bar Color"
            ),
            .color(
                key: "backgroundColor",
                value: backgroundColor,
                label: "Background Color"
            ),
            .color(
                key: "axisColor",
                value: axisColor,
                label: "Axis Color"
            ),
            .color(
                key: "labelColor",
                value: labelColor,
                label: "Label Color"
            ),
            .slider(
                key: "fontSize",
                value: fontSize,
                range: 10.0...28.0,
                step: 1.0,
                label: "Label Font Size"
            ),
            .slider(
                key: "padding",
                value: padding,
                range: 6.0...24.0,
                step: 1.0,
                label: "Padding"
            ),
            .slider(
                key: "labelPadding",
                value: labelPadding,
                range: 2.0...16.0,
                step: 1.0,
                label: "Label Padding"
            ),
            .slider(
                key: "targetBarWidth",
                value: targetBarWidth,
                range: 1.0...10.0,
                step: 0.5,
                label: "Target Bar Width"
            ),
            .slider(
                key: "barSpacing",
                value: barSpacing,
                range: 0.0...6.0,
                step: 0.5,
                label: "Bar Spacing"
            ),
            .slider(
                key: "lineWidth",
                value: lineWidth,
                range: 1.0...8.0,
                step: 0.5,
                label: "Line Width"
            ),
            .integer(
                key: "minBarCount",
                value: minBarCount,
                range: 6...200,
                label: "Minimum Bar Count"
            ),
            .integer(
                key: "maxBarCount",
                value: maxBarCount,
                range: 50...1000,
                label: "Maximum Bar Count"
            ),
            .slider(
                key: "minBarAlpha",
                value: minBarAlpha,
                range: 0.05...1.0,
                step: 0.05,
                label: "Min Bar Brightness"
            ),
            .slider(
                key: "brightnessRamp",
                value: brightnessRamp,
                range: 0.0...0.25,
                step: 0.01,
                label: "Brightness Ramp"
            ),
            .slider(
                key: "cornerRadius",
                value: cornerRadius,
                range: 0.0...20.0,
                step: 1.0,
                label: "Corner Radius"
            ),
            .boolean(
                key: "showBackground",
                value: showBackground,
                label: "Show Background"
            )
        ]
    }

    // MARK: - Property Updates

    public func updatingProperty(key: String, value: Any) -> AltitudeGraphConfiguration? {
        var updated = self

        switch key {
        case "style":
            if let enumValue = value as? AltitudeGraphStyle {
                updated.style = enumValue
            } else if let stringValue = value as? String, let style = AltitudeGraphStyle(rawValue: stringValue) {
                updated.style = style
            }
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
        case "barColor":
            if let colorValue = value as? SerializableColor {
                updated.barColor = colorValue
            }
        case "backgroundColor":
            if let colorValue = value as? SerializableColor {
                updated.backgroundColor = colorValue
            }
        case "axisColor":
            if let colorValue = value as? SerializableColor {
                updated.axisColor = colorValue
            }
        case "labelColor":
            if let colorValue = value as? SerializableColor {
                updated.labelColor = colorValue
            }
        case "fontSize":
            if let doubleValue = value as? Double {
                updated.fontSize = doubleValue
            }
        case "padding":
            if let doubleValue = value as? Double {
                updated.padding = doubleValue
            }
        case "labelPadding":
            if let doubleValue = value as? Double {
                updated.labelPadding = doubleValue
            }
        case "targetBarWidth":
            if let doubleValue = value as? Double {
                updated.targetBarWidth = doubleValue
            }
        case "barSpacing":
            if let doubleValue = value as? Double {
                updated.barSpacing = doubleValue
            }
        case "lineWidth":
            if let doubleValue = value as? Double {
                updated.lineWidth = doubleValue
            }
        case "minBarCount":
            if let intValue = value as? Int {
                updated.minBarCount = intValue
            } else if let doubleValue = value as? Double {
                updated.minBarCount = Int(doubleValue)
            }
        case "maxBarCount":
            if let intValue = value as? Int {
                updated.maxBarCount = intValue
            } else if let doubleValue = value as? Double {
                updated.maxBarCount = Int(doubleValue)
            }
        case "minBarAlpha":
            if let doubleValue = value as? Double {
                updated.minBarAlpha = doubleValue
            }
        case "brightnessRamp":
            if let doubleValue = value as? Double {
                updated.brightnessRamp = doubleValue
            }
        case "cornerRadius":
            if let doubleValue = value as? Double {
                updated.cornerRadius = doubleValue
            }
        case "showBackground":
            if let boolValue = value as? Bool {
                updated.showBackground = boolValue
            }
        default:
            return nil
        }

        return updated
    }
}

// MARK: - Altitude Graph Renderer

public struct AltitudeGraphRenderer: InstrumentRenderer {

    public init() {}

    public func render(
        context: MetalRenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        guard let config = configuration as? AltitudeGraphConfiguration else {
            return
        }

        let renderer = Metal2DRenderer.shared(for: context.device)
        let bounds = context.bounds

        if config.showBackground {
            renderer.drawRoundedRect(
                in: bounds,
                radius: CGFloat(config.cornerRadius),
                color: config.backgroundColor,
                renderContext: context
            )
        }

        guard let track = dataProvider.track(),
              let startTime = track.startTime,
              let endTime = track.endTime else {
            renderNoData(context: context, config: config, renderer: renderer)
            return
        }

        let points = track.points
        guard !points.isEmpty else {
            renderNoData(context: context, config: config, renderer: renderer)
            return
        }

        let duration = endTime.timeIntervalSince(startTime)
        if duration <= 0 {
            renderNoData(context: context, config: config, renderer: renderer)
            return
        }

        var minElevation = Double.infinity
        var maxElevation = -Double.infinity
        for point in points {
            guard let elevation = point.elevation else { continue }
            if elevation < minElevation { minElevation = elevation }
            if elevation > maxElevation { maxElevation = elevation }
        }

        if !minElevation.isFinite || !maxElevation.isFinite {
            renderNoData(context: context, config: config, renderer: renderer)
            return
        }

        let rawRange = maxElevation - minElevation
        let range = max(1.0, rawRange)
        let scale = max(1.0, context.scale)

        struct AxisLabel {
            let texture: MTLTexture
            let size: CGSize
            let fraction: Double
        }

        var axisLabels: [AxisLabel] = []

        #if canImport(AppKit)
        let font = NSFont.systemFont(ofSize: config.fontSize, weight: .medium)
        let labelRange = max(0.0, rawRange)
        let fractions: [Double] = [1.0, 2.0 / 3.0, 1.0 / 3.0]
        for fraction in fractions {
            let value = minElevation + labelRange * fraction
            let text = formattedAltitude(value: config.units.convert(meters: value), decimals: config.decimalPlaces)
                + " " + config.units.rawValue
            if let (tex, size) = MetalTextRenderer.shared.texture(
                text: text,
                font: font,
                color: config.labelColor,
                device: context.device,
                scale: scale
            ) {
                axisLabels.append(AxisLabel(texture: tex, size: size, fraction: fraction))
            }
        }
        #endif

        let maxLabelWidth = axisLabels.map(\.size.width).max() ?? 0
        let leftInset = config.padding + (maxLabelWidth > 0 ? Double(maxLabelWidth) + config.labelPadding : 0)
        let topInset = config.padding
        let rightInset = config.padding
        let bottomInset = config.padding

        let graphRect = CGRect(
            x: bounds.minX + leftInset,
            y: bounds.minY + topInset,
            width: bounds.width - leftInset - rightInset,
            height: bounds.height - topInset - bottomInset
        )

        if graphRect.width <= 4 || graphRect.height <= 4 {
            renderNoData(context: context, config: config, renderer: renderer)
            return
        }

        if !axisLabels.isEmpty {
            for label in axisLabels {
                let y = graphRect.maxY - graphRect.height * CGFloat(label.fraction)
                var labelRect = CGRect(
                    x: bounds.minX + config.padding,
                    y: y - label.size.height / 2,
                    width: label.size.width,
                    height: label.size.height
                )
                let minY = bounds.minY + config.padding
                let maxY = bounds.maxY - config.padding - label.size.height
                if labelRect.minY < minY { labelRect.origin.y = minY }
                if labelRect.minY > maxY { labelRect.origin.y = maxY }
                renderer.drawTexture(label.texture, in: labelRect, tintColor: .white, renderContext: context)
            }
        }

        renderer.drawLine(
            from: CGPoint(x: graphRect.minX, y: graphRect.minY),
            to: CGPoint(x: graphRect.minX, y: graphRect.maxY),
            lineWidth: 1.0,
            color: config.axisColor,
            renderContext: context
        )

        let dottedFractions: [Double] = [2.0 / 3.0, 1.0 / 3.0]
        for fraction in dottedFractions {
            let y = graphRect.maxY - graphRect.height * CGFloat(fraction)
            drawDottedLine(
                renderer: renderer,
                from: CGPoint(x: graphRect.minX, y: y),
                to: CGPoint(x: graphRect.maxX, y: y),
                color: config.axisColor.withAlpha(0.6),
                renderContext: context
            )
        }

        let barCount = barCountForWidth(
            graphWidth: graphRect.width,
            targetBarWidth: config.targetBarWidth,
            barSpacing: config.barSpacing,
            minBars: config.minBarCount,
            maxBars: config.maxBarCount
        )

        if barCount <= 0 {
            renderNoData(context: context, config: config, renderer: renderer)
            return
        }

        let barSpacing = max(0.0, config.barSpacing)
        let barWidth = max(
            1.0,
            (graphRect.width - CGFloat(barCount - 1) * CGFloat(barSpacing)) / CGFloat(barCount)
        )

        var barSums = Array(repeating: 0.0, count: barCount)
        var barCounts = Array(repeating: 0, count: barCount)

        let segmentDuration = duration / Double(barCount)
        var currentBar = 0
        var nextBoundary = startTime.addingTimeInterval(segmentDuration)

        for point in points {
            guard let elevation = point.elevation else { continue }

            let timestamp = point.timestamp
            while timestamp >= nextBoundary && currentBar < barCount - 1 {
                currentBar += 1
                nextBoundary = startTime.addingTimeInterval(segmentDuration * Double(currentBar + 1))
            }

            barSums[currentBar] += elevation
            barCounts[currentBar] += 1
        }

        let progress = timelineProgress(
            currentPoint: dataProvider.currentPoint(),
            startTime: startTime,
            endTime: endTime
        )

        let minAlpha = max(0.0, min(1.0, config.minBarAlpha))
        let ramp = max(0.0001, config.brightnessRamp)

        var lastValue = minElevation

        var plotPoints: [CGPoint] = []
        plotPoints.reserveCapacity(barCount)

        for index in 0..<barCount {
            let value: Double
            if barCounts[index] > 0 {
                value = barSums[index] / Double(barCounts[index])
                lastValue = value
            } else {
                value = lastValue
            }

            let normalized = max(0.0, min(1.0, (value - minElevation) / range))
            let barHeight = CGFloat(normalized) * graphRect.height
            let barX = graphRect.minX + CGFloat(index) * (barWidth + CGFloat(barSpacing))
            let barCenterX = barX + barWidth / 2
            let barY = graphRect.maxY - barHeight
            plotPoints.append(CGPoint(x: barCenterX, y: barY))

            let barT = (Double(index) + 0.5) / Double(barCount)
            let brightness = min(1.0, max(0.0, (progress - barT) / ramp + 1.0))
            let alpha = minAlpha + (1.0 - minAlpha) * brightness

            if config.style == .bars {
                let barRect = CGRect(
                    x: barX,
                    y: barY,
                    width: barWidth,
                    height: barHeight
                )
                renderer.drawRect(
                    in: barRect,
                    color: config.barColor.withAlpha(alpha),
                    renderContext: context
                )
            }
        }

        if config.style == .line && plotPoints.count > 1 {
            let lineWidth = CGFloat(max(1.0, config.lineWidth))
            for index in 0..<(plotPoints.count - 1) {
                let start = plotPoints[index]
                let end = plotPoints[index + 1]
                let segmentT = (Double(index) + 0.5) / Double(max(1, plotPoints.count - 1))
                let brightness = min(1.0, max(0.0, (progress - segmentT) / ramp + 1.0))
                let alpha = minAlpha + (1.0 - minAlpha) * brightness
                renderer.drawLine(
                    from: start,
                    to: end,
                    lineWidth: lineWidth,
                    color: config.barColor.withAlpha(alpha),
                    renderContext: context
                )
            }
        }

        // Draw current altitude label near the timeline position
        #if canImport(AppKit)
        if let currentPoint = dataProvider.currentPoint(),
           let currentElevation = currentPoint.elevation {
            let normalized = max(0.0, min(1.0, (currentElevation - minElevation) / range))
            let x = graphRect.minX + CGFloat(progress) * graphRect.width
            let y = graphRect.maxY - CGFloat(normalized) * graphRect.height

            let labelText = formattedAltitude(
                value: config.units.convert(meters: currentElevation),
                decimals: config.decimalPlaces
            ) + " " + config.units.rawValue

            let labelFont = NSFont.systemFont(ofSize: config.fontSize, weight: .semibold)
            if let (texture, size) = MetalTextRenderer.shared.texture(
                text: labelText,
                font: labelFont,
                color: config.labelColor,
                device: context.device,
                scale: scale
            ) {
                var labelX = x - size.width / 2
                labelX = max(graphRect.minX, min(labelX, graphRect.maxX - size.width))

                var labelY = y - size.height - 4
                if labelY < graphRect.minY {
                    labelY = min(y + 4, graphRect.maxY - size.height)
                }

                let labelRect = CGRect(
                    x: labelX,
                    y: labelY,
                    width: size.width,
                    height: size.height
                )
                renderer.drawTexture(texture, in: labelRect, tintColor: .white, renderContext: context)
            }
        }
        #endif
    }

    private func barCountForWidth(
        graphWidth: CGFloat,
        targetBarWidth: Double,
        barSpacing: Double,
        minBars: Int,
        maxBars: Int
    ) -> Int {
        let targetWidth = max(1.0, targetBarWidth)
        let spacing = max(0.0, barSpacing)
        let maxCount = Int((Double(graphWidth) + spacing) / (targetWidth + spacing))
        let maxFitCount = Int((Double(graphWidth) + spacing) / (1.0 + spacing))
        let desired = max(minBars, min(maxBars, maxCount))
        let clamped = max(1, min(desired, maxFitCount))
        return clamped
    }

    private func drawDottedLine(
        renderer: Metal2DRenderer,
        from start: CGPoint,
        to end: CGPoint,
        color: SerializableColor,
        renderContext: MetalRenderContext
    ) {
        let length = hypot(end.x - start.x, end.y - start.y)
        if length <= 0.5 {
            return
        }

        let dotLength: CGFloat = 4.0
        let gapLength: CGFloat = 3.0
        let step = dotLength + gapLength
        let dx = (end.x - start.x) / length
        let dy = (end.y - start.y) / length

        var distance: CGFloat = 0
        while distance < length {
            let segmentStart = CGPoint(
                x: start.x + dx * distance,
                y: start.y + dy * distance
            )
            let segmentEndDistance = min(distance + dotLength, length)
            let segmentEnd = CGPoint(
                x: start.x + dx * segmentEndDistance,
                y: start.y + dy * segmentEndDistance
            )
            renderer.drawLine(
                from: segmentStart,
                to: segmentEnd,
                lineWidth: 1.0,
                color: color,
                renderContext: renderContext
            )
            distance += step
        }
    }

    private func timelineProgress(
        currentPoint: TelemetryPoint?,
        startTime: Date,
        endTime: Date
    ) -> Double {
        guard let current = currentPoint else { return 1.0 }
        let duration = endTime.timeIntervalSince(startTime)
        if duration <= 0 { return 1.0 }
        let raw = current.timestamp.timeIntervalSince(startTime) / duration
        return min(1.0, max(0.0, raw))
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
        config: AltitudeGraphConfiguration,
        renderer: Metal2DRenderer
    ) {
        #if canImport(AppKit)
        let font = NSFont.systemFont(ofSize: 18, weight: .medium)
        let scale = max(1.0, context.scale)
        if let (texture, size) = MetalTextRenderer.shared.texture(
            text: "No Data",
            font: font,
            color: config.labelColor.withAlpha(0.5),
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

// MARK: - Altitude Graph Plugin

/// Altitude graph instrument plugin
///
/// Displays altitude over time as a dense bar graph with a max-height label on the Y axis.
public struct AltitudeGraphPlugin: InstrumentPlugin {

    public init() {}

    public static let metadata = PluginMetadata(
        id: "com.flighttrace.altitude-graph",
        name: "Altitude Graph",
        description: "Dense bar graph of altitude over time",
        version: "1.0.0",
        category: .visual,
        iconName: "chart.bar.fill"
    )

    public static let dataDependencies: Set<TelemetryDataType> = [.elevation, .timestamp]

    public static let defaultSize = CGSize(width: 320, height: 160)

    public static let minimumSize = CGSize(width: 180, height: 120)

    public func createConfiguration() -> any InstrumentConfiguration {
        AltitudeGraphConfiguration()
    }

    public func createRenderer() -> any InstrumentRenderer {
        AltitudeGraphRenderer()
    }
}
