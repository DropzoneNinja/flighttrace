// AirspeedGaugePlugin.swift
// Airspeed gauge instrument plugin (Metal)

import Foundation
import CoreGraphics

#if canImport(AppKit)
import AppKit
import FlightTraceCore
#endif

public enum AirspeedGaugeStyle: String, Sendable, Codable, CaseIterable, Equatable {
    case clear = "Clear"
    case steamGauge = "Steam Gauge"
}

public struct AirspeedGaugeConfiguration: InstrumentConfiguration, Codable {
    public var id = UUID()

    public var gaugeStyle: AirspeedGaugeStyle = .steamGauge

    /// Maximum speed on the dial (knots)
    public var maxSpeed: Double = 100

    /// Color band ranges (knots)
    public var greenStart: Double = 20
    public var greenEnd: Double = 70

    public var yellowStart: Double = 70
    public var yellowEnd: Double = 80

    public var whiteStart: Double = 5
    public var whiteEnd: Double = 20

    public var redStart: Double = 80
    public var redEnd: Double = 100

    public var tickColor: SerializableColor = .white
    public var numberColor: SerializableColor = .white
    public var needleColor: SerializableColor = .white
    public var faceColor: SerializableColor = SerializableColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)

    public var majorTickCount: Int = 12
    public var minorTicksPerMajor: Int = 4
    public var majorTickLength: Double = 12.0
    public var minorTickLength: Double = 6.0
    public var tickStrokeWidth: Double = 2.0

    public var numberFontSize: Double = 18.0

    public var needleLength: Double = 0.85
    public var needleStrokeWidth: Double = 2.0

    // Labels and units
    public var units: SpeedUnit = .kilometersPerHour
    public var showCenterLabel: Bool = true
    public var centerLabelText: String = "SPEED"
    public var centerLabelFontSize: Double = 12.0
    public var showUnitLabel: Bool = true
    public var unitLabelFontSize: Double = 10.0

    public init() {}

    public func encode() throws -> Data { try JSONEncoder().encode(self) }
    public static func decode(from data: Data) throws -> Self { try JSONDecoder().decode(Self.self, from: data) }

    public func properties() -> [ConfigurationProperty] {
        [
            .enumeration(key: "gaugeStyle", value: gaugeStyle, options: AirspeedGaugeStyle.allCases, label: "Gauge Style"),
            .double(key: "maxSpeed", value: maxSpeed, range: 80...400, label: "Max Speed"),
            .double(key: "greenStart", value: greenStart, range: 0...400, label: "Green Start"),
            .double(key: "greenEnd", value: greenEnd, range: 0...400, label: "Green End"),
            .double(key: "yellowStart", value: yellowStart, range: 0...400, label: "Yellow Start"),
            .double(key: "yellowEnd", value: yellowEnd, range: 0...400, label: "Yellow End"),
            .double(key: "whiteStart", value: whiteStart, range: 0...400, label: "White Start"),
            .double(key: "whiteEnd", value: whiteEnd, range: 0...400, label: "White End"),
            .double(key: "redStart", value: redStart, range: 0...400, label: "Red Start"),
            .double(key: "redEnd", value: redEnd, range: 0...400, label: "Red End"),
            .color(key: "tickColor", value: tickColor, label: "Tick Color"),
            .color(key: "numberColor", value: numberColor, label: "Number Color"),
            .color(key: "needleColor", value: needleColor, label: "Needle Color"),
            .slider(key: "numberFontSize", value: numberFontSize, range: 10.0...28.0, step: 1.0, label: "Number Font Size"),
            .integer(key: "majorTickCount", value: majorTickCount, range: 6...16, label: "Major Ticks"),
            .integer(key: "minorTicksPerMajor", value: minorTicksPerMajor, range: 0...6, label: "Minor Ticks"),
            .slider(key: "majorTickLength", value: majorTickLength, range: 6.0...20.0, step: 1.0, label: "Major Tick Length"),
            .slider(key: "minorTickLength", value: minorTickLength, range: 2.0...12.0, step: 1.0, label: "Minor Tick Length"),
            .slider(key: "tickStrokeWidth", value: tickStrokeWidth, range: 1.0...4.0, step: 0.5, label: "Tick Width"),
            .enumeration(key: "units", value: units, options: SpeedUnit.allCases, label: "Speed Unit"),
            .boolean(key: "showCenterLabel", value: showCenterLabel, label: "Show Center Label"),
            .string(key: "centerLabelText", value: centerLabelText, label: "Center Label Text"),
            .slider(key: "centerLabelFontSize", value: centerLabelFontSize, range: 8.0...20.0, step: 1.0, label: "Center Label Size"),
            .boolean(key: "showUnitLabel", value: showUnitLabel, label: "Show Unit Label"),
            .slider(key: "unitLabelFontSize", value: unitLabelFontSize, range: 8.0...16.0, step: 1.0, label: "Unit Label Size")
        ]
    }

    public func updatingProperty(key: String, value: Any) -> AirspeedGaugeConfiguration? {
        var updated = self
        switch key {
        case "gaugeStyle":
            if let v = value as? AirspeedGaugeStyle { updated.gaugeStyle = v }
            else if let s = value as? String, let v = AirspeedGaugeStyle(rawValue: s) { updated.gaugeStyle = v }
        case "maxSpeed":
            if let v = value as? Double {
                let rounded = max(10.0, (v / 10.0).rounded() * 10.0)
                updated.maxSpeed = rounded
            }
        case "greenStart":
            if let v = value as? Double { updated.greenStart = v }
        case "greenEnd":
            if let v = value as? Double { updated.greenEnd = v }
        case "yellowStart":
            if let v = value as? Double { updated.yellowStart = v }
        case "yellowEnd":
            if let v = value as? Double { updated.yellowEnd = v }
        case "whiteStart":
            if let v = value as? Double { updated.whiteStart = v }
        case "whiteEnd":
            if let v = value as? Double { updated.whiteEnd = v }
        case "redStart":
            if let v = value as? Double { updated.redStart = v }
        case "redEnd":
            if let v = value as? Double { updated.redEnd = v }
        case "tickColor":
            if let v = value as? SerializableColor { updated.tickColor = v }
        case "numberColor":
            if let v = value as? SerializableColor { updated.numberColor = v }
        case "needleColor":
            if let v = value as? SerializableColor { updated.needleColor = v }
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
        case "units":
            if let v = value as? SpeedUnit { updated.units = v }
            else if let s = value as? String, let v = SpeedUnit(rawValue: s) { updated.units = v }
        case "showCenterLabel":
            if let v = value as? Bool { updated.showCenterLabel = v }
        case "centerLabelText":
            if let v = value as? String { updated.centerLabelText = v }
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

public struct AirspeedGaugeRenderer: InstrumentRenderer {
    public init() {}

    public func render(
        context: MetalRenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        guard let config = configuration as? AirspeedGaugeConfiguration else { return }

        guard let point = dataProvider.currentPoint(), let speed = point.speed else {
            renderNoData(context: context, config: config)
            return
        }

        let speedValue = config.units.convert(metersPerSecond: speed)
        renderDial(context: context, speedValue: speedValue, config: config)
    }

    private func renderDial(context: MetalRenderContext, speedValue: Double, config: AirspeedGaugeConfiguration) {
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

        renderColorBands(context: context, center: center, radius: innerRadius, config: config)
        renderTicks(context: context, center: center, radius: innerRadius, config: config)
        renderNumbers(context: context, center: center, radius: innerRadius, config: config)

        if config.showCenterLabel {
            renderCenterLabel(context: context, center: center, text: config.centerLabelText, config: config)
        }
        if config.showUnitLabel {
            renderUnitLabel(context: context, center: center, text: config.units.rawValue, config: config)
        }

        renderNeedle(context: context, center: center, radius: innerRadius, speedValue: speedValue, config: config)
    }

    private func renderCenterLabel(
        context: MetalRenderContext,
        center: CGPoint,
        text: String,
        config: AirspeedGaugeConfiguration
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
                y: center.y - size.height - 10, // above hub
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
        text: String,
        config: AirspeedGaugeConfiguration
    ) {
        #if canImport(AppKit)
        let renderer = Metal2DRenderer.shared(for: context.device)
        let scale = max(1.0, context.scale)
        let font = NSFont.systemFont(ofSize: config.unitLabelFontSize, weight: .medium)
        if let (tex, size) = MetalTextRenderer.shared.texture(
            text: text,
            font: font,
            color: config.numberColor.withAlpha(0.7),
            device: context.device,
            scale: scale,
            extraVerticalPadding: config.unitLabelFontSize * 0.2
        ) {
            let rect = CGRect(
                x: center.x - size.width / 2,
                y: center.y + 10, // below hub
                width: size.width,
                height: size.height
            )
            renderer.drawTexture(tex, in: rect, tintColor: .white, renderContext: context)
        }
        #endif
    }

    private func renderColorBands(
        context: MetalRenderContext,
        center: CGPoint,
        radius: CGFloat,
        config: AirspeedGaugeConfiguration
    ) {
        let bandWidth: CGFloat = 10
        let outer = radius - 6
        let inner = outer - bandWidth

        func drawBand(start: Double, end: Double, color: SerializableColor) {
            guard end > start else { return }
            let startAngle = angleForSpeed(start, max: config.maxSpeed)
            let endAngle = angleForSpeed(end, max: config.maxSpeed)
            drawArcBand(
                context: context,
                center: center,
                innerRadius: inner,
                outerRadius: outer,
                startAngle: startAngle,
                endAngle: endAngle,
                color: color
            )
        }

        drawBand(start: config.whiteStart, end: config.whiteEnd, color: .white)
        drawBand(start: config.greenStart, end: config.greenEnd, color: SerializableColor(red: 0.2, green: 0.6, blue: 0.2))
        drawBand(start: config.yellowStart, end: config.yellowEnd, color: SerializableColor(red: 0.9, green: 0.8, blue: 0.1))
        drawBand(start: config.redStart, end: config.redEnd, color: SerializableColor(red: 0.9, green: 0.1, blue: 0.1))
    }

    private func computeLabelStep(maxSpeed: Double) -> Double {
        let maxVal = max(10.0, (maxSpeed / 10.0).rounded() * 10.0)
        // Prefer 11, then 10, then 9 labels (intervals 10,9,8)
        let preferredIntervals = [10, 9, 8]
        for intervals in preferredIntervals {
            let step = maxVal / Double(intervals)
            if step.truncatingRemainder(dividingBy: 10.0) == 0 {
                return step
            }
        }
        // Fallback: choose a divisor of maxVal that is a multiple of 10 and yields labels closest to 11
        let maxInt = Int(maxVal)
        var bestStep: Int = 10
        var bestDelta = Int.max
        for s in stride(from: maxInt, through: 10, by: -10) {
            if maxInt % s == 0 {
                let labels = maxInt / s + 1
                let delta = abs(labels - 11)
                if delta < bestDelta {
                    bestDelta = delta
                    bestStep = s
                    if labels >= 9 && labels <= 11 { break }
                }
            }
        }
        return Double(bestStep)
    }

    private func renderTicks(
        context: MetalRenderContext,
        center: CGPoint,
        radius: CGFloat,
        config: AirspeedGaugeConfiguration
    ) {
        let renderer = Metal2DRenderer.shared(for: context.device)
        let step = computeLabelStep(maxSpeed: config.maxSpeed)
        let intervals = max(1, Int(round(config.maxSpeed / step)))
        let minor = max(0, config.minorTicksPerMajor)
        let total = intervals * (minor + 1)

        for i in 0...total {
            let isMajor = i % (minor + 1) == 0
            let tickLength = CGFloat(isMajor ? config.majorTickLength : config.minorTickLength)
            let tickWidth = CGFloat(isMajor ? config.tickStrokeWidth : config.tickStrokeWidth * 0.5)
            let value = (Double(i) / Double(total)) * config.maxSpeed
            let angle = angleForSpeed(value, max: config.maxSpeed)

            let radians = angle * .pi / 180
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
        config: AirspeedGaugeConfiguration
    ) {
        #if canImport(AppKit)
        let renderer = Metal2DRenderer.shared(for: context.device)
        let scale = max(1.0, context.scale)
        let font = NSFont.monospacedDigitSystemFont(ofSize: config.numberFontSize, weight: .semibold)
        let numberRadius = radius - CGFloat(config.majorTickLength) - CGFloat(config.numberFontSize) * 0.5

        let step = computeLabelStep(maxSpeed: config.maxSpeed)
        let intervals = max(1, Int(round(config.maxSpeed / step)))
        for k in 0...intervals {
            let value = Double(k) * step
            let angle = angleForSpeed(value, max: config.maxSpeed)
            let radians = angle * .pi / 180
            let x = center.x + numberRadius * cos(radians)
            let y = center.y + numberRadius * sin(radians)

            let text = String(Int(value))
            if let (tex, size) = MetalTextRenderer.shared.texture(
                text: text,
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

    private func renderNeedle(
        context: MetalRenderContext,
        center: CGPoint,
        radius: CGFloat,
        speedValue: Double,
        config: AirspeedGaugeConfiguration
    ) {
        let renderer = Metal2DRenderer.shared(for: context.device)
        let maxSpeed = max(1.0, config.maxSpeed)
        let clamped = max(0.0, min(maxSpeed, speedValue))
        let angle = angleForSpeed(clamped, max: maxSpeed)
        let radians = angle * .pi / 180
        let length = radius * CGFloat(config.needleLength)
        let end = CGPoint(
            x: center.x + length * cos(radians),
            y: center.y + length * sin(radians)
        )
        renderer.drawLine(from: center, to: end, lineWidth: CGFloat(config.needleStrokeWidth), color: config.needleColor, renderContext: context)
        renderer.drawCircle(center: center, radius: 4, color: config.tickColor, renderContext: context)
    }

    private func angleForSpeed(_ speed: Double, max maxValue: Double) -> Double {
        let clamped = Swift.max(0.0, Swift.min(maxValue, speed))
        // 0 at 12 o'clock, max at 11 o'clock (clockwise, ~330° sweep)
        let startAngle = -90.0
        let endAngle = 240.0
        let t = clamped / maxValue
        return startAngle + (endAngle - startAngle) * t
    }

    private func drawArcBand(
        context: MetalRenderContext,
        center: CGPoint,
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        startAngle: Double,
        endAngle: Double,
        color: SerializableColor
    ) {
        let renderer = Metal2DRenderer.shared(for: context.device)
        let steps = max(6, Int(abs(endAngle - startAngle) / 3))
        let step = (endAngle - startAngle) / Double(steps)

        var previousInner: CGPoint? = nil
        var previousOuter: CGPoint? = nil

        for i in 0...steps {
            let angle = (startAngle + Double(i) * step) * .pi / 180
            let inner = CGPoint(
                x: center.x + innerRadius * cos(angle),
                y: center.y + innerRadius * sin(angle)
            )
            let outer = CGPoint(
                x: center.x + outerRadius * cos(angle),
                y: center.y + outerRadius * sin(angle)
            )

            if let pInner = previousInner, let pOuter = previousOuter {
                renderer.drawLine(from: pInner, to: inner, lineWidth: 2, color: color, renderContext: context)
                renderer.drawLine(from: pOuter, to: outer, lineWidth: 2, color: color, renderContext: context)
            }

            previousInner = inner
            previousOuter = outer
        }
    }

    private func renderNoData(context: MetalRenderContext, config: AirspeedGaugeConfiguration) {
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

public struct AirspeedGaugePlugin: InstrumentPlugin {
    public init() {}

    public static let metadata = PluginMetadata(
        id: "com.flighttrace.airspeed-gauge",
        name: "Airspeed Gauge",
        description: "Analog airspeed indicator",
        version: "1.0.0",
        category: .gauge,
        iconName: "speedometer"
    )

    public static let dataDependencies: Set<TelemetryDataType> = [.speed, .timestamp]
    public static let defaultSize = CGSize(width: 220, height: 220)
    public static let minimumSize = CGSize(width: 140, height: 140)

    public func createConfiguration() -> any InstrumentConfiguration {
        AirspeedGaugeConfiguration()
    }

    public func createRenderer() -> any InstrumentRenderer {
        AirspeedGaugeRenderer()
    }
}

