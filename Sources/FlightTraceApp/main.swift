// FlightTraceApp - Main Application Entry Point

import SwiftUI
import FlightTraceCore
import FlightTracePlugins
import FlightTraceUI

@main
struct FlightTraceApp: App {
    init() {
        // Register built-in plugins at startup (synchronously on main thread)
        registerPlugins()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            FlightTraceCommands()
        }
    }

    private func registerPlugins() {
        // Register plugins synchronously
        MainActor.assumeIsolated {
            // Register built-in plugins
            try? PluginHost.shared.register(SpeedGaugePlugin.self)
            try? PluginHost.shared.register(AltitudeGaugePlugin.self)
            try? PluginHost.shared.register(VerticalSpeedPlugin.self)
            try? PluginHost.shared.register(GMeterPlugin.self)
            try? PluginHost.shared.register(HeadingPlugin.self)
            try? PluginHost.shared.register(TimestampPlugin.self)
            try? PluginHost.shared.register(DistancePlugin.self)
            try? PluginHost.shared.register(TracklinePlugin.self)
            try? PluginHost.shared.register(MinimapPlugin.self)

            print("✓ Registered \(PluginHost.shared.availablePlugins().count) plugin(s)")
        }
    }
}

struct ContentView: View {
    @State private var viewModel = CanvasViewModel(
        canvasSize: CGSize(width: 1920, height: 1080)
    )

    var body: some View {
        MainWindowView(viewModel: viewModel)
            .frame(minWidth: 1200, minHeight: 800)
            .focusedCanvasViewModel(viewModel)
    }
}
