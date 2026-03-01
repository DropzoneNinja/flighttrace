// MetalRenderContext.swift
// Shared Metal rendering context for instruments

import Foundation
import CoreGraphics
import Combine
@preconcurrency import Metal

/// Context information provided to plugins during Metal rendering
public struct MetalRenderContext: @unchecked Sendable {
    public let bounds: CGRect
    public let viewportSize: CGSize
    public let scale: CGFloat
    public let currentTime: Date
    public let isPreview: Bool
    public let frameRate: Double
    public let frameNumber: Int?
    public let safeAreaInsets: RenderEdgeInsets

    public let device: MTLDevice
    public let commandBuffer: MTLCommandBuffer
    public let renderEncoder: MTLRenderCommandEncoder

    public init(
        bounds: CGRect,
        viewportSize: CGSize,
        scale: CGFloat,
        currentTime: Date,
        isPreview: Bool,
        frameRate: Double,
        frameNumber: Int?,
        safeAreaInsets: RenderEdgeInsets,
        device: MTLDevice,
        commandBuffer: MTLCommandBuffer,
        renderEncoder: MTLRenderCommandEncoder
    ) {
        self.bounds = bounds
        self.viewportSize = viewportSize
        self.scale = scale
        self.currentTime = currentTime
        self.isPreview = isPreview
        self.frameRate = frameRate
        self.frameNumber = frameNumber
        self.safeAreaInsets = safeAreaInsets
        self.device = device
        self.commandBuffer = commandBuffer
        self.renderEncoder = renderEncoder
    }
}
