// InstrumentView.swift
// SwiftUI view that renders a single instrument on the canvas

import SwiftUI
import CoreGraphics
import CoreLocation
import FlightTraceCore
import FlightTracePlugins

/// View that renders a single instrument instance
///
/// This view wraps the Core Graphics rendering from instrument plugins
/// and presents it in a SwiftUI view hierarchy. It handles:
/// - Rendering the plugin output
/// - Applying position and size transformations
/// - Rotation and layering
public struct InstrumentView: View {

    // MARK: - Properties

    /// The instrument instance to render
    let instrument: InstrumentInstance

    /// The plugin instance
    let plugin: any InstrumentPlugin

    /// The configuration for this instrument
    let configuration: any InstrumentConfiguration

    /// The data provider for telemetry access
    let dataProvider: any TelemetryDataProvider

    /// Current timeline time
    let currentTime: Date

    /// Whether this instrument is selected
    let isSelected: Bool

    // MARK: - Body

    public var body: some View {
        Canvas { context, size in
            // Create render context
            let renderContext = RenderContext(
                bounds: CGRect(origin: .zero, size: size),
                scale: context.environment.displayScale,
                currentTime: currentTime,
                isPreview: true
            )

            // Render the instrument using its renderer
            let renderer = plugin.createRenderer()

            // Render the instrument
            renderWithCanvas(
                context: context,
                size: size,
                renderer: renderer,
                renderContext: renderContext
            )
        }
        .frame(width: instrument.size.width, height: instrument.size.height)
        .rotationEffect(.degrees(instrument.rotation), anchor: .center)
        .position(
            x: instrument.position.x + instrument.size.width / 2,
            y: instrument.position.y + instrument.size.height / 2
        )
        .opacity(instrument.isVisible ? 1 : 0.3)
    }

    // MARK: - Selection Overlay

    private var selectionOverlay: some View {
        Rectangle()
            .strokeBorder(Color.blue, lineWidth: 2)
            .background(Color.blue.opacity(0.1))
            .frame(width: instrument.size.width, height: instrument.size.height)
    }

    // MARK: - Canvas Rendering

    private func renderWithCanvas(
        context: GraphicsContext,
        size: CGSize,
        renderer: any InstrumentRenderer,
        renderContext: RenderContext
    ) {
        // Use CGContext rendering
        _ = CGRect(origin: .zero, size: size)

        // Create a bitmap context for Core Graphics rendering
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return
        }

        let width = Int(size.width * context.environment.displayScale)
        let height = Int(size.height * context.environment.displayScale)

        guard let cgContext = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return
        }

        // Scale context to match display scale
        cgContext.scaleBy(x: context.environment.displayScale, y: context.environment.displayScale)

        // Flip context for macOS coordinate system (bottom-left origin)
        cgContext.translateBy(x: 0, y: size.height)
        cgContext.scaleBy(x: 1, y: -1)

        // Render the instrument
        renderer.render(
            context: cgContext,
            renderContext: renderContext,
            configuration: configuration,
            dataProvider: dataProvider
        )

        // Draw the rendered image into the canvas
        if let image = cgContext.makeImage() {
            let cgImage = Image(decorative: image, scale: context.environment.displayScale)
            context.draw(cgImage, at: CGPoint(x: size.width / 2, y: size.height / 2))
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
struct InstrumentView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample speed gauge plugin for preview
        let plugin = SpeedGaugePlugin()
        let config = SpeedGaugeConfiguration()

        // Create mock data provider
        let mockProvider = MockDataProvider()

        // Create sample instrument instance
        let instrument = InstrumentInstance(
            pluginID: SpeedGaugePlugin.metadata.id,
            name: "Speed",
            position: CGPoint(x: 100, y: 100),
            size: SpeedGaugePlugin.defaultSize
        )

        InstrumentView(
            instrument: instrument,
            plugin: plugin,
            configuration: config,
            dataProvider: mockProvider,
            currentTime: Date(),
            isSelected: true
        )
        .frame(width: 400, height: 300)
        .background(Color.gray.opacity(0.3))
    }
}

/// Mock data provider for previews
private final class MockDataProvider: TelemetryDataProvider {
    func currentPoint() -> TelemetryPoint? {
        TelemetryPoint(
            timestamp: Date(),
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            elevation: 100,
            speed: 25.0, // ~90 km/h
            verticalSpeed: 2.0,
            heading: 180,
            horizontalAccuracy: 5,
            verticalAccuracy: 10,
            gForce: 1.0
        )
    }

    func point(at timestamp: Date) -> TelemetryPoint? {
        currentPoint()
    }

    func points(from startTime: Date, to endTime: Date) -> [TelemetryPoint] {
        []
    }

    func lastPoints(_ count: Int) -> [TelemetryPoint] {
        []
    }

    func track() -> TelemetryTrack? {
        nil
    }

    func trackStatistics() -> TrackStatistics? {
        nil
    }
}
#endif
