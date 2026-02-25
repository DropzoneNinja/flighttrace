// CanvasInstrumentContainer.swift
// Container view that wraps an instrument and its selection handles

import SwiftUI
import CoreGraphics
import FlightTracePlugins

/// Container view that holds an instrument and its selection UI elements
///
/// This view acts as a single draggable unit containing:
/// - The instrument rendering
/// - Selection handles (when in resize mode and selected)
/// - All positioned together so they move as one
struct CanvasInstrumentContainer: View {

    // MARK: - Properties

    let instrument: InstrumentInstance
    let plugin: any InstrumentPlugin
    let configuration: any InstrumentConfiguration
    let dataProvider: any TelemetryDataProvider
    let currentTime: Date
    let isSelected: Bool
    let resizeMode: Bool  // Whether resize mode is active
    let dragOffset: CGSize  // Additional offset during drag

    // MARK: - Callbacks

    let onSelect: () -> Void
    let onDrag: (CGSize) -> Void
    let onDragEnded: () -> Void
    let onResize: (SelectionHandlesView.ResizeHandle, CGSize) -> Void
    let onRotate: (Double) -> Void

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The instrument rendering (at origin, no position modifier)
            instrumentContent
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect()
                }
                .if(!(isSelected && resizeMode)) { view in
                    // Enable drag when NOT in resize mode for selected instrument
                    view.gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                onDrag(value.translation)
                            }
                            .onEnded { _ in
                                onDragEnded()
                            }
                    )
                }

            // Selection handles overlay (only when selected AND in resize mode)
            if isSelected && resizeMode {
                SelectionHandlesView(
                    size: instrument.size,
                    onResize: onResize,
                    onRotate: onRotate,
                    onDrag: nil,  // Disable drag in resize mode
                    onDragEnded: nil
                )
            }
        }
        .frame(width: instrument.size.width, height: instrument.size.height)
        .rotationEffect(.degrees(instrument.rotation), anchor: .center)
        .offset(
            x: instrument.position.x + dragOffset.width,
            y: instrument.position.y + dragOffset.height
        )
    }

    // MARK: - Instrument Content

    private var instrumentContent: some View {
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

            // Use CGContext rendering
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
                print("✅ CGContext.makeImage() succeeded - image size: \(image.width)x\(image.height)")
                let cgImage = Image(decorative: image, scale: context.environment.displayScale)
                context.draw(cgImage, at: CGPoint(x: size.width / 2, y: size.height / 2))
                print("✅ context.draw() called at (\(size.width / 2), \(size.height / 2))")
            } else {
                print("❌ CGContext.makeImage() returned nil!")
            }
        }
        .frame(width: instrument.size.width, height: instrument.size.height)
        .opacity(instrument.isVisible ? 1 : 0.3)
    }
}

// MARK: - View Extensions

private extension View {
    /// Conditionally apply a transformation to the view
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
