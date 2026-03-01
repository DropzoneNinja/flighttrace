// VerticalSpeedGaugePlugin.swift
// Vertical speed gauge instrument plugin (Metal)

import Foundation
import CoreGraphics

#if canImport(AppKit)
import AppKit
import FlightTraceCore
#endif

// MARK: - Gauge Style

public enum VerticalSpeedGaugeStyle: String, Sendable, Codable, CaseIterable, Equatable {
    case clear = "Clear"
    case steamGauge = "Steam Gauge"
}

// MARK: - Configuration

public struct VerticalSpeedGaugeConfiguration: InstrumentConfiguration, Codable {
    public var id = UUID()

    public var gaugeStyle: VerticalSpeedGaugeStyle = .steamGauge

    /// Max vertical speed (ft/min) for the scale
    public var maxSpeedFPM: Double = 2000

    /// Colors
    public var faceColor: SerializableColor = SerializableColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)
    public var tickColor: SerializableColor = .white
    public var numberColor: SerializableColor = .white
    public var needleColor: SerializableColor = .white

    /// Tick layout
    public var majorTicksPerSide: Int = 4
    public var minorTicksPerMajor: Int = 4
    public var majorTickLength: Double = 12.0
    public var minorTickLength: Double = 6.0
    public var tickStrokeWidth: Double = 2.0

    /// Labels
    public var numberFontSize: Double = 20.0
    public var showCenterLabel: Bool = true
    public var centerLabelText: String = "VERTICAL\nSPEED"
    public var centerLabelFontSize: Double = 12.0
    public var showUnitLabel: Bool = true
    public var unitLabelText: String = "ft/min"
    public var unitLabelFontSize: Double = 10.0

    /// Needle
    public var needleLength: Double = 0.85
    public var needleStrokeWidth: Double = 2.0

    public init() {}

    public func encode() throws -> Data { try JSONEncoder().encode(self) }
    public static func decode(from data: Data) throws -> Self { try JSONDecoder().decode(Self.self, from: data) }

    public func properties() -> [ConfigurationProperty] {
        [
            .enumeration(key: "gaugeStyle", value: gaugeStyle, options: VerticalSpeedGaugeStyle.allCases, label: "Gauge Style"),
            .slider(key: "maxSpeedFPM", value: maxSpeedFPM, range: 500...4000, step: 100, label: "Max Speed (ft/min)"),
            .color(key: "tickColor", value: tickColor, label: "Tick Color"),
            .color(key: "numberColor", value: numberColor, label: "Number Color"),
            .color(key: "needleColor", value: needleColor, label: "Needle Color"),
            .slider(key: "numberFontSize", value: numberFontSize, range: 10.0...28.0, step: 1.0, label: "Number Font Size"),
            .integer(key: "majorTicksPerSide", value: majorTicksPerSide, range: 2...8, label: "Major Ticks/Side"),
            .integer(key: "minorTicksPerMajor", value: minorTicksPerMajor, range: 0...6, label: "Minor Ticks"),
            .slider(key: "majorTickLength", value: majorTickLength, range: 6.0...20.0, step: 1.0, label: "Major Tick Length"),
            .slider(key: "minorTickLength", value: minorTickLength, range: 2.0...12.0, step: 1.0, label: "Minor Tick Length"),
            .slider(key: "tickStrokeWidth", value: tickStrokeWidth, range: 1.0...4.0, step: 0.5, label: "Tick Width"),
            .boolean(key: "showCenterLabel", value: showCenterLabel, label: "Show Center Label"),
            .slider(key: "centerLabelFontSize", value: centerLabelFontSize, range: 8.0...20.0, step: 1.0, label: "Center Label Size"),
            .boolean(key: "showUnitLabel", value: showUnitLabel, label: "Show Unit Label"),
            .string(key: "unitLabelText", value: unitLabelText, label: "Unit Label Text"),
            .slider(key: "unitLabelFontSize", value: unitLabelFontSize, range: 8.0...16.0, step: 1.0, label: "Unit Label Size")
        ]
    }

    public func updatingProperty(key: String, value: Any) -> VerticalSpeedGaugeConfiguration? {
        var updated = self
        switch key {
        case "gaugeStyle":
            if let v = value as? VerticalSpeedGaugeStyle { updated.gaugeStyle = v }
            else if let s = value as? String, let v = VerticalSpeedGaugeStyle(rawValue: s) { updated.gaugeStyle = v }
        case "maxSpeedFPM":
            if let v = value as? Double { updated.maxSpeedFPM = v }
        case "tickColor":
            if let v = value as? SerializableColor { updated.tickColor = v }
        case "numberColor":
            if let v = value as? SerializableColor { updated.numberColor = v }
        case "needleColor":
            if let v = value as? SerializableColor { updated.needleColor = v }
        case "numberFontSize":
            if let v = value as? Double { updated.numberFontSize = v }
        case "majorTicksPerSide":
            if let v = value as? Int { updated.majorTicksPerSide = v }
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
        case "unitLabelText":
            if let v = value as? String { updated.unitLabelText = v }
        case "unitLabelFontSize":
            if let v = value as? Double { updated.unitLabelFontSize = v }
        default:
            return nil
        }
        return updated
    }
}

// MARK: - Renderer

public struct VerticalSpeedGaugeRenderer: InstrumentRenderer {
    public init() {}

    public func render(
        context: MetalRenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        guard let config = configuration as? VerticalSpeedGaugeConfiguration else { return }

        guard let point = dataProvider.currentPoint(), let verticalSpeed = point.verticalSpeed else {
            renderNoData(context: context, config: config)
            return
        }

        let vsFPM = VerticalSpeedUnit.feetPerMinute.convert(metersPerSecond: verticalSpeed)
        renderDial(context: context, verticalSpeedFPM: vsFPM, config: config)
    }

    private func renderDial(context: MetalRenderContext, verticalSpeedFPM: Double, config: VerticalSpeedGaugeConfiguration) {
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
        renderDirectionalMarkers(context: context, center: center, radius: innerRadius, config: config)

        if config.showCenterLabel {
            renderCenterLabel(context: context, center: center, text: config.centerLabelText, config: config)
        }

        if config.showUnitLabel {
            renderUnitLabel(context: context, center: center, text: config.unitLabelText, config: config)
        }

        renderNeedle(context: context, center: center, radius: innerRadius, verticalSpeedFPM: verticalSpeedFPM, config: config)
    }

    private func renderTicks(
        context: MetalRenderContext,
        center: CGPoint,
        radius: CGFloat,
        config: VerticalSpeedGaugeConfiguration
    ) {
        let renderer = Metal2DRenderer.shared(for: context.device)
        let maxHundreds = max(1.0, config.maxSpeedFPM / 100.0)
        let majorValues = [0.0, 0.25, 0.5, 0.75, 1.0].map { $0 * maxHundreds }
        let minorCount = max(0, config.minorTicksPerMajor)

        func drawTick(angleDegrees: Double, isMajor: Bool) {
            let tickLength = CGFloat(isMajor ? config.majorTickLength : config.minorTickLength)
            let tickWidth = CGFloat(isMajor ? config.tickStrokeWidth : config.tickStrokeWidth * 0.5)
            let radians = angleDegrees * .pi / 180
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

        // Major ticks on top and bottom halves
        for value in majorValues {
            let frac = value / maxHundreds
            let topAngle = angleForPositiveFraction(frac)
            drawTick(angleDegrees: topAngle, isMajor: true)
            if value > 0 {
                let bottomAngle = angleForNegativeFraction(frac)
                drawTick(angleDegrees: bottomAngle, isMajor: true)
            }
        }

        // Minor ticks only between 0-5 and 5-10 (i.e. 0-0.25 and 0.25-0.5 of max)
        if minorCount > 0 {
            let minorRanges: [(Double, Double)] = [
                (0.0, 0.25),
                (0.25, 0.5)
            ]
            for (start, end) in minorRanges {
                for m in 1...minorCount {
                    let t = Double(m) / Double(minorCount + 1)
                    let frac = start + (end - start) * t
                    let topAngle = angleForPositiveFraction(frac)
                    let bottomAngle = angleForNegativeFraction(frac)
                    drawTick(angleDegrees: topAngle, isMajor: false)
                    drawTick(angleDegrees: bottomAngle, isMajor: false)
                }
            }
        }
    }

    private func renderNumbers(
        context: MetalRenderContext,
        center: CGPoint,
        radius: CGFloat,
        config: VerticalSpeedGaugeConfiguration
    ) {
        #if canImport(AppKit)
        let renderer = Metal2DRenderer.shared(for: context.device)
        let scale = max(1.0, context.scale)
        let font = NSFont.monospacedDigitSystemFont(ofSize: config.numberFontSize, weight: .semibold)
        let maxHundreds = max(1.0, config.maxSpeedFPM / 100.0)
        let numberRadius = max(
            radius * 0.7,
            radius - CGFloat(config.majorTickLength) - CGFloat(config.numberFontSize) * 0.6
        )

        let labelFractions: [(Double, String)] = [
            (0.0, "0"),
            (0.25, "\(Int(round(maxHundreds * 0.25)))"),
            (0.5, "\(Int(round(maxHundreds * 0.5)))"),
            (0.75, "\(Int(round(maxHundreds * 0.75)))"),
            (1.0, "\(Int(round(maxHundreds)))")
        ]

        for (frac, text) in labelFractions {
            let topAngle = angleForPositiveFraction(frac)
            let topRadians = topAngle * .pi / 180
            let topX = center.x + numberRadius * cos(topRadians)
            let topY = center.y + numberRadius * sin(topRadians)
            if let (tex, size) = MetalTextRenderer.shared.texture(
                text: text,
                font: font,
                color: config.numberColor,
                device: context.device,
                scale: scale,
                extraVerticalPadding: config.numberFontSize * 0.2
            ) {
                let rect = CGRect(
                    x: topX - size.width / 2,
                    y: topY - size.height / 2,
                    width: size.width,
                    height: size.height
                )
                renderer.drawTexture(tex, in: rect, tintColor: .white, renderContext: context)
            }

            // Mirror on bottom half (skip max to avoid duplicate at 3 o'clock)
            if frac > 0 && frac < 1.0 {
                let bottomAngle = angleForNegativeFraction(frac)
                let bottomRadians = bottomAngle * .pi / 180
                let bottomX = center.x + numberRadius * cos(bottomRadians)
                let bottomY = center.y + numberRadius * sin(bottomRadians)
                if let (tex, size) = MetalTextRenderer.shared.texture(
                    text: text,
                    font: font,
                    color: config.numberColor,
                    device: context.device,
                    scale: scale,
                    extraVerticalPadding: config.numberFontSize * 0.2
                ) {
                    let rect = CGRect(
                        x: bottomX - size.width / 2,
                        y: bottomY - size.height / 2,
                        width: size.width,
                        height: size.height
                    )
                    renderer.drawTexture(tex, in: rect, tintColor: .white, renderContext: context)
                }
            }
        }
        #endif
    }

    private func renderCenterLabel(
        context: MetalRenderContext,
        center: CGPoint,
        text: String,
        config: VerticalSpeedGaugeConfiguration
    ) {
        #if canImport(AppKit)
        let renderer = Metal2DRenderer.shared(for: context.device)
        let scale = max(1.0, context.scale)
        let font = NSFont.systemFont(ofSize: config.centerLabelFontSize, weight: .bold)
        let lines = text.components(separatedBy: "\n")
        let lineSpacing: CGFloat = 2
        var totalHeight: CGFloat = 0
        var lineSizes: [CGSize] = []
        for line in lines {
            if let (_, size) = MetalTextRenderer.shared.texture(
                text: line,
                font: font,
                color: config.numberColor,
                device: context.device,
                scale: scale,
                extraVerticalPadding: config.centerLabelFontSize * 0.2
            ) {
                lineSizes.append(size)
                totalHeight += size.height
            }
        }
        totalHeight += lineSpacing * CGFloat(max(0, lineSizes.count - 1))
        var y = center.y - totalHeight / 2 - 8
        for (_, line) in lines.enumerated() {
            guard let (tex, size) = MetalTextRenderer.shared.texture(
                text: line,
                font: font,
                color: config.numberColor,
                device: context.device,
                scale: scale,
                extraVerticalPadding: config.centerLabelFontSize * 0.2
            ) else { continue }
            let rect = CGRect(
                x: center.x + 28 - size.width / 2,
                y: y,
                width: size.width,
                height: size.height
            )
            renderer.drawTexture(tex, in: rect, tintColor: .white, renderContext: context)
            y += size.height + lineSpacing
        }
        #endif
    }

    private func renderUnitLabel(
        context: MetalRenderContext,
        center: CGPoint,
        text: String,
        config: VerticalSpeedGaugeConfiguration
    ) {
        #if canImport(AppKit)
        let renderer = Metal2DRenderer.shared(for: context.device)
        let scale = max(1.0, context.scale)
        let font = NSFont.systemFont(ofSize: config.unitLabelFontSize, weight: .medium)
        let lines = text.components(separatedBy: "\n")
        let lineSpacing: CGFloat = 2
        var totalHeight: CGFloat = 0
        var sizes: [CGSize] = []
        for line in lines {
            if let (_, size) = MetalTextRenderer.shared.texture(
                text: line,
                font: font,
                color: config.numberColor.withAlpha(0.7),
                device: context.device,
                scale: scale,
                extraVerticalPadding: config.unitLabelFontSize * 0.2
            ) {
                sizes.append(size)
                totalHeight += size.height
            }
        }
        totalHeight += lineSpacing * CGFloat(max(0, sizes.count - 1))
        var y = center.y + 26
        for line in lines {
            guard let (tex, size) = MetalTextRenderer.shared.texture(
                text: line,
                font: font,
                color: config.numberColor.withAlpha(0.7),
                device: context.device,
                scale: scale,
                extraVerticalPadding: config.unitLabelFontSize * 0.2
            ) else { continue }
            let rect = CGRect(
                x: center.x + 28 - size.width / 2,
                y: y,
                width: size.width,
                height: size.height
            )
            renderer.drawTexture(tex, in: rect, tintColor: .white, renderContext: context)
            y += size.height + lineSpacing
        }
        #endif
    }

    private func renderDirectionalMarkers(
        context: MetalRenderContext,
        center: CGPoint,
        radius: CGFloat,
        config: VerticalSpeedGaugeConfiguration
    ) {
        #if canImport(AppKit)
        let renderer = Metal2DRenderer.shared(for: context.device)
        let scale = max(1.0, context.scale)
        let font = NSFont.systemFont(ofSize: 10, weight: .bold)

        let upAngle = CGFloat(130) * .pi / 180
        let dnAngle = CGFloat(230) * .pi / 180
        let markerRadius = radius * 0.55
        let markerLength = radius * 0.12

        let upStart = CGPoint(x: center.x + markerRadius * cos(upAngle), y: center.y + markerRadius * sin(upAngle))
        let upEnd = CGPoint(x: center.x + (markerRadius + markerLength) * cos(upAngle), y: center.y + (markerRadius + markerLength) * sin(upAngle))
        renderer.drawLine(from: upStart, to: upEnd, lineWidth: 4, color: SerializableColor(red: 0.35, green: 0.7, blue: 0.9), renderContext: context)

        let dnStart = CGPoint(x: center.x + markerRadius * cos(dnAngle), y: center.y + markerRadius * sin(dnAngle))
        let dnEnd = CGPoint(x: center.x + (markerRadius + markerLength) * cos(dnAngle), y: center.y + (markerRadius + markerLength) * sin(dnAngle))
        renderer.drawLine(from: dnStart, to: dnEnd, lineWidth: 4, color: SerializableColor(red: 0.6, green: 0.4, blue: 0.3), renderContext: context)

        if let (upTex, upSize) = MetalTextRenderer.shared.texture(
            text: "UP",
            font: font,
            color: SerializableColor.white,
            device: context.device,
            scale: scale,
            extraVerticalPadding: 2
        ) {
            let rect = CGRect(
                x: center.x - upSize.width / 2 - radius * 0.22,
                y: center.y - upSize.height / 2 - radius * 0.18,
                width: upSize.width,
                height: upSize.height
            )
            renderer.drawTexture(upTex, in: rect, tintColor: .white, renderContext: context)
        }

        if let (dnTex, dnSize) = MetalTextRenderer.shared.texture(
            text: "DN",
            font: font,
            color: SerializableColor.white,
            device: context.device,
            scale: scale,
            extraVerticalPadding: 2
        ) {
            let rect = CGRect(
                x: center.x - dnSize.width / 2 - radius * 0.20,
                y: center.y - dnSize.height / 2 + radius * 0.18,
                width: dnSize.width,
                height: dnSize.height
            )
            renderer.drawTexture(dnTex, in: rect, tintColor: .white, renderContext: context)
        }
        #endif
    }

    private func renderNeedle(
        context: MetalRenderContext,
        center: CGPoint,
        radius: CGFloat,
        verticalSpeedFPM: Double,
        config: VerticalSpeedGaugeConfiguration
    ) {
        let renderer = Metal2DRenderer.shared(for: context.device)
        let maxFPM = max(100, config.maxSpeedFPM)
        let clamped = max(-maxFPM, min(maxFPM, verticalSpeedFPM))
        // let maxHundreds = max(1.0, maxFPM / 100.0)
        let frac = abs(clamped) / maxFPM
        let angle = clamped >= 0
            ? angleForPositiveFraction(frac)
            : angleForNegativeFraction(frac)
        let radians = angle * .pi / 180
        let length = radius * CGFloat(config.needleLength)
        let end = CGPoint(
            x: center.x + length * cos(radians),
            y: center.y + length * sin(radians)
        )
        renderer.drawLine(from: center, to: end, lineWidth: CGFloat(config.needleStrokeWidth), color: config.needleColor, renderContext: context)
        renderer.drawCircle(center: center, radius: 4, color: config.tickColor, renderContext: context)
    }

    // 0 at 9 o'clock, max at 3 o'clock on top half (through 12 o'clock).
    private func angleForPositiveFraction(_ frac: Double) -> Double {
        let clamped = max(0.0, min(1.0, frac))
        return 180.0 + clamped * 180.0
    }

    // Mirror on bottom half: 0 at 9 o'clock, max at 3 o'clock via 6 o'clock.
    private func angleForNegativeFraction(_ frac: Double) -> Double {
        let clamped = max(0.0, min(1.0, frac))
        return 180.0 - clamped * 180.0
    }

    private func renderNoData(context: MetalRenderContext, config: VerticalSpeedGaugeConfiguration) {
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

public struct VerticalSpeedGaugePlugin: InstrumentPlugin {
    public init() {}

    public static let metadata = PluginMetadata(
        id: "com.flighttrace.vertical-speed-gauge",
        name: "Vertical Speed (Gauge)",
        description: "Analog vertical speed indicator",
        version: "1.0.0",
        category: .indicator,
        iconName: "gauge.with.needle.fill"
    )

    public static let dataDependencies: Set<TelemetryDataType> = [.verticalSpeed, .timestamp]
    public static let defaultSize = CGSize(width: 220, height: 220)
    public static let minimumSize = CGSize(width: 140, height: 140)

    public func createConfiguration() -> any InstrumentConfiguration {
        VerticalSpeedGaugeConfiguration()
    }

    public func createRenderer() -> any InstrumentRenderer {
        VerticalSpeedGaugeRenderer()
    }
}
