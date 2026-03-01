// MainWindowView.swift
// Main application window with integrated sidebars and panels

import SwiftUI
#if canImport(AppKit)
import AppKit
import FlightTraceCore
import FlightTracePlugins
#endif

/// Main application window view
///
/// Layout:
/// - Left sidebar: Plugin catalog
/// - Center: Canvas and timeline
/// - Right sidebar: Inspector panel
/// - Top: Toolbar and file import areas
public struct MainWindowView: View {

    @Bindable var viewModel: CanvasViewModel
    @AppStorage("appearance") private var appearance: AppearanceMode = .system
    @AppStorage("showPluginCatalog") private var showPluginCatalog: Bool = true
    @AppStorage("showInspector") private var showInspector: Bool = true

    @State private var showGPXImport: Bool = true
    @State private var showVideoImport: Bool = false
    @State private var gpxLoadSuccess: String?

    // Export state
    @State private var exportSettingsWindow: ExportSettingsWindowController?
    @State private var showExportProgress: Bool = false
    @State private var exportProgress: ExportEngine.ExportProgress?
    @State private var exportOrchestrator: ExportOrchestrator?

    public init(viewModel: CanvasViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HSplitView {
            // Left sidebar: Plugin catalog
            if showPluginCatalog {
                PluginCatalogView(viewModel: viewModel)
                    .frame(minWidth: 250, idealWidth: 280, maxWidth: 350)
            }

            // Center: Main content area
            VStack(spacing: 0) {
                // Success message after GPX load
                if let success = gpxLoadSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("GPX File Loaded Successfully")
                                .font(.headline)
                            Text(success)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            gpxLoadSuccess = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Top import area (if no GPX loaded)
                if viewModel.timelineEngine.track == nil {
                    GPXImportView(viewModel: viewModel, onSuccess: { message in
                        gpxLoadSuccess = message
                        // Auto-dismiss after 5 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            gpxLoadSuccess = nil
                        }
                    })
                        .frame(height: 200)
                        .background(Color(nsColor: .controlBackgroundColor))

                    Divider()
                }

                // Optional video import area
                if showVideoImport {
                    VideoImportView(viewModel: viewModel)
                        .frame(height: 150)
                        .background(Color(nsColor: .controlBackgroundColor))

                    Divider()
                }

                // Canvas view (main content)
                MainCanvasView(viewModel: viewModel, onExport: prepareExport)
            }
            .frame(minWidth: 600)

            // Right sidebar: Inspector
            if showInspector {
                InspectorPanelView(viewModel: viewModel)
                    .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)
            }
        }
        .toolbar {
            toolbarContent
        }
        .preferredColorScheme(appearance.colorScheme)
        .sheet(isPresented: $showExportProgress) {
            exportProgressSheet
        }
        .focusedCanvasViewModel(viewModel)
        .focusedValue(\.exportAction, prepareExport)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // File operations
        ToolbarItemGroup(placement: .navigation) {
            Menu {
                Button("Open GPX...") {
                    showGPXImport = true
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Open Layout...") {
                    loadLayout()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Divider()

                Button("Save Layout...") {
                    saveLayout()
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(viewModel.instruments.isEmpty)

                Button("Save Layout As...") {
                    saveLayout()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(viewModel.instruments.isEmpty)

                Divider()

                Button("Import Video Background...") {
                    showVideoImport.toggle()
                }

                Divider()

                Button("Export Video...") {
                    prepareExport()
                }
                .keyboardShortcut("e", modifiers: [.command])
                .disabled(!canExport)

            } label: {
                Label("File", systemImage: "doc")
            }
            .help("File operations")
        }

        // View toggles
        ToolbarItemGroup(placement: .principal) {
            Toggle(isOn: $showPluginCatalog) {
                Label("Instruments", systemImage: "sidebar.left")
            }
            .help("Toggle instrument catalog")

            Toggle(isOn: $showInspector) {
                Label("Inspector", systemImage: "sidebar.right")
            }
            .help("Toggle inspector panel")

            Divider()

            Toggle(isOn: $viewModel.showSafeAreaGuides) {
                Label("Guides", systemImage: "square.grid.3x3")
            }
            .help("Toggle safe area guides")
        }

        // Export
        ToolbarItemGroup(placement: .automatic) {
            Divider()

            Button {
                prepareExport()
            } label: {
                Label("Export Video", systemImage: "square.and.arrow.up")
            }
            .help("Export video with overlays")
            .disabled(!canExport)
            .keyboardShortcut("e", modifiers: [.command])
        }

        // Settings and help
        ToolbarItemGroup(placement: .automatic) {
            Button {
                PreferencesOpener.open()
            } label: {
                Label("Preferences", systemImage: "gearshape")
            }
            .help("Open preferences")
        }
    }

    // MARK: - Computed Properties

    private var canExport: Bool {
        // Can export if we have a timeline loaded and at least one instrument
        viewModel.timelineEngine.track != nil && !viewModel.instruments.isEmpty
    }

    // MARK: - Actions

    private func saveLayout() {
        LayoutFileManager.saveLayout(viewModel: viewModel) { result in
            switch result {
            case .success(let url):
                print("Layout saved to: \(url.path)")
            case .failure(let error):
                print("Failed to save layout: \(error.localizedDescription)")
            }
        }
    }

    private func loadLayout() {
        LayoutFileManager.loadLayout(viewModel: viewModel) { result in
            switch result {
            case .success:
                print("Layout loaded successfully")
            case .failure(let error):
                print("Failed to load layout: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Export Actions

    private func prepareExport() {
        print("DEBUG: prepareExport() called")

        // Create default export configuration
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let outputURL = documentsURL.appendingPathComponent("flighttrace-export.mp4")

        let config = ExportConfiguration(
            outputURL: outputURL,
            codec: .h264,
            resolution: .hd1080p,
            frameRate: .fps30,
            quality: .medium,
            canvasSize: viewModel.canvasSize
        )

        print("DEBUG: Creating export settings window...")

        // Create and show export settings window
        let windowController = ExportSettingsWindowController(
            configuration: config,
            onExport: { finalConfig in
                Task { @MainActor in
                    await self.startExport(with: finalConfig)
                }
            }
        )

        self.exportSettingsWindow = windowController
        windowController.show()

        print("DEBUG: Export settings window shown")
    }

    private func startExport(with config: ExportConfiguration) async {
        // Show progress
        showExportProgress = true
        exportProgress = nil

        // Create orchestrator
        let orchestrator = ExportOrchestrator(
            instruments: viewModel.instruments,
            timeline: viewModel.timelineEngine,
            configuration: config
        )
        self.exportOrchestrator = orchestrator

        do {
            // Start export with progress updates
            try await orchestrator.export { progress in
                Task { @MainActor in
                    self.exportProgress = progress
                }
            }

            // Export completed successfully
            await MainActor.run {
                showExportProgress = false
                // Show success alert
                let alert = NSAlert()
                alert.messageText = "Export Completed"
                alert.informativeText = "Video exported successfully to:\n\(config.outputURL.path)"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.addButton(withTitle: "Show in Finder")

                let response = alert.runModal()
                if response == .alertSecondButtonReturn {
                    NSWorkspace.shared.activateFileViewerSelecting([config.outputURL])
                }
            }
        } catch {
            // Export failed
            await MainActor.run {
                showExportProgress = false

                let alert = NSAlert()
                alert.messageText = "Export Failed"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .critical
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }

    private func cancelExport() {
        exportOrchestrator?.cancel()
        showExportProgress = false
    }

    // MARK: - Export Sheets

    @ViewBuilder
    private var exportProgressSheet: some View {
        VStack(spacing: 0) {
            if let progress = exportProgress {
                ExportProgressView(progress: progress) {
                    cancelExport()
                }
            } else {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Preparing Export...")
                        .font(.headline)
                }
                .padding(40)
                .frame(width: 400, height: 200)
            }
        }
    }
}

// MARK: - Menu Commands

/// Application menu commands
public struct FlightTraceCommands: Commands {

    @FocusedValue(\.canvasViewModel) private var viewModel: CanvasViewModel?
    @FocusedValue(\.exportAction) private var exportAction: (() -> Void)?

    public init() {}

    public var body: some Commands {
        // App menu (About)
        CommandGroup(replacing: .appInfo) {
            Button("About FlightTrace") {
                showAboutPanel()
            }
        }

        // File menu
        CommandGroup(replacing: .newItem) {
            Button("Open GPX...") {
                // Action handled by toolbar
            }
            .keyboardShortcut("o", modifiers: [.command])

            Button("Open Layout...") {
                if let vm = viewModel {
                    LayoutFileManager.loadLayout(viewModel: vm) { _ in }
                }
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .disabled(viewModel == nil)

            Divider()

            Button("Save Layout...") {
                if let vm = viewModel {
                    LayoutFileManager.saveLayout(viewModel: vm) { _ in }
                }
            }
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(viewModel?.instruments.isEmpty != false)

            Button("Save Layout As...") {
                if let vm = viewModel {
                    LayoutFileManager.saveLayout(viewModel: vm) { _ in }
                }
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(viewModel?.instruments.isEmpty != false)

            Divider()

            Button("Export Video...") {
                exportAction?()
            }
            .keyboardShortcut("e", modifiers: [.command])
            .disabled(viewModel?.timelineEngine.track == nil || viewModel?.instruments.isEmpty != false || exportAction == nil)
        }

        // Edit menu additions
        CommandGroup(after: .undoRedo) {
            Divider()

            Button("Delete Selected Instrument") {
                if let vm = viewModel, let selectedID = vm.selectedInstrumentID {
                    vm.removeInstrument(id: selectedID)
                }
            }
            .keyboardShortcut(.delete, modifiers: [])
            .disabled(viewModel?.selectedInstrumentID == nil)
        }

        // View menu
        CommandMenu("View") {
            Button("Show Plugin Catalog") {
                // Toggle handled by AppStorage
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button("Show Inspector") {
                // Toggle handled by AppStorage
            }
            .keyboardShortcut("2", modifiers: [.command])

            Divider()

            Button("Show Safe Area Guides") {
                viewModel?.showSafeAreaGuides.toggle()
            }
            .keyboardShortcut("g", modifiers: [.command])
            .disabled(viewModel == nil)

            Button("Toggle Snap Guides") {
                viewModel?.snapEnabled.toggle()
            }
            .keyboardShortcut("'", modifiers: [.command])
            .disabled(viewModel == nil)
        }

        // Instrument menu
        CommandMenu("Instrument") {
            Button("Bring Forward") {
                if let vm = viewModel, let selectedID = vm.selectedInstrumentID {
                    vm.bringForward(id: selectedID)
                }
            }
            .keyboardShortcut("]", modifiers: [.command])
            .disabled(viewModel?.selectedInstrumentID == nil)

            Button("Send Backward") {
                if let vm = viewModel, let selectedID = vm.selectedInstrumentID {
                    vm.sendBackward(id: selectedID)
                }
            }
            .keyboardShortcut("[", modifiers: [.command])
            .disabled(viewModel?.selectedInstrumentID == nil)

            Divider()

            Button("Bring to Front") {
                if let vm = viewModel, let selectedID = vm.selectedInstrumentID {
                    vm.bringToFront(id: selectedID)
                }
            }
            .keyboardShortcut("]", modifiers: [.command, .option])
            .disabled(viewModel?.selectedInstrumentID == nil)

            Button("Send to Back") {
                if let vm = viewModel, let selectedID = vm.selectedInstrumentID {
                    vm.sendToBack(id: selectedID)
                }
            }
            .keyboardShortcut("[", modifiers: [.command, .option])
            .disabled(viewModel?.selectedInstrumentID == nil)
        }

        // Window menu (preferences)
        CommandGroup(replacing: .appSettings) {
            Button("Preferences...") {
                PreferencesOpener.open()
            }
            .keyboardShortcut(",", modifiers: [.command])
        }
    }

    private func showAboutPanel() {
        #if canImport(AppKit)
        let bundle = Bundle.main
        let version = (bundle.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0"
        let build = (bundle.infoDictionary?["CFBundleVersion"] as? String) ?? "0"
        let options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationVersion: "Version \(version) (Build \(build))",
            .credits: NSAttributedString(string: "© 2026 Michael Steinmann. All rights reserved.")
        ]
        NSApp.orderFrontStandardAboutPanel(options: options)
        NSApp.activate(ignoringOtherApps: true)
        #endif
    }
}

// MARK: - Focused Values

private struct CanvasViewModelKey: FocusedValueKey {
    typealias Value = CanvasViewModel
}

private struct ExportActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var canvasViewModel: CanvasViewModel? {
        get { self[CanvasViewModelKey.self] }
        set { self[CanvasViewModelKey.self] = newValue }
    }

    var exportAction: (() -> Void)? {
        get { self[ExportActionKey.self] }
        set { self[ExportActionKey.self] = newValue }
    }
}

extension View {
    public func focusedCanvasViewModel(_ viewModel: CanvasViewModel?) -> some View {
        focusedValue(\.canvasViewModel, viewModel)
    }
}
// MARK: - Built-in Plugin Registration (UI module)

/// Centralized registration for built-in plugins that are available in FlightTracePlugins.
/// Keeping this in the UI module avoids referencing plugin symbols from the app target directly.
public enum PluginRegistration {
    public static func registerBuiltIns() {
        MainActor.assumeIsolated {
            // Register available plugins. Commented out unresolved symbols to allow the app to compile.
            try? PluginHost.shared.register([
                AirspeedGaugePlugin.self,
                AltimeterGaugePlugin.self,
                AltitudeDigitalPlugin.self,
                AltitudeGraphPlugin.self,
                DistanceDigitalPlugin.self,
                GMeterDigitalPlugin.self,
                HeadingPlugin.self,
                MinimapPlugin.self,
                SpeedDigitalPlugin.self,
                TimestampDigitalPlugin.self,
                TracklinePlugin.self,
                VerticalSpeedGaugePlugin.self,
                VerticalSpeedDigitalPlugin.self
            ])

            let count = PluginHost.shared.availablePlugins().count
            print("✓ Registered \(count) plugin(s)")
        }
    }
}

