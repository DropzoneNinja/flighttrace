// InstrumentRenderer.swift
// Protocol for rendering instrument visuals

import Foundation
import CoreGraphics
import Metal

#if canImport(AppKit)
import AppKit
import FlightTraceCore
#endif

/// Protocol for rendering an instrument's visual representation
///
/// Renderers are responsible for drawing the instrument using Metal. They receive telemetry
/// data and configuration, and encode draw commands into a shared render pass.
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
/// - Use Metal for all rendering
/// - Cache expensive computations in the configuration when possible
///
/// ## Example Implementation
/// ```swift
/// struct SpeedGaugeRenderer: InstrumentRenderer {
///     func render(
///         context: MetalRenderContext,
///         configuration: any InstrumentConfiguration,
///         dataProvider: any TelemetryDataProvider
///     ) {
///         // Encode Metal draw calls using context.renderEncoder
///     }
/// }
/// ```
public protocol InstrumentRenderer: Sendable {

    /// Render the instrument into a Metal render pass
    ///
    /// - Parameters:
    ///   - context: Metal render context (encoder, bounds, timing)
    ///   - configuration: The current configuration for this instrument instance
    ///   - dataProvider: Provider for querying telemetry data
    ///
    /// - Note: This method must be deterministic - same inputs must produce identical output
    ///         for frame-accurate video export
    /// - Note: Do not end the render encoder; it is managed by the caller.
    func render(
        context: MetalRenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    )

}
