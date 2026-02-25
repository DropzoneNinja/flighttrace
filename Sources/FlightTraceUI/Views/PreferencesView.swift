// PreferencesView.swift
// Application preferences window

import SwiftUI

/// Application preferences window
///
/// Manages:
/// - General settings (theme, default canvas size)
/// - Timeline settings
/// - Export settings
/// - Plugin settings
public struct PreferencesView: View {

    @AppStorage("defaultCanvasWidth") private var defaultCanvasWidth: Double = 1920
    @AppStorage("defaultCanvasHeight") private var defaultCanvasHeight: Double = 1080
    @AppStorage("appearance") private var appearance: AppearanceMode = .system
    @AppStorage("snapEnabled") private var snapEnabledByDefault: Bool = true
    @AppStorage("showSafeAreaGuides") private var showSafeAreaGuidesByDefault: Bool = false
    @AppStorage("telemetrySmoothingWindow") private var telemetrySmoothingWindow: Int = 5
    @AppStorage("defaultPlaybackSpeed") private var defaultPlaybackSpeed: Double = 1.0
    @AppStorage("exportQuality") private var exportQuality: ExportQuality = .high

    @State private var selectedTab: PreferencesTab = .general

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            // General tab
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(PreferencesTab.general)

            // Canvas tab
            canvasTab
                .tabItem {
                    Label("Canvas", systemImage: "rectangle.on.rectangle.angled")
                }
                .tag(PreferencesTab.canvas)

            // Timeline tab
            timelineTab
                .tabItem {
                    Label("Timeline", systemImage: "timeline.selection")
                }
                .tag(PreferencesTab.timeline)

            // Export tab
            exportTab
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .tag(PreferencesTab.export)
        }
        .frame(width: 550, height: 400)
    }

    // MARK: - General Tab

    @ViewBuilder
    private var generalTab: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text("Change the application appearance theme")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Telemetry") {
                Stepper("Smoothing Window: \(telemetrySmoothingWindow) samples",
                        value: $telemetrySmoothingWindow,
                        in: 1...20)

                Text("Number of samples to average for smoothing GPS data. Higher values = smoother but more lag.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Canvas Tab

    @ViewBuilder
    private var canvasTab: some View {
        Form {
            Section("Default Canvas Size") {
                HStack {
                    TextField("Width", value: $defaultCanvasWidth, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)

                    Text("×")
                        .foregroundColor(.secondary)

                    TextField("Height", value: $defaultCanvasHeight, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)

                    Text("px")
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    presetButton("1080p", width: 1920, height: 1080)
                    presetButton("720p", width: 1280, height: 720)
                    presetButton("4K", width: 3840, height: 2160)
                    presetButton("1080×1920", width: 1080, height: 1920)
                }
                .font(.caption)
            }

            Section("Canvas Behavior") {
                Toggle("Enable snap guides by default", isOn: $snapEnabledByDefault)
                Toggle("Show safe area guides by default", isOn: $showSafeAreaGuidesByDefault)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private func presetButton(_ label: String, width: Double, height: Double) -> some View {
        Button(label) {
            defaultCanvasWidth = width
            defaultCanvasHeight = height
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Timeline Tab

    @ViewBuilder
    private var timelineTab: some View {
        Form {
            Section("Playback") {
                Slider(value: $defaultPlaybackSpeed, in: 0.25...4.0, step: 0.25) {
                    Text("Default Playback Speed")
                } minimumValueLabel: {
                    Text("0.25×")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("4×")
                        .font(.caption)
                }

                HStack {
                    Text("Speed:")
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f×", defaultPlaybackSpeed))
                        .fontWeight(.medium)
                }
                .font(.caption)
            }

            Section("Synchronization") {
                Text("Timeline synchronization settings will appear here in future releases")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Export Tab

    @ViewBuilder
    private var exportTab: some View {
        Form {
            Section("Quality") {
                Picker("Export Quality", selection: $exportQuality) {
                    ForEach(ExportQuality.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                .pickerStyle(.segmented)

                Text(exportQuality.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Performance") {
                Text("Export performance settings will appear here in future releases")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Preferences Tab

private enum PreferencesTab: String, CaseIterable {
    case general
    case canvas
    case timeline
    case export
}

// MARK: - Appearance Mode

public enum AppearanceMode: String, CaseIterable, Codable {
    case light
    case dark
    case system

    public var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - Export Quality

public enum ExportQuality: String, CaseIterable, Codable {
    case low
    case medium
    case high
    case maximum

    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .maximum: return "Maximum"
        }
    }

    public var description: String {
        switch self {
        case .low:
            return "Faster exports with reduced quality"
        case .medium:
            return "Balanced quality and speed"
        case .high:
            return "High quality exports (recommended)"
        case .maximum:
            return "Maximum quality, slower exports"
        }
    }

    public var bitrate: Int {
        switch self {
        case .low: return 5_000_000
        case .medium: return 10_000_000
        case .high: return 20_000_000
        case .maximum: return 40_000_000
        }
    }
}

// MARK: - Helper to Open Preferences

public struct PreferencesOpener {
    /// Open the preferences window
    @MainActor
    public static func open() {
        let preferencesView = PreferencesView()
        let hostingController = NSHostingController(rootView: preferencesView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Preferences"
        window.styleMask = [.titled, .closable]
        window.level = .floating
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Keep reference to prevent deallocation
        WindowManager.shared.preferencesWindow = window
    }
}

// MARK: - Window Manager

/// Singleton to manage application windows
@MainActor
private class WindowManager {
    static let shared = WindowManager()
    var preferencesWindow: NSWindow?
}
