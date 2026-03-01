// OverlayCanvasView.swift
// Main canvas view for displaying and editing overlay instruments

import SwiftUI
import FlightTraceCore
import FlightTracePlugins

/// Main canvas view for the overlay editor
///
/// Displays all instrument instances and handles:
/// - Rendering instruments in Z-order
/// - Selection and interaction
/// - Canvas background
public struct OverlayCanvasView: View {

    // MARK: - Properties

    /// The view model managing canvas state
    @Bindable var viewModel: CanvasViewModel

    /// Plugin host for accessing plugins
    private let pluginHost: PluginHost

    // MARK: - Direct Timeline Observation

    /// Direct observation of timeline to ensure view updates
    /// This is necessary because TimelineEngine is an ObservableObject nested within the Observable CanvasViewModel
    @ObservedObject private var timelineEngine: TimelineEngine
    @StateObject private var rendererCache = InstrumentRendererCache()

    // MARK: - Drag State

    @State private var draggedInstrumentID: UUID?
    @State private var dragOriginalPosition: CGPoint = .zero
    @State private var currentDragTranslation: CGSize = .zero

    // MARK: - Initialization

    public init(viewModel: CanvasViewModel, pluginHost: PluginHost = .shared) {
        self.viewModel = viewModel
        self.pluginHost = pluginHost
        self._timelineEngine = ObservedObject(wrappedValue: viewModel.timelineEngine)
    }

    // MARK: - Body

    public var body: some View {
        // Main canvas area
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Canvas background - tap here deselects
                Rectangle()
                    .fill(viewModel.backgroundColor)
                    .frame(width: viewModel.canvasSize.width, height: viewModel.canvasSize.height)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.deselectInstrument()
                    }

                // Safe area guides overlay
                if viewModel.showSafeAreaGuides {
                    AspectRatioOverlayView(
                        canvasSize: viewModel.canvasSize,
                        aspectRatio: viewModel.selectedAspectRatio ?? .landscape16x9
                    )
                }

                // Instruments layer
                ForEach(viewModel.sortedInstruments) { instrument in
                    instrumentView(for: instrument)
                }
            }
            .frame(width: viewModel.canvasSize.width, height: viewModel.canvasSize.height)
            .clipped()
        }
    }

    // MARK: - Instrument View

    @ViewBuilder
    private func instrumentView(for instrument: InstrumentInstance) -> some View {
        if let plugin = pluginHost.plugin(withID: instrument.pluginID) {
            let configuration = loadConfiguration(for: instrument, plugin: plugin)
            let isSelected = viewModel.selectedInstrumentID == instrument.id
            let isDragging = draggedInstrumentID == instrument.id

            // Calculate display position
            let displayPosition = isDragging ?
                CGPoint(
                    x: dragOriginalPosition.x + currentDragTranslation.width,
                    y: dragOriginalPosition.y + currentDragTranslation.height
                ) : instrument.position

            // Capture current timeline position to ensure Canvas updates
            // Using the directly observed timelineEngine ensures SwiftUI sees this dependency
            let currentTimelinePosition = timelineEngine.currentPosition

            MetalInstrumentView(
                renderer: rendererCache.renderer(for: instrument.pluginID, plugin: plugin),
                configuration: configuration,
                dataProvider: viewModel.dataProvider,
                currentTime: currentTimelinePosition.gpxTimestamp,
                isPreview: true,
                frameRate: 30.0,
                frameNumber: nil
            )
            .frame(width: instrument.size.width, height: instrument.size.height)
            .opacity(instrument.isVisible ? 1 : 0.3)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white, lineWidth: 2)
                    .opacity(isSelected ? 1 : 0)
            )
            .id("\(instrument.id)-\(currentTimelinePosition.videoTime)")
            .rotationEffect(.degrees(instrument.rotation), anchor: .center)
            .position(
                x: displayPosition.x + instrument.size.width / 2,
                y: displayPosition.y + instrument.size.height / 2
            )
            .if(!(isSelected && viewModel.resizeMode)) { view in
                // Only enable drag when NOT in resize mode with this instrument selected
                view.gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            handleDragChanged(instrumentID: instrument.id, value: value)
                        }
                        .onEnded { value in
                            handleDragEnded(instrumentID: instrument.id, value: value)
                        }
                )
            }
            .onTapGesture {
                viewModel.selectInstrument(id: instrument.id)
            }

            // Resize handles overlay (separate positioned element)
            if isSelected && viewModel.resizeMode {
                SelectionHandlesView(
                    size: instrument.size,
                    onResize: { handle, newSize in
                        viewModel.resizeInstrument(id: instrument.id, to: newSize, fromHandle: handle)
                    },
                    onRotate: { angle in
                        viewModel.rotateInstrument(id: instrument.id, by: angle)
                    },
                    onDrag: nil,
                    onDragEnded: nil
                )
                .rotationEffect(.degrees(instrument.rotation), anchor: .center)
                .position(
                    x: displayPosition.x + instrument.size.width / 2,
                    y: displayPosition.y + instrument.size.height / 2
                )
            }
        } else {
            // Plugin not found - show placeholder
            placeholderView(for: instrument)
        }
    }

    // MARK: - Placeholder View

    private func placeholderView(for instrument: InstrumentInstance) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.red.opacity(0.3))
                .border(Color.red, width: 2)

            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.red)

                Text("Plugin Not Found")
                    .font(.caption)
                    .foregroundColor(.white)

                Text(instrument.pluginID)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(width: instrument.size.width, height: instrument.size.height)
        .offset(x: instrument.position.x, y: instrument.position.y)
    }

    // MARK: - Gesture Handlers

    private func handleDragChanged(instrumentID: UUID, value: DragGesture.Value) {
        // On first drag event, store the original position
        if draggedInstrumentID != instrumentID {
            draggedInstrumentID = instrumentID
            if let instrument = viewModel.instruments.first(where: { $0.id == instrumentID }) {
                dragOriginalPosition = instrument.position
            }
        }

        // Store the cumulative translation
        currentDragTranslation = value.translation
    }

    private func handleDragEnded(instrumentID: UUID, value: DragGesture.Value) {
        // Calculate final position
        let finalPosition = CGPoint(
            x: dragOriginalPosition.x + value.translation.width,
            y: dragOriginalPosition.y + value.translation.height
        )

        // Update instrument position
        viewModel.updateInstrument(id: instrumentID) { instrument in
            instrument.position = finalPosition
        }

        // Reset drag state
        draggedInstrumentID = nil
        dragOriginalPosition = .zero
        currentDragTranslation = .zero
    }

    // MARK: - Helper Methods

    private func loadConfiguration(
        for instrument: InstrumentInstance,
        plugin: any InstrumentPlugin
    ) -> any InstrumentConfiguration {
        if let configData = instrument.configurationData {
            let configType = type(of: plugin.createConfiguration())
            if let decoded = try? configType.decode(from: configData) {
                return decoded
            }
        }
        return plugin.createConfiguration()
    }
}

// MARK: - View Extensions

private extension View {
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

// MARK: - Preview

#if DEBUG
struct OverlayCanvasView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = CanvasViewModel(
            canvasSize: CGSize(width: 1920, height: 1080)
        )

        return OverlayCanvasView(viewModel: viewModel)
            .frame(width: 800, height: 600)
            .background(Color.gray)
    }
}
#endif
