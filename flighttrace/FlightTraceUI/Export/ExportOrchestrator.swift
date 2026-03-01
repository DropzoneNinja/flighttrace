// ExportOrchestrator.swift
// Bridges the export engine with the UI layer and plugin system

import Foundation
import CoreGraphics
import FlightTraceCore
import FlightTracePlugins

/// Orchestrates the export process by connecting instruments, timeline, and export engine
///
/// The ExportOrchestrator is responsible for:
/// - Taking instrument instances from the canvas
/// - Setting up the export engine with proper rendering closure
/// - Managing the timeline for frame-by-frame data access
/// - Rendering all active instruments for each frame
///
/// ## Usage
/// ```swift
/// let orchestrator = await ExportOrchestrator(
///     instruments: canvasViewModel.instruments,
///     timeline: timelineEngine,
///     configuration: exportConfig
/// )
///
/// try await orchestrator.export { progress in
///     print("Exporting: \(progress.percentComplete)%")
/// }
/// ```
@MainActor
public final class ExportOrchestrator {

    // MARK: - Properties

    private let instruments: [InstrumentInstance]
    private let timeline: TimelineEngine
    private let configuration: ExportConfiguration
    private let pluginHost: PluginHost

    private var exportEngine: ExportEngine?

    // MARK: - Initialization

    /// Create an export orchestrator
    ///
    /// - Parameters:
    ///   - instruments: The instrument instances to render
    ///   - timeline: The timeline engine for data synchronization
    ///   - configuration: Export configuration
    ///   - pluginHost: Plugin host (defaults to shared instance)
    public init(
        instruments: [InstrumentInstance],
        timeline: TimelineEngine,
        configuration: ExportConfiguration,
        pluginHost: PluginHost = .shared
    ) {
        self.instruments = instruments
        self.timeline = timeline
        self.configuration = configuration
        self.pluginHost = pluginHost
    }

    // MARK: - Export

    /// Execute the export
    ///
    /// - Parameter progressCallback: Optional closure for progress updates
    /// - Throws: Export errors if the process fails
    public func export(
        progressCallback: (@Sendable (ExportEngine.ExportProgress) -> Void)? = nil
    ) async throws {
        // Create export engine
        let duration = timeline.duration
        let startTime = timeline.track?.startTime ?? Date()

        let engine = ExportEngine(
            configuration: configuration,
            duration: duration,
            startTime: startTime
        )
        self.exportEngine = engine

        // Create thread-safe data provider for export
        let dataProvider = ExportDataProvider(
            track: timeline.track,
            timeOffset: timeline.timeOffset,
            startTime: startTime
        )

        // Prepare plugin instances and configurations
        let renderableInstruments = try prepareInstruments()

        // Debug: Log which instruments are being exported
        print("ExportOrchestrator: Prepared \(renderableInstruments.count) instruments for export:")
        for (index, renderable) in renderableInstruments.enumerated() {
            print("  [\(index)] \(renderable.plugin.metadata.name) at position (\(Int(renderable.instance.position.x)), \(Int(renderable.instance.position.y))) size (\(Int(renderable.instance.size.width))x\(Int(renderable.instance.size.height)))")
        }

        // Capture values before closure to avoid self capture
        let frameRate = configuration.frameRate.rawValue
        let canvasSize = configuration.effectiveCanvasSize

        // Setup rendering closure (must not capture self - runs on background thread)
        engine.setRenderingClosure { context, size, timestamp, frameNumber in
            if frameNumber == 0 {
                print("🎬 ExportOrchestrator: Rendering frame 0")
                print("   Video size: \(size.width)x\(size.height)")
                print("   Canvas size: \(canvasSize.width)x\(canvasSize.height)")
            }

            // Update data provider's current timestamp for this frame
            dataProvider.setCurrentTimestamp(timestamp)

            // Render all instruments at this timestamp (using canvas coordinates)
            let scaleX = size.width / canvasSize.width
            let scaleY = size.height / canvasSize.height
            if frameNumber == 0 {
                print("   Scaling: \(scaleX)x \(scaleY)y")
            }

            Self.renderInstrumentsStatic(
                renderableInstruments,
                into: context,
                canvasSize: canvasSize,
                renderTargetSize: size,
                scaleX: scaleX,
                scaleY: scaleY,
                timestamp: timestamp,
                frameNumber: frameNumber,
                dataProvider: dataProvider,
                frameRate: frameRate
            )

            if frameNumber == 0 {
                print("🎬 ExportOrchestrator: Finished frame 0")
            }
        }

        // Execute export
        try await engine.export(progressCallback: progressCallback)
    }

    /// Cancel the ongoing export
    public func cancel() {
        exportEngine?.cancel()
    }

    // MARK: - Instrument Preparation

    /// Renderable instrument data
    private struct RenderableInstrument: Sendable {
        let instance: InstrumentInstance
        let plugin: any InstrumentPlugin.Type
        let renderer: any InstrumentRenderer
        let configuration: any InstrumentConfiguration
    }

    /// Prepare all instruments for rendering
    private func prepareInstruments() throws -> [RenderableInstrument] {
        var renderables: [RenderableInstrument] = []

        // Sort instruments by Z-order (render from back to front)
        let sortedInstruments = instruments
            .filter { $0.isVisible }
            .sorted { $0.zOrder < $1.zOrder }

        for instance in sortedInstruments {
            // Get plugin type
            guard let pluginType = pluginHost.pluginType(id: instance.pluginID) else {
                print("Warning: Plugin not found for ID: \(instance.pluginID)")
                continue
            }

            // Create plugin instance
            let plugin = pluginType.init()

            // Get renderer
            let renderer = plugin.createRenderer()

            // Get or create configuration (decode from data if available)
            let configuration: any InstrumentConfiguration
            if let configData = instance.configurationData {
                // Decode existing configuration from data
                let configType = type(of: plugin.createConfiguration())
                if let decoded = try? configType.decode(from: configData) {
                    configuration = decoded
                    print("ExportOrchestrator: Decoded configuration for \(pluginType.metadata.name)")
                } else {
                    configuration = plugin.createConfiguration()
                    print("ExportOrchestrator: Warning - Failed to decode configuration for \(pluginType.metadata.name), using defaults")
                }
            } else {
                // No saved configuration, use defaults
                configuration = plugin.createConfiguration()
                print("ExportOrchestrator: Using default configuration for \(pluginType.metadata.name)")
            }

            renderables.append(RenderableInstrument(
                instance: instance,
                plugin: pluginType,
                renderer: renderer,
                configuration: configuration
            ))
        }

        return renderables
    }

    // MARK: - Frame Rendering

    /// Render all instruments for a single frame (static method to avoid actor isolation issues)
    private nonisolated static func renderInstrumentsStatic(
        _ instruments: [RenderableInstrument],
        into context: MetalRenderContext,
        canvasSize: CGSize,
        renderTargetSize: CGSize,
        scaleX: CGFloat,
        scaleY: CGFloat,
        timestamp: Date,
        frameNumber: Int,
        dataProvider: TelemetryDataProvider,
        frameRate: Int
    ) {
        // Debug: Log first frame rendering
        if frameNumber == 0 {
            print("ExportOrchestrator: Starting to render frame 0 with \(instruments.count) instruments")
            print("   Canvas size for rendering: \(canvasSize.width)x\(canvasSize.height)")
        }

        for renderable in instruments {
            let instance = renderable.instance

            // Calculate instrument bounds in canvas space
            let instrumentBounds = CGRect(
                x: instance.position.x * scaleX,
                y: instance.position.y * scaleY,
                width: instance.size.width * scaleX,
                height: instance.size.height * scaleY
            )

            // Create render context for this instrument
            let instrumentRenderContext = MetalRenderContext(
                bounds: instrumentBounds,
                viewportSize: renderTargetSize,
                scale: 1.0, // Export uses 1.0 scale, final resolution is determined by video settings
                currentTime: timestamp,
                isPreview: false,
                frameRate: Double(frameRate),
                frameNumber: frameNumber,
                safeAreaInsets: .zero,
                device: context.device,
                commandBuffer: context.commandBuffer,
                renderEncoder: context.renderEncoder
            )

            // Debug: Log before rendering
            if frameNumber == 0 {
                print("ExportOrchestrator: About to render \(renderable.plugin.metadata.name) at frame 0")
            }

            // Render the instrument
            renderable.renderer.render(
                context: instrumentRenderContext,
                configuration: renderable.configuration,
                dataProvider: dataProvider
            )

            // Debug: Log after rendering
            if frameNumber == 0 {
                print("ExportOrchestrator: Finished rendering \(renderable.plugin.metadata.name) at frame 0")
            }

        }
    }
}

// MARK: - Convenience Extensions

public extension ExportOrchestrator {
    /// Create an orchestrator from canvas view model
    ///
    /// - Parameters:
    ///   - canvasViewModel: The canvas view model containing instruments
    ///   - timeline: Timeline engine
    ///   - configuration: Export configuration
    /// - Returns: Configured orchestrator
    static func fromCanvas(
        canvasViewModel: CanvasViewModel,
        timeline: TimelineEngine,
        configuration: ExportConfiguration
    ) -> ExportOrchestrator {
        ExportOrchestrator(
            instruments: canvasViewModel.instruments,
            timeline: timeline,
            configuration: configuration
        )
    }
}
