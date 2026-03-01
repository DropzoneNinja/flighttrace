// Metal2DRenderer.swift
// Simple 2D rendering helpers for Metal-based plugins

import Foundation
import CoreGraphics
import CoreText
import Metal
import MetalKit

#if canImport(AppKit)
import AppKit
import FlightTraceCore
#endif

struct Metal2DVertex {
    var position: SIMD2<Float>
    var uv: SIMD2<Float>
}

final class Metal2DRenderer: @unchecked Sendable {
    private nonisolated(unsafe) static var cache: [UInt64: Metal2DRenderer] = [:]
    private static let cacheLock = NSLock()

    static func shared(for device: MTLDevice) -> Metal2DRenderer {
        let key = device.registryID
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let existing = cache[key] {
            return existing
        }
        let renderer = Metal2DRenderer(device: device)
        cache[key] = renderer
        return renderer
    }

    private let device: MTLDevice
    private let solidPipeline: MTLRenderPipelineState
    private let texturedPipeline: MTLRenderPipelineState
    private let samplerState: MTLSamplerState
    private let textureLoader: MTKTextureLoader
    private var textureCache: [String: MTLTexture] = [:]
    private let textureCacheLock = NSLock()
    private static let resourceBundle: Bundle = {
        // In Xcode app target (non-SPM), Bundle.module is unavailable.
        // Use the main bundle for resources.
        Bundle.main
    }()

    private init(device: MTLDevice) {
        self.device = device

        self.textureLoader = MTKTextureLoader(device: device)

        let library: MTLLibrary
        if let defaultLibrary = device.makeDefaultLibrary() {
            library = defaultLibrary
        } else if let moduleLibrary = try? device.makeDefaultLibrary(bundle: Metal2DRenderer.resourceBundle) {
            library = moduleLibrary
        } else if let bundleLibrary = Metal2DRenderer.loadLibraryFromBundles(device: device) {
            library = bundleLibrary
        } else if
            let url = Metal2DRenderer.resourceBundle.url(forResource: "Metal2DShaders", withExtension: "metal"),
            let source = try? String(contentsOf: url, encoding: .utf8),
            let sourceLibrary = try? device.makeLibrary(source: source, options: nil) {
            library = sourceLibrary
        } else {
            fatalError("Failed to load Metal shader library from default, module, or bundled metallib.")
        }

        let solidDescriptor = MTLRenderPipelineDescriptor()
        solidDescriptor.vertexFunction = library.makeFunction(name: "vertex_passthrough")
        solidDescriptor.fragmentFunction = library.makeFunction(name: "fragment_solid")
        solidDescriptor.vertexDescriptor = Metal2DRenderer.vertexDescriptor()
        solidDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        solidDescriptor.colorAttachments[0].isBlendingEnabled = true
        solidDescriptor.colorAttachments[0].rgbBlendOperation = .add
        solidDescriptor.colorAttachments[0].alphaBlendOperation = .add
        solidDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        solidDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        solidDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        solidDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        let texturedDescriptor = MTLRenderPipelineDescriptor()
        texturedDescriptor.vertexFunction = library.makeFunction(name: "vertex_passthrough")
        texturedDescriptor.fragmentFunction = library.makeFunction(name: "fragment_textured")
        texturedDescriptor.vertexDescriptor = Metal2DRenderer.vertexDescriptor()
        texturedDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        texturedDescriptor.colorAttachments[0].isBlendingEnabled = true
        texturedDescriptor.colorAttachments[0].rgbBlendOperation = .add
        texturedDescriptor.colorAttachments[0].alphaBlendOperation = .add
        texturedDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        texturedDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        texturedDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        texturedDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            solidPipeline = try device.makeRenderPipelineState(descriptor: solidDescriptor)
            texturedPipeline = try device.makeRenderPipelineState(descriptor: texturedDescriptor)
        } catch {
            fatalError("Failed to create Metal pipeline state: \(error)")
        }

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        samplerState = device.makeSamplerState(descriptor: samplerDescriptor) ?? {
            fatalError("Failed to create Metal sampler state.")
        }()
    }

    func texture(named name: String, bundle: Bundle = Metal2DRenderer.resourceBundle) -> MTLTexture? {
        textureCacheLock.lock()
        if let cached = textureCache[name] {
            textureCacheLock.unlock()
            return cached
        }
        textureCacheLock.unlock()

        guard let url = bundle.url(forResource: name, withExtension: "png") else {
            return nil
        }

        let options: [MTKTextureLoader.Option: Any] = [
            .SRGB: false,
            .origin: MTKTextureLoader.Origin.topLeft
        ]

        guard let texture = try? textureLoader.newTexture(URL: url, options: options) else {
            return nil
        }

        textureCacheLock.lock()
        textureCache[name] = texture
        textureCacheLock.unlock()
        return texture
    }

    private static func loadLibraryFromBundles(device: MTLDevice) -> MTLLibrary? {
        let bundles = [Metal2DRenderer.resourceBundle]
        for bundle in bundles {
            if let urls = bundle.urls(forResourcesWithExtension: "metallib", subdirectory: nil) {
                for url in urls {
                    if let library = try? device.makeLibrary(URL: url) {
                        return library
                    }
                }
            }
        }
        return nil
    }

    private static func vertexDescriptor() -> MTLVertexDescriptor {
        let descriptor = MTLVertexDescriptor()
        descriptor.attributes[0].format = .float2
        descriptor.attributes[0].offset = 0
        descriptor.attributes[0].bufferIndex = 0

        descriptor.attributes[1].format = .float2
        descriptor.attributes[1].offset = MemoryLayout<SIMD2<Float>>.stride
        descriptor.attributes[1].bufferIndex = 0

        descriptor.layouts[0].stride = MemoryLayout<Metal2DVertex>.stride
        descriptor.layouts[0].stepFunction = .perVertex
        descriptor.layouts[0].stepRate = 1
        return descriptor
    }

    func drawRect(
        in rect: CGRect,
        color: SerializableColor,
        renderContext: MetalRenderContext
    ) {
        let vertices = quadVertices(for: rect)
        drawSolid(vertices: vertices, color: color, renderContext: renderContext)
    }

    func drawRoundedRect(
        in rect: CGRect,
        radius: CGFloat,
        color: SerializableColor,
        renderContext: MetalRenderContext
    ) {
        let clampedRadius = max(0, min(radius, min(rect.width, rect.height) / 2))
        if clampedRadius == 0 {
            drawRect(in: rect, color: color, renderContext: renderContext)
            return
        }

        let vertices = roundedRectTriangleFan(rect: rect, radius: clampedRadius, segmentsPerCorner: 12)
        drawSolid(vertices: vertices, color: color, renderContext: renderContext)
    }

    func drawTexture(
        _ texture: MTLTexture,
        in rect: CGRect,
        tintColor: SerializableColor,
        renderContext: MetalRenderContext
    ) {
        let vertices = quadVertices(for: rect, flipVertical: true, flipHorizontal: false)
        let viewport = SIMD2<Float>(Float(renderContext.viewportSize.width), Float(renderContext.viewportSize.height))
        var viewportUniforms = viewport
        var colorUniforms = tintColor.simd

        renderContext.renderEncoder.setRenderPipelineState(texturedPipeline)
        let vertexDataLength = MemoryLayout<Metal2DVertex>.stride * vertices.count
        guard let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertexDataLength, options: .storageModeShared) else {
            return
        }
        renderContext.renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderContext.renderEncoder.setVertexBytes(&viewportUniforms, length: MemoryLayout<SIMD2<Float>>.stride, index: 1)
        renderContext.renderEncoder.setFragmentBytes(&colorUniforms, length: MemoryLayout<SIMD4<Float>>.stride, index: 2)
        renderContext.renderEncoder.setFragmentTexture(texture, index: 0)
        renderContext.renderEncoder.setFragmentSamplerState(samplerState, index: 0)

        renderContext.renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
    }

    func drawTexture(
        _ texture: MTLTexture,
        in rect: CGRect,
        tintColor: SerializableColor,
        renderContext: MetalRenderContext,
        flipVertical: Bool,
        flipHorizontal: Bool = false
    ) {
        let vertices = quadVertices(for: rect, flipVertical: flipVertical, flipHorizontal: flipHorizontal)
        let viewport = SIMD2<Float>(Float(renderContext.viewportSize.width), Float(renderContext.viewportSize.height))
        var viewportUniforms = viewport
        var colorUniforms = tintColor.simd

        renderContext.renderEncoder.setRenderPipelineState(texturedPipeline)
        let vertexDataLength = MemoryLayout<Metal2DVertex>.stride * vertices.count
        guard let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertexDataLength, options: .storageModeShared) else {
            return
        }
        renderContext.renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderContext.renderEncoder.setVertexBytes(&viewportUniforms, length: MemoryLayout<SIMD2<Float>>.stride, index: 1)
        renderContext.renderEncoder.setFragmentBytes(&colorUniforms, length: MemoryLayout<SIMD4<Float>>.stride, index: 2)
        renderContext.renderEncoder.setFragmentTexture(texture, index: 0)
        renderContext.renderEncoder.setFragmentSamplerState(samplerState, index: 0)

        renderContext.renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
    }

    func drawCircle(
        center: CGPoint,
        radius: CGFloat,
        color: SerializableColor,
        renderContext: MetalRenderContext,
        segments: Int = 64
    ) {
        let vertices = circleTriangleFan(center: center, radius: radius, segments: segments)
        drawSolid(vertices: vertices, color: color, renderContext: renderContext)
    }

    func drawCircleStroke(
        center: CGPoint,
        radius: CGFloat,
        lineWidth: CGFloat,
        color: SerializableColor,
        renderContext: MetalRenderContext,
        segments: Int = 64
    ) {
        let thickness = max(1, lineWidth)
        let outer = radius + thickness / 2
        let inner = max(0, radius - thickness / 2)
        let vertices = ringTriangles(center: center, outerRadius: outer, innerRadius: inner, segments: segments)
        drawSolid(vertices: vertices, color: color, renderContext: renderContext)
    }

    func drawLine(
        from start: CGPoint,
        to end: CGPoint,
        lineWidth: CGFloat,
        color: SerializableColor,
        renderContext: MetalRenderContext
    ) {
        let thickness = max(1, lineWidth)
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(0.001, sqrt(dx * dx + dy * dy))
        let nx = -(dy / length) * (thickness / 2)
        let ny = (dx / length) * (thickness / 2)

        let p0 = SIMD2<Float>(Float(start.x + nx), Float(start.y + ny))
        let p1 = SIMD2<Float>(Float(end.x + nx), Float(end.y + ny))
        let p2 = SIMD2<Float>(Float(end.x - nx), Float(end.y - ny))
        let p3 = SIMD2<Float>(Float(start.x - nx), Float(start.y - ny))

        let vertices: [Metal2DVertex] = [
            Metal2DVertex(position: p0, uv: .zero),
            Metal2DVertex(position: p1, uv: .zero),
            Metal2DVertex(position: p2, uv: .zero),
            Metal2DVertex(position: p0, uv: .zero),
            Metal2DVertex(position: p2, uv: .zero),
            Metal2DVertex(position: p3, uv: .zero),
        ]
        drawSolid(vertices: vertices, color: color, renderContext: renderContext)
    }

    private func drawSolid(
        vertices: [Metal2DVertex],
        color: SerializableColor,
        renderContext: MetalRenderContext
    ) {
        let viewport = SIMD2<Float>(Float(renderContext.viewportSize.width), Float(renderContext.viewportSize.height))
        var viewportUniforms = viewport
        var colorUniforms = color.simd

        renderContext.renderEncoder.setRenderPipelineState(solidPipeline)
        let vertexDataLength = MemoryLayout<Metal2DVertex>.stride * vertices.count
        guard let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertexDataLength, options: .storageModeShared) else {
            return
        }
        renderContext.renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderContext.renderEncoder.setVertexBytes(&viewportUniforms, length: MemoryLayout<SIMD2<Float>>.stride, index: 1)
        renderContext.renderEncoder.setFragmentBytes(&colorUniforms, length: MemoryLayout<SIMD4<Float>>.stride, index: 2)

        renderContext.renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
    }
    
    private func quadVertices(for rect: CGRect, flipVertical: Bool = false, flipHorizontal: Bool = false) -> [Metal2DVertex] {
        let x0 = Float(rect.minX)
        let y0 = Float(rect.minY)
        let x1 = Float(rect.maxX)
        let y1 = Float(rect.maxY)

        let uvTop: Float = flipVertical ? 1.0 : 0.0
        let uvBottom: Float = flipVertical ? 0.0 : 1.0
        let uvLeft: Float = flipHorizontal ? 1.0 : 0.0
        let uvRight: Float = flipHorizontal ? 0.0 : 1.0

        return [
            Metal2DVertex(position: SIMD2<Float>(x0, y0), uv: SIMD2<Float>(uvLeft, uvTop)),
            Metal2DVertex(position: SIMD2<Float>(x1, y0), uv: SIMD2<Float>(uvRight, uvTop)),
            Metal2DVertex(position: SIMD2<Float>(x0, y1), uv: SIMD2<Float>(uvLeft, uvBottom)),
            Metal2DVertex(position: SIMD2<Float>(x1, y0), uv: SIMD2<Float>(uvRight, uvTop)),
            Metal2DVertex(position: SIMD2<Float>(x1, y1), uv: SIMD2<Float>(uvRight, uvBottom)),
            Metal2DVertex(position: SIMD2<Float>(x0, y1), uv: SIMD2<Float>(uvLeft, uvBottom)),
        ]
    }

    private func roundedRectTriangleFan(
        rect: CGRect,
        radius: CGFloat,
        segmentsPerCorner: Int
    ) -> [Metal2DVertex] {
        let center = SIMD2<Float>(Float(rect.midX), Float(rect.midY))
        let points = roundedRectPerimeterPoints(rect: rect, radius: radius, segmentsPerCorner: segmentsPerCorner)
        var vertices: [Metal2DVertex] = []

        for i in 0..<points.count {
            let p0 = points[i]
            let p1 = points[(i + 1) % points.count]
            vertices.append(Metal2DVertex(position: center, uv: .zero))
            vertices.append(Metal2DVertex(position: p0, uv: .zero))
            vertices.append(Metal2DVertex(position: p1, uv: .zero))
        }

        return vertices
    }

    private func circleTriangleFan(
        center: CGPoint,
        radius: CGFloat,
        segments: Int
    ) -> [Metal2DVertex] {
        let seg = max(8, segments)
        var vertices: [Metal2DVertex] = []
        let centerVec = SIMD2<Float>(Float(center.x), Float(center.y))
        for i in 0..<seg {
            let a0 = (Float(i) / Float(seg)) * Float.pi * 2
            let a1 = (Float(i + 1) / Float(seg)) * Float.pi * 2
            let p0 = SIMD2<Float>(Float(center.x) + cos(a0) * Float(radius), Float(center.y) + sin(a0) * Float(radius))
            let p1 = SIMD2<Float>(Float(center.x) + cos(a1) * Float(radius), Float(center.y) + sin(a1) * Float(radius))
            vertices.append(Metal2DVertex(position: centerVec, uv: .zero))
            vertices.append(Metal2DVertex(position: p0, uv: .zero))
            vertices.append(Metal2DVertex(position: p1, uv: .zero))
        }
        return vertices
    }

    private func ringTriangles(
        center: CGPoint,
        outerRadius: CGFloat,
        innerRadius: CGFloat,
        segments: Int
    ) -> [Metal2DVertex] {
        let seg = max(8, segments)
        var vertices: [Metal2DVertex] = []
        for i in 0..<seg {
            let a0 = (Float(i) / Float(seg)) * Float.pi * 2
            let a1 = (Float(i + 1) / Float(seg)) * Float.pi * 2

            let outer0 = SIMD2<Float>(Float(center.x) + cos(a0) * Float(outerRadius), Float(center.y) + sin(a0) * Float(outerRadius))
            let outer1 = SIMD2<Float>(Float(center.x) + cos(a1) * Float(outerRadius), Float(center.y) + sin(a1) * Float(outerRadius))
            let inner0 = SIMD2<Float>(Float(center.x) + cos(a0) * Float(innerRadius), Float(center.y) + sin(a0) * Float(innerRadius))
            let inner1 = SIMD2<Float>(Float(center.x) + cos(a1) * Float(innerRadius), Float(center.y) + sin(a1) * Float(innerRadius))

            vertices.append(Metal2DVertex(position: outer0, uv: .zero))
            vertices.append(Metal2DVertex(position: inner0, uv: .zero))
            vertices.append(Metal2DVertex(position: inner1, uv: .zero))

            vertices.append(Metal2DVertex(position: outer0, uv: .zero))
            vertices.append(Metal2DVertex(position: inner1, uv: .zero))
            vertices.append(Metal2DVertex(position: outer1, uv: .zero))
        }
        return vertices
    }

    private func roundedRectPerimeterPoints(
        rect: CGRect,
        radius: CGFloat,
        segmentsPerCorner: Int
    ) -> [SIMD2<Float>] {
        let clampedRadius = max(0, min(radius, min(rect.width, rect.height) / 2))
        let segmentCount = max(2, segmentsPerCorner)

        let minX = Float(rect.minX)
        let maxX = Float(rect.maxX)
        let minY = Float(rect.minY)
        let maxY = Float(rect.maxY)
        let r = Float(clampedRadius)

        var points: [SIMD2<Float>] = []

        func addArc(center: SIMD2<Float>, start: Float, end: Float) {
            let step = (end - start) / Float(segmentCount)
            for i in 0...segmentCount {
                let angle = start + Float(i) * step
                let x = center.x + cos(angle) * r
                let y = center.y + sin(angle) * r
                points.append(SIMD2<Float>(x, y))
            }
        }

        // Top-right corner (0 to 90 degrees)
        addArc(center: SIMD2<Float>(maxX - r, minY + r), start: -Float.pi / 2, end: 0)
        // Bottom-right corner (90 to 180)
        addArc(center: SIMD2<Float>(maxX - r, maxY - r), start: 0, end: Float.pi / 2)
        // Bottom-left corner (180 to 270)
        addArc(center: SIMD2<Float>(minX + r, maxY - r), start: Float.pi / 2, end: Float.pi)
        // Top-left corner (270 to 360)
        addArc(center: SIMD2<Float>(minX + r, minY + r), start: Float.pi, end: Float.pi * 1.5)

        return points
    }
}

final class MetalTextRenderer: @unchecked Sendable {
    private struct TextKey: Hashable {
        let text: String
        let fontName: String
        let fontSize: CGFloat
        let colorRed: Double
        let colorGreen: Double
        let colorBlue: Double
        let colorAlpha: Double
        let scale: CGFloat
        let extraVerticalPadding: CGFloat
    }

    static let shared = MetalTextRenderer()

    private var cache: [TextKey: (MTLTexture, CGSize)] = [:]
    private let lock = NSLock()

    private init() {}

    func texture(
        text: String,
        font: NSFont,
        color: SerializableColor,
        device: MTLDevice,
        scale: CGFloat,
        extraVerticalPadding: CGFloat = 0
    ) -> (MTLTexture, CGSize)? {
        let key = TextKey(
            text: text,
            fontName: font.fontName,
            fontSize: font.pointSize,
            colorRed: color.red,
            colorGreen: color.green,
            colorBlue: color.blue,
            colorAlpha: color.alpha,
            scale: scale,
            extraVerticalPadding: extraVerticalPadding
        )

        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        #if canImport(AppKit)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color.nsColor
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()
        let paddedHeight = textSize.height + (extraVerticalPadding * 2)
        let width = max(1, Int(ceil(textSize.width * scale)))
        let height = max(1, Int(ceil(paddedHeight * scale)))

        let bytesPerRow = width * 4
        guard let data = calloc(height, bytesPerRow) else {
            return nil
        }
        defer { free(data) }

        guard let context = CGContext(
            data: data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: 0, y: extraVerticalPadding + textSize.height)
        context.scaleBy(x: 1.0, y: -1.0)

        let line = CTLineCreateWithAttributedString(attributedString)
        CTLineDraw(line, context)

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead]

        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }

        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: width, height: height, depth: 1))
        texture.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: bytesPerRow)

        let size = CGSize(width: textSize.width, height: paddedHeight)

        lock.lock()
        cache[key] = (texture, size)
        lock.unlock()

        return (texture, size)
        #else
        return nil
        #endif
    }
}

private extension SerializableColor {
    var simd: SIMD4<Float> {
        SIMD4<Float>(Float(red), Float(green), Float(blue), Float(alpha))
    }
}
