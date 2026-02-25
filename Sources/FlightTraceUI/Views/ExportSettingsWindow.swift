// ExportSettingsWindow.swift
// Standalone window for export settings

import SwiftUI
import AppKit
import FlightTraceCore

/// Window controller for export settings
public class ExportSettingsWindowController: NSWindowController {

    private var exportConfiguration: ExportConfiguration
    private let onExport: (ExportConfiguration) -> Void

    public init(configuration: ExportConfiguration, onExport: @escaping (ExportConfiguration) -> Void) {
        self.exportConfiguration = configuration
        self.onExport = onExport

        // Create the content view
        let contentView = ExportSettingsWindowContent(
            configuration: configuration,
            onCancel: {
                NSApp.keyWindow?.close()
            },
            onExport: { config in
                NSApp.keyWindow?.close()
                onExport(config)
            }
        )

        // Create hosting controller
        let hostingController = NSHostingController(rootView: contentView)

        // Create window
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Export Settings"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 600, height: 700))
        window.center()

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Content view for export settings window
struct ExportSettingsWindowContent: View {

    @State private var configuration: ExportConfiguration
    let onCancel: () -> Void
    let onExport: (ExportConfiguration) -> Void

    init(configuration: ExportConfiguration, onCancel: @escaping () -> Void, onExport: @escaping (ExportConfiguration) -> Void) {
        self._configuration = State(initialValue: configuration)
        self.onCancel = onCancel
        self.onExport = onExport
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Export Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()

            Divider()

            // Settings form
            ExportSettingsView(configuration: $configuration)
                .frame(minHeight: 500)

            Divider()

            // Footer buttons
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Export") {
                    onExport(configuration)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}
