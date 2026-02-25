// PluginCatalogVerification.swift
// Verification that all 9 built-in plugins are registered correctly
// Run manually in Xcode or via the app's debug output

import Foundation
@preconcurrency import FlightTracePlugins

/// Verifies that all built-in plugins are correctly registered
@MainActor
func verifyPluginCatalog() {
    print("🔍 Verifying Plugin Catalog...")
    print("=" * 60)

    // Expected plugins
    let expectedPlugins = [
        "com.flighttrace.speed-gauge",
        "com.flighttrace.altitude-gauge",
        "com.flighttrace.vertical-speed",
        "com.flighttrace.g-meter",
        "com.flighttrace.heading",
        "com.flighttrace.timestamp",
        "com.flighttrace.distance",
        "com.flighttrace.trackline",
        "com.flighttrace.minimap"
    ]

    // Register all plugins (as done in main.swift)
    try? PluginHost.shared.register([
        SpeedGaugePlugin.self,
        AltitudeGaugePlugin.self,
        VerticalSpeedPlugin.self,
        GMeterPlugin.self,
        HeadingPlugin.self,
        TimestampPlugin.self,
        DistancePlugin.self,
        TracklinePlugin.self,
        MinimapPlugin.self
    ])

    // Get all registered plugins
    let availablePlugins = PluginHost.shared.availablePlugins()

    print("\n📊 Registration Summary:")
    print("  Expected: \(expectedPlugins.count) plugins")
    print("  Registered: \(availablePlugins.count) plugins")

    // Check each expected plugin
    var allFound = true
    print("\n✓ Plugin Verification:")

    for expectedID in expectedPlugins {
        if let plugin = PluginHost.shared.plugin(id: expectedID) {
            print("  ✅ \(plugin.name) (\(plugin.id))")
            print("      Category: \(plugin.category.rawValue)")
            print("      Version: \(plugin.version)")
        } else {
            print("  ❌ Missing: \(expectedID)")
            allFound = false
        }
    }

    // List plugins by category
    print("\n📁 Plugins by Category:")
    for category in PluginCategory.allCases {
        let plugins = PluginHost.shared.plugins(in: category)
        if !plugins.isEmpty {
            print("  \(category.rawValue.capitalized): \(plugins.map { $0.name }.joined(separator: ", "))")
        }
    }

    // Final result
    print("\n" + "=" * 60)
    if allFound && availablePlugins.count == expectedPlugins.count {
        print("✅ SUCCESS: All 9 built-in plugins are registered correctly!")
    } else {
        print("❌ FAILURE: Plugin catalog verification failed")
    }
    print("=" * 60)
}

// Operator overload for string repetition
private func * (string: String, count: Int) -> String {
    String(repeating: string, count: count)
}
