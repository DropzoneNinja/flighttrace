// InstrumentRenderer.swift
// Protocol for rendering instrument visuals

import Foundation
import CoreGraphics

#if canImport(AppKit)
import AppKit
#endif

/// Protocol for rendering an instrument's visual representation
///
/// Renderers are responsible for drawing the instrument using Core Graphics, Core Animation,
/// or Metal. They receive telemetry data and configuration, and produce visual output.
///
/// ## Rendering Requirements
/// - Renderers must be stateless (deterministic output for same input)
/// - All rendering must be resolution-independent (vector-based preferred)
/// - Renderers should optimize for real-time preview performance
/// - Export rendering may use higher quality settings than preview
///
/// ## Performance Guidelines
/// - Target 60fps for preview rendering on Apple Silicon
/// - Minimize allocations in the render path
/// - Use Metal for complex rendering if Core Graphics is insufficient
/// - Cache expensive computations in the configuration when possible
///
/// ## Example Implementation
/// ```swift
/// struct SpeedGaugeRenderer: InstrumentRenderer {
///     func render(
///         context: CGContext,
///         renderContext: RenderContext,
///         configuration: any InstrumentConfiguration,
///         dataProvider: any TelemetryDataProvider
///     ) {
///         guard let point = dataProvider.currentPoint(),
///               let speed = point.speed,
///               let config = configuration as? SpeedGaugeConfiguration else {
///             return
///         }
///
///         // Draw background
///         context.setFillColor(.black.copy(alpha: 0.7)!)
///         context.fill(renderContext.bounds)
///
///         // Draw speed text
///         let speedValue = config.units == .mph ? speed * 2.237 : speed * 3.6
///         // ... text rendering
///     }
/// }
/// ```
public protocol InstrumentRenderer: Sendable {

    /// Render the instrument into a Core Graphics context
    ///
    /// - Parameters:
    ///   - context: The Core Graphics context to render into
    ///   - renderContext: Information about the rendering context (bounds, scale, time)
    ///   - configuration: The current configuration for this instrument instance
    ///   - dataProvider: Provider for querying telemetry data
    ///
    /// - Note: This method must be deterministic - same inputs must produce identical output
    ///         for frame-accurate video export
    func render(
        context: CGContext,
        renderContext: RenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    )

    /// Optional: Return a SwiftUI view for rendering (alternative to Core Graphics)
    ///
    /// If implemented, this view will be used for preview rendering in SwiftUI.
    /// Export rendering will still use the Core Graphics render method.
    ///
    /// - Parameters:
    ///   - renderContext: Information about the rendering context
    ///   - configuration: The current configuration for this instrument instance
    ///   - dataProvider: Provider for querying telemetry data
    /// - Returns: A view representing the instrument, or nil to use Core Graphics rendering
    @MainActor
    func createView(
        renderContext: RenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) -> InstrumentView?
}

// MARK: - Default Implementations

public extension InstrumentRenderer {
    /// Default implementation returns nil (use Core Graphics rendering)
    @MainActor
    func createView(
        renderContext: RenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) -> InstrumentView? {
        nil
    }
}

// MARK: - InstrumentView

/// Type-erased view for SwiftUI-based instrument rendering
///
/// This is a wrapper that allows plugins to return SwiftUI views without
/// exposing generic types in the protocol
///
/// Note: This is a placeholder for future SwiftUI integration.
/// Currently, plugins should use Core Graphics rendering via the render() method.
public struct InstrumentView: Sendable {
    // Placeholder - will be implemented when SwiftUI rendering support is added
}
