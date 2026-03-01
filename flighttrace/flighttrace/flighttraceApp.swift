// FlightTraceApp - Main Application Entry Point

import SwiftUI
import AppKit
import FlightTraceUI

@main
struct FlightTraceApp: App {
    #if canImport(AppKit)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    init() {
        // Register built-in plugins at startup (synchronously on main thread)
        registerPlugins()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    #if canImport(AppKit)
                    let bid = Bundle.main.bundleIdentifier ?? "nil"
                    // print("[App] WindowGroup.onAppear: bundleId=\(bid) isActive=\(NSApp.isActive) windows=\(NSApp.windows.count) key=\(NSApp.keyWindow?.title ?? "nil")")
                    NSApp.setActivationPolicy(.regular)
                    if let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first {
                        // print("[App] WindowGroup.onAppear: making key window: \(window.title)")
                        window.makeKeyAndOrderFront(nil)
                    } else {
                        // print("[App] WindowGroup.onAppear: no window to make key")
                    }
                    NSApp.activate(ignoringOtherApps: true)
                    #endif
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            FlightTraceCommands()
        }
    }

    private func registerPlugins() {
        // Centralized registration in FlightTraceUI to avoid direct symbol references here
        PluginRegistration.registerBuiltIns()
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

#if canImport(AppKit)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let bid = Bundle.main.bundleIdentifier ?? "nil"
        // print("[AppDelegate] didFinishLaunching: bundleId=\(bid) activationPolicy=\(String(describing: NSApp.activationPolicy))")
        NSApp.setActivationPolicy(.regular)
        if let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first {
            // print("[AppDelegate] making key window: \(window.title)")
            window.makeKeyAndOrderFront(nil)
        } else {
            // print("[AppDelegate] no window available at launch")
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationDidBecomeActive(_ notification: Notification) {
        // print("[AppDelegate] applicationDidBecomeActive")
    }

    func applicationDidResignActive(_ notification: Notification) {
        // print("[AppDelegate] applicationDidResignActive")
    }
}
#endif
