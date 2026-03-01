// MetalInstrumentView.swift
// SwiftUI wrapper for Metal-based instrument rendering

import SwiftUI
import Metal
import MetalKit
import FlightTraceCore
import FlightTracePlugins

struct MetalInstrumentView: NSViewRepresentable {
    let renderer: any InstrumentRenderer
    let configuration: any InstrumentConfiguration
    let dataProvider: any TelemetryDataProvider
    let currentTime: Date
    let isPreview: Bool
    let frameRate: Double
    let frameNumber: Int?

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = context.coordinator.device
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.framebufferOnly = false
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColorMake(0, 0, 0, 0)
        view.delegate = context.coordinator
        view.preferredFramesPerSecond = 30
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.view = nsView
        context.coordinator.renderer = renderer
        context.coordinator.configuration = configuration
        context.coordinator.dataProvider = dataProvider
        context.coordinator.currentTime = currentTime
        context.coordinator.isPreview = isPreview
        context.coordinator.frameRate = frameRate
        context.coordinator.frameNumber = frameNumber
        context.coordinator.requestRedraw(view: nsView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        let device: MTLDevice
        private let commandQueue: MTLCommandQueue

        weak var view: MTKView?
        var renderer: (any InstrumentRenderer)?
        var configuration: (any InstrumentConfiguration)?
        var dataProvider: (any TelemetryDataProvider)?
        var currentTime: Date = Date()
        var isPreview: Bool = true
        var frameRate: Double = 60.0
        var frameNumber: Int? = nil
        private var lastDrawTime: CFTimeInterval = 0
        private let minFrameInterval: CFTimeInterval = 1.0 / 30.0
        private var tileCacheObserver: Any?

        override init() {
            guard let device = MTLCreateSystemDefaultDevice(),
                  let queue = device.makeCommandQueue() else {
                fatalError("Metal is required but no compatible device was found.")
            }
            self.device = device
            self.commandQueue = queue
            super.init()

            tileCacheObserver = NotificationCenter.default.addObserver(
                forName: Notification.Name("MinimapTileCacheDidUpdate"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self, let view = self.view else { return }
                self.requestRedraw(view: view)
            }
        }

        deinit {
            if let observer = tileCacheObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func requestRedraw(view: MTKView) {
            let now = CACurrentMediaTime()
            if now - lastDrawTime >= minFrameInterval {
                lastDrawTime = now
                view.setNeedsDisplay(view.bounds)
            }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // No-op
        }

        func draw(in view: MTKView) {
            guard
                let renderer,
                let configuration,
                let dataProvider,
                let drawable = view.currentDrawable,
                let commandBuffer = commandQueue.makeCommandBuffer()
            else {
                return
            }

            guard view.drawableSize.width > 0,
                  view.drawableSize.height > 0,
                  view.bounds.width > 0,
                  view.bounds.height > 0 else {
                return
            }

            lastDrawTime = CACurrentMediaTime()

            let passDescriptor = MTLRenderPassDescriptor()
            passDescriptor.colorAttachments[0].texture = drawable.texture
            passDescriptor.colorAttachments[0].loadAction = .clear
            passDescriptor.colorAttachments[0].storeAction = .store
            passDescriptor.colorAttachments[0].clearColor = view.clearColor

            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
                return
            }

            let bounds = view.bounds
            let scale = bounds.width > 0 ? view.drawableSize.width / bounds.width : 1.0

            let renderContext = MetalRenderContext(
                bounds: bounds,
                viewportSize: bounds.size,
                scale: scale,
                currentTime: currentTime,
                isPreview: isPreview,
                frameRate: frameRate,
                frameNumber: frameNumber,
                safeAreaInsets: .zero,
                device: device,
                commandBuffer: commandBuffer,
                renderEncoder: encoder
            )

            renderer.render(
                context: renderContext,
                configuration: configuration,
                dataProvider: dataProvider
            )

            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
