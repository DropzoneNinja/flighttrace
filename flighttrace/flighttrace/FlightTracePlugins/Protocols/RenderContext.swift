// RenderContext.swift
// Provides canvas information and rendering context for instrument plugins

import Foundation
import CoreGraphics
import FlightTraceCore

/// Context information provided to plugins during rendering
///
/// This struct encapsulates all the information an instrument plugin needs to render itself,
/// including canvas bounds, scale factors, and rendering metadata.
public struct RenderContext: Sendable {

    // MARK: - Canvas Properties

    /// The bounds where the instrument should render (in points)
    public let bounds: CGRect

    /// The scale factor for the current display (1.0 for standard, 2.0+ for Retina)
    public let scale: CGFloat

    /// The current timestamp in the timeline (for time-based animations or data queries)
    public let currentTime: Date

    // MARK: - Rendering Metadata

    /// Whether this is a preview render (true) or final export render (false)
    ///
    /// Plugins may choose to reduce quality or disable effects during preview for performance
    public let isPreview: Bool

    /// The target frame rate for the current rendering context
    ///
    /// Useful for plugins that need to implement smooth animations or time-based effects
    public let frameRate: Double

    /// The current frame number (for export rendering)
    ///
    /// This is nil during preview rendering and available during export
    public let frameNumber: Int?

    // MARK: - Safe Area Guides

    /// Safe area insets for common aspect ratios
    ///
    /// Plugins can use this to avoid rendering important content in unsafe zones
    public let safeAreaInsets: FlightTraceCore.RenderEdgeInsets

    // MARK: - Initialization

    public init(
        bounds: CGRect,
        scale: CGFloat = 1.0,
        currentTime: Date,
        isPreview: Bool = true,
        frameRate: Double = 60.0,
        frameNumber: Int? = nil,
        safeAreaInsets: FlightTraceCore.RenderEdgeInsets = .zero
    ) {
        self.bounds = bounds
        self.scale = scale
        self.currentTime = currentTime
        self.isPreview = isPreview
        self.frameRate = frameRate
        self.frameNumber = frameNumber
        self.safeAreaInsets = safeAreaInsets
    }
}
