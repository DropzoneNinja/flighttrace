// AltimeterGaugePlugin.swift
// Altimeter gauge instrument plugin (Metal)

import Foundation
import CoreGraphics

#if canImport(AppKit)
import AppKit
import FlightTraceCore
#endif

// MARK: - Altimeter Styles

public enum AltimeterGaugeStyle: String, Sendable, Codable, CaseIterable, Equatable {
    case clear = "Clear"
    case steamGauge = "Steam Gauge"
}

public enum AltimeterNeedleMode: String, Sendable, Codable, CaseIterable, Equatable {
    case threeNeedle = "Three-Needle"
    case twoNeedle = "Two-Needle"
}

// MARK: - Configuration

public struct AltimeterGaugeConfiguration: InstrumentConfiguration, Codable {
    public var id = UUID()

    public var units: AltitudeUnit = .feet
    public var gaugeStyle: AltimeterGaugeStyle = .steamGauge
    public var needleMode: AltimeterNeedleMode = .threeNeedle

    public var faceColor: SerializableColor = SerializableColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)
    public var tickColor: SerializableColor = .white
    public var numberColor: SerializableColor = .white

    public var hundredNeedleColor: SerializableColor = .white
    public var thousandNeedleColor: SerializableColor = .white
    public var tenThousandNeedleColor: SerializableColor = .white

    public var majorTickCount: Int = 10
    public var minorTicksPerMajor: Int = 4
    public var majorTickLength: Double = 12.0
    public var minorTickLength: Double = 6.0
    public var tickStrokeWidth: Double = 2.0

    public var numberFontSize: Double = 18.0
    public var showCenterLabel: Bool = true
    public var centerLabelText: String = "ALT"
    public var centerLabelFontSize: Double = 14.0
    public var showUnitLabel: Bool = true
    public var unitLabelFontSize: Double = 10.0

    public var hundredNeedleLength: Double = 0.9
    public var thousandNeedleLength: Double = 0.6
    public var tenThousandNeedleLength: Double = 0.4
    public var needleStrokeWidth: Double = 2.0

    public init() {}

    public func encode() throws -> Data { try JSONEncoder().encode(self) }
    public static func decode(from data: Data) throws -> Self { try JSONDecoder().decode(Self.self, from: data) }

    public func properties() -> [ConfigurationProperty] {
        [
            .enumeration(key: "units", value: units, options: AltitudeUnit.allCases, label: "Units"),
            .enumeration(key: "gaugeStyle", value: gaugeStyle, options: AltimeterGaugeStyle.allCases, label: "Gauge Style"),
            .enumeration(key: "needleMode", value: needleMode, options: AltimeterNeedleMode.allCases, label: "Needle Mode"),
            .color(key: "faceColor", value: faceColor, label: "Face Color"),
            .color(key: "tickColor", value: tickColor, label: "Tick Color"),
            .color(key: "numberColor", value: numberColor, label: "Number Color"),
            .slider(key: "numberFontSize", value: numberFontSize, range: 10.0...32.0, step: 1.0, label: "Number Font Size"),
            .integer(key: "majorTickCount", value: majorTickCount, range: 6...12, label: "Major Ticks"),
            .integer(key: "minorTicksPerMajor", value: minorTicksPerMajor, range: 0...8, label: "Minor Ticks"),
            .slider(key: "majorTickLength", value: majorTickLength, range: 6.0...20.0, step: 1.0, label: "Major Tick Length"),
            .slider(key: "minorTickLength", value: minorTickLength, range: 2.0...12.0, step: 1.0, label: "Minor Tick Length"),
            .slider(key: "tickStrokeWidth", value: tickStrokeWidth, range: 1.0...4.0, step: 0.5, label: "Tick Width"),
            .boolean(key: "showCenterLabel", value: showCenterLabel, label: "Show Center Label"),
            .slider(key: "centerLabelFontSize", value: centerLabelFontSize, range: 8.0...24.0, step: 1.0, label: "Center Label Size"),
            .boolean(key: "showUnitLabel", value: showUnitLabel, label: "Show Unit Label"),
            .slider(key: "unitLabelFontSize", value: unitLabelFontSize, range: 8.0...18.0, step: 1.0, label: "Unit Label Size")
        ]
    }

    public func updatingProperty(key: String, value: Any) -> AltimeterGaugeConfiguration? {
        var updated = self
        switch key {
        case "units":
            if let v = value as? AltitudeUnit { updated.units = v }
            else if let s = value as? String, let v = AltitudeUnit(rawValue: s) { updated.units = v }
        case "gaugeStyle":
            if let v = value as? AltimeterGaugeStyle { updated.gaugeStyle = v }
            else if let s = value as? String, let v = AltimeterGaugeStyle(rawValue: s) { updated.gaugeStyle = v }
        case "needleMode":
            if let v = value as? AltimeterNeedleMode { updated.needleMode = v }
            else if let s = value as? String, let v = AltimeterNeedleMode(rawValue: s) { updated.needleMode = v }
        case "faceColor":
            if let v = value as? SerializableColor { updated.faceColor = v }
        case "tickColor":
            if let v = value as? SerializableColor { updated.tickColor = v }
        case "numberColor":
            if let v = value as? SerializableColor { updated.numberColor = v }
        case "numberFontSize":
            if let v = value as? Double { updated.numberFontSize = v }
        case "majorTickCount":
            if let v = value as? Int { updated.majorTickCount = v }
        case "minorTicksPerMajor":
            if let v = value as? Int { updated.minorTicksPerMajor = v }
        case "majorTickLength":
            if let v = value as? Double { updated.majorTickLength = v }
        case "minorTickLength":
            if let v = value as? Double { updated.minorTickLength = v }
        case "tickStrokeWidth":
            if let v = value as? Double { updated.tickStrokeWidth = v }
        case "showCenterLabel":
            if let v = value as? Bool { updated.showCenterLabel = v }
        case "centerLabelFontSize":
            if let v = value as? Double { updated.centerLabelFontSize = v }
        case "showUnitLabel":
            if let v = value as? Bool { updated.showUnitLabel = v }
        case "unitLabelFontSize":
            if let v = value as? Double { updated.unitLabelFontSize = v }
        default:
            return nil
        }
        return updated
    }
}

// MARK: - Renderer (Metal)

public struct AltimeterGaugeRenderer: InstrumentRenderer {
    public init() {}

    public func render(
        context: MetalRenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        guard let config = configuration as? AltimeterGaugeConfiguration else { return }

        guard let point = dataProvider.currentPoint(), let elevation = point.elevation else {
            renderNoData(context: context, config: config)
            return
        }

        let altitudeValue = config.units.convert(meters: elevation)
        renderDial(context: context, altitude: altitudeValue, config: config)
    }

    private func renderDial(context: MetalRenderContext, altitude: Double, config: AltimeterGaugeConfiguration) {
        let renderer = Metal2DRenderer.shared(for: context.device)

        let bounds = context.bounds
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let maxDimension = min(bounds.width, bounds.height)
        let outerRadius = maxDimension / 2
        let innerRadius = config.gaugeStyle == .steamGauge ? outerRadius * 0.8925 : outerRadius - 2

        if config.gaugeStyle == .steamGauge,
           let bezel = renderer.texture(named: "steam-gauge-bezel") {
            let bezelRect = CGRect(
                x: center.x - outerRadius,
                y: center.y - outerRadius,
                width: outerRadius * 2,
                height: outerRadius * 2
            )
            renderer.drawTexture(bezel, in: bezelRect, tintColor: .white, renderContext: context)
        }

        let faceColor: SerializableColor = (config.gaugeStyle == .steamGauge) ? .black : config.faceColor
        renderer.drawCircle(center: center, radius: innerRadius, color: faceColor, renderContext: context)

        if config.gaugeStyle == .clear {
            renderer.drawCircleStroke(center: center, radius: innerRadius, lineWidth: 2, color: .white, renderContext: context)
        }

        renderTicks(context: context, center: center, radius: innerRadius, config: config)
        renderNumbers(context: context, center: center, radius: innerRadius, config: config)

        if config.showCenterLabel {
            renderCenterLabel(context: context, center: center, text: config.centerLabelText, config: config)
        }

        if config.showUnitLabel {
            renderUnitLabel(context: context, center: center, unit: config.units.rawValue.uppercased(), config: config)
        }

        renderNeedles(context: context, center: center, radius: innerRadius, altitude: altitude, config: config)
    }

    private func renderTicks(
        context: MetalRenderContext,
        center: CGPoint,
        radius: CGFloat,
        config: AltimeterGaugeConfiguration
    ) {
        let renderer = Metal2DRenderer.shared(for: context.device)
        let major = max(1, config.majorTickCount)
        let minor = max(0, config.minorTicksPerMajor)
        let total = major * (minor + 1)

        for i in 0..<total {
            let isMajor = i % (minor + 1) == 0
            let tickLength = CGFloat(isMajor ? config.majorTickLength : config.minorTickLength)
            let tickWidth = CGFloat(isMajor ? config.tickStrokeWidth : config.tickStrokeWidth * 0.5)
            let angle = CGFloat(i) * 360.0 / CGFloat(total)
            let radians = (angle - 90) * .pi / 180

            let outer = CGPoint(
                x: center.x + radius * cos(radians),
                y: center.y + radius * sin(radians)
            )
            let inner = CGPoint(
                x: center.x + (radius - tickLength) * cos(radians),
                y: center.y + (radius - tickLength) * sin(radians)
            )
            renderer.drawLine(from: inner, to: outer, lineWidth: tickWidth, color: config.tickColor, renderContext: context)
        }
    }

    private func renderNumbers(
        context: MetalRenderContext,
        center: CGPoint,
        radius: CGFloat,
        config: AltimeterGaugeConfiguration
    ) {
        #if canImport(AppKit)
        let renderer = Metal2DRenderer.shared(for: context.device)
        let scale = max(1.0, context.scale)
        let font = NSFont.monospacedDigitSystemFont(ofSize: config.numberFontSize, weight: .semibold)
        let numberRadius = max(
            radius * 0.7,
            radius - CGFloat(config.majorTickLength) - CGFloat(config.numberFontSize) * 0.8
        )

        for i in 0..<10 {
            let number = String(i)
            let angle = CGFloat(i) * 36.0
            let radians = (angle - 90) * .pi / 180
            let x = center.x + numberRadius * cos(radians)
            let y = center.y + numberRadius * sin(radians)

            if let (tex, size) = MetalTextRenderer.shared.texture(
                text: number,
                font: font,
                color: config.numberColor,
                device: context.device,
                scale: scale,
                extraVerticalPadding: config.numberFontSize * 0.2
            ) {
                let rect = CGRect(
                    x: x - size.width / 2,
                    y: y - size.height / 2,
                    width: size.width,
                    height: size.height
                )
                renderer.drawTexture(tex, in: rect, tintColor: .white, renderContext: context)
            }
        }
        #endif
    }

    private func renderCenterLabel(
        context: MetalRenderContext,
        center: CGPoint,
        text: String,
        config: AltimeterGaugeConfiguration
    ) {
        #if canImport(AppKit)
        let renderer = Metal2DRenderer.shared(for: context.device)
        let scale = max(1.0, context.scale)
        let font = NSFont.systemFont(ofSize: config.centerLabelFontSize, weight: .bold)
        if let (tex, size) = MetalTextRenderer.shared.texture(
            text: text,
            font: font,
            color: config.numberColor,
            device: context.device,
            scale: scale,
            extraVerticalPadding: config.centerLabelFontSize * 0.2
        ) {
            let rect = CGRect(
                x: center.x - size.width / 2,
                y: center.y - size.height / 2 + 15,
                width: size.width,
                height: size.height
            )
            renderer.drawTexture(tex, in: rect, tintColor: .white, renderContext: context)
        }
        #endif
    }

    private func renderUnitLabel(
        context: MetalRenderContext,
        center: CGPoint,
        unit: String,
        config: AltimeterGaugeConfiguration
    ) {
        #if canImport(AppKit)
        let renderer = Metal2DRenderer.shared(for: context.device)
        let scale = max(1.0, context.scale)
        let font = NSFont.systemFont(ofSize: config.unitLabelFontSize, weight: .medium)
        if let (tex, size) = MetalTextRenderer.shared.texture(
            text: unit,
            font: font,
            color: config.numberColor.withAlpha(0.7),
            device: context.device,
            scale: scale,
            extraVerticalPadding: config.unitLabelFontSize * 0.2
        ) {
            let rect = CGRect(
                x: center.x - size.width / 2,
                y: center.y - size.height / 2 + 50,
                width: size.width,
                height: size.height
            )
            renderer.drawTexture(tex, in: rect, tintColor: .white, renderContext: context)
        }
        #endif
    }

    private func renderNeedles(
        context: MetalRenderContext,
        center: CGPoint,
        radius: CGFloat,
        altitude: Double,
        config: AltimeterGaugeConfiguration
    ) {
        let renderer = Metal2DRenderer.shared(for: context.device)
        let angles = calculateNeedleAngles(altitude: altitude, units: config.units)

        if config.needleMode == .threeNeedle {
            let length = radius * CGFloat(config.tenThousandNeedleLength)
            let end = pointOnCircle(center: center, radius: length, angleDegrees: angles.tenThousand)
            renderer.drawLine(from: center, to: end, lineWidth: CGFloat(config.needleStrokeWidth * 1.5), color: config.tenThousandNeedleColor, renderContext: context)
        }

        let thousandLen = radius * CGFloat(config.thousandNeedleLength)
        let thousandEnd = pointOnCircle(center: center, radius: thousandLen, angleDegrees: angles.thousand)
        renderer.drawLine(from: center, to: thousandEnd, lineWidth: CGFloat(config.needleStrokeWidth * 1.2), color: config.thousandNeedleColor, renderContext: context)

        let hundredLen = radius * CGFloat(config.hundredNeedleLength)
        let hundredEnd = pointOnCircle(center: center, radius: hundredLen, angleDegrees: angles.hundred)
        renderer.drawLine(from: center, to: hundredEnd, lineWidth: CGFloat(config.needleStrokeWidth), color: config.hundredNeedleColor, renderContext: context)

        renderer.drawCircle(center: center, radius: 4, color: config.tickColor, renderContext: context)
    }

    private func pointOnCircle(center: CGPoint, radius: CGFloat, angleDegrees: CGFloat) -> CGPoint {
        let radians = (angleDegrees - 90) * .pi / 180
        return CGPoint(
            x: center.x + radius * cos(radians),
            y: center.y + radius * sin(radians)
        )
    }

    private func calculateNeedleAngles(altitude: Double, units: AltitudeUnit) -> (hundred: CGFloat, thousand: CGFloat, tenThousand: CGFloat) {
        let altFeet = units == .feet ? altitude : altitude * 3.28084
        let hundredAngle = (altFeet.truncatingRemainder(dividingBy: 1000) / 1000) * 360
        let thousandAngle = (altFeet.truncatingRemainder(dividingBy: 10000) / 10000) * 360
        let tenThousandAngle = (altFeet / 100000).truncatingRemainder(dividingBy: 1) * 360
        return (
            hundred: CGFloat(hundredAngle),
            thousand: CGFloat(thousandAngle),
            tenThousand: CGFloat(tenThousandAngle)
        )
    }

    private func renderNoData(context: MetalRenderContext, config: AltimeterGaugeConfiguration) {
        let renderer = Metal2DRenderer.shared(for: context.device)
        let bounds = context.bounds
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let maxDimension = min(bounds.width, bounds.height)
        let outerRadius = maxDimension / 2
        let innerRadius = config.gaugeStyle == .steamGauge ? outerRadius * 0.8925 : outerRadius - 2

        if config.gaugeStyle == .steamGauge,
           let bezel = renderer.texture(named: "steam-gauge-bezel") {
            let bezelRect = CGRect(
                x: center.x - outerRadius,
                y: center.y - outerRadius,
                width: outerRadius * 2,
                height: outerRadius * 2
            )
            renderer.drawTexture(bezel, in: bezelRect, tintColor: .white, renderContext: context)
        }

        renderer.drawCircle(center: center, radius: innerRadius, color: .black, renderContext: context)

        #if canImport(AppKit)
        let scale = max(1.0, context.scale)
        let font = NSFont.systemFont(ofSize: 16, weight: .medium)
        if let (tex, size) = MetalTextRenderer.shared.texture(
            text: "NO DATA",
            font: font,
            color: config.numberColor.withAlpha(0.5),
            device: context.device,
            scale: scale,
            extraVerticalPadding: 4
        ) {
            let rect = CGRect(
                x: center.x - size.width / 2,
                y: center.y - size.height / 2,
                width: size.width,
                height: size.height
            )
            renderer.drawTexture(tex, in: rect, tintColor: .white, renderContext: context)
        }
        #endif
    }
}

// MARK: - Plugin

public struct AltimeterGaugePlugin: InstrumentPlugin {
    public init() {}

    public static let metadata = PluginMetadata(
        id: "com.flighttrace.altimeter-gauge",
        name: "Altimeter Gauge",
        description: "Analog altimeter with needles",
        version: "1.0.0",
        category: .gauge,
        iconName: "gauge.with.needle.fill"
    )

    public static let dataDependencies: Set<TelemetryDataType> = [.elevation, .timestamp]
    public static let defaultSize = CGSize(width: 220, height: 220)
    public static let minimumSize = CGSize(width: 140, height: 140)

    public func createConfiguration() -> any InstrumentConfiguration {
        AltimeterGaugeConfiguration()
    }

    public func createRenderer() -> any InstrumentRenderer {
        AltimeterGaugeRenderer()
    }
}
