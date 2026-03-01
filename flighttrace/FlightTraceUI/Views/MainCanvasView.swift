// MainCanvasView.swift
// Main view combining the overlay canvas and timeline controls

import SwiftUI
import FlightTraceCore
import FlightTracePlugins

/// Main canvas view that combines the overlay canvas with timeline controls
///
/// This is the primary editing interface for FlightTrace, providing:
/// - Full canvas for overlay editing
/// - Timeline scrubber at the bottom
/// - Real-time preview updates
/// - Toolbar for common actions
public struct MainCanvasView: View {

    // MARK: - Properties

    /// The canvas view model
    @Bindable public var viewModel: CanvasViewModel
    private let onExport: (() -> Void)?

    @ObservedObject private var timelineEngine: TimelineEngine

    // MARK: - Initialization

    public init(viewModel: CanvasViewModel, onExport: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onExport = onExport
        self._timelineEngine = ObservedObject(wrappedValue: viewModel.timelineEngine)
    }

    // MARK: - State

    /// Whether the canvas is being zoomed/panned
    @State private var canvasScale: CGFloat = 1.0
    @State private var canvasOffset: CGSize = .zero

    /// Whether to show the toolbar
    @State private var showToolbar = true

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            if showToolbar {
                toolbar
                    .transition(.move(edge: .top))
            }

            // Main canvas area
            canvasArea

            // Timeline scrubber
            Divider()
            TimelineScrubberView(timelineEngine: viewModel.timelineEngine)
        }
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 16) {
            // Export action
            exportButton

            Spacer()

            // View controls
            viewControls

            Divider()
                .frame(height: 20)

            // Info display
            infoDisplay
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.windowBackgroundColor).opacity(0.95))
    }

    // MARK: - Export Button

    private var exportButton: some View {
        Button(action: {
            onExport?()
        }) {
            Label("Export Video", systemImage: "square.and.arrow.up")
                .font(.headline)
        }
        .buttonStyle(.borderless)
        .help("Export video with overlays")
        .disabled(!canExport || onExport == nil)
    }

    // MARK: - View Controls

    private var viewControls: some View {
        HStack(spacing: 8) {
            // Toggle safe area guides
            Button(action: { viewModel.showSafeAreaGuides.toggle() }) {
                Image(systemName: viewModel.showSafeAreaGuides ? "grid" : "grid")
                    .foregroundColor(viewModel.showSafeAreaGuides ? .blue : .primary)
            }
            .buttonStyle(.borderless)
            .help("Toggle safe area guides")

            // Zoom controls
            Button(action: { canvasScale = max(0.1, canvasScale - 0.1) }) {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Zoom out")

            Text("\(Int(canvasScale * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 40)

            Button(action: { canvasScale = min(4.0, canvasScale + 0.1) }) {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Zoom in")

            Button(action: { canvasScale = 1.0; canvasOffset = .zero }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.borderless)
            .help("Fit to window")
        }
    }

    // MARK: - Info Display

    private var infoDisplay: some View {
        HStack(spacing: 12) {
            // Canvas size
            Text("\(Int(viewModel.canvasSize.width))×\(Int(viewModel.canvasSize.height))")
                .font(.caption)
                .foregroundColor(.secondary)

            // Instrument count
            Text("\(viewModel.instruments.count) instruments")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Canvas Area

    private var canvasArea: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                OverlayCanvasView(viewModel: viewModel)
                    .scaleEffect(canvasScale)
                    .frame(
                        width: viewModel.canvasSize.width * canvasScale,
                        height: viewModel.canvasSize.height * canvasScale
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.1))
        }
    }

    // MARK: - Helper Methods

    private var canExport: Bool {
        timelineEngine.track != nil && !viewModel.instruments.isEmpty
    }
}

// MARK: - Preview

#if DEBUG
struct MainCanvasView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample view model
        let viewModel = CanvasViewModel(
            canvasSize: CGSize(width: 1920, height: 1080)
        )

        return MainCanvasView(viewModel: viewModel)
            .frame(width: 1200, height: 800)
    }
}
#endif
