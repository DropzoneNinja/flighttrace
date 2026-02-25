// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FlightTrace",
    platforms: [
        .macOS(.v14) // macOS Sonoma and later
    ],
    products: [
        // Main application executable
        .executable(
            name: "FlightTrace",
            targets: ["FlightTraceApp"]
        ),
        // Manual test executable
        .executable(
            name: "ManualTest",
            targets: ["ManualTest"]
        ),
        // Manual Speed Gauge Plugin test
        .executable(
            name: "ManualSpeedGaugeTest",
            targets: ["ManualSpeedGaugeTest"]
        ),
        // Libraries for modular development
        .library(
            name: "FlightTraceCore",
            targets: ["FlightTraceCore"]
        ),
        .library(
            name: "FlightTracePlugins",
            targets: ["FlightTracePlugins"]
        ),
        .library(
            name: "FlightTraceUI",
            targets: ["FlightTraceUI"]
        ),
    ],
    dependencies: [
        // Pure Swift/Apple frameworks - no external dependencies initially
    ],
    targets: [
        // MARK: - Core Module
        // Contains GPX parsing, timeline engine, export engine, data models
        .target(
            name: "FlightTraceCore",
            dependencies: [],
            path: "Sources/FlightTraceCore"
        ),
        .testTarget(
            name: "FlightTraceCoreTests",
            dependencies: ["FlightTraceCore"],
            path: "Tests/FlightTraceCoreTests"
        ),

        // MARK: - Plugins Module
        // Contains plugin protocols, plugin host, and all instrument implementations
        .target(
            name: "FlightTracePlugins",
            dependencies: ["FlightTraceCore"],
            path: "Sources/FlightTracePlugins"
        ),
        .testTarget(
            name: "FlightTracePluginsTests",
            dependencies: ["FlightTracePlugins", "FlightTraceCore"],
            path: "Tests/FlightTracePluginsTests"
        ),

        // MARK: - UI Module
        // Contains SwiftUI views for canvas, timeline, inspector panels
        .target(
            name: "FlightTraceUI",
            dependencies: [
                "FlightTraceCore",
                "FlightTracePlugins"
            ],
            path: "Sources/FlightTraceUI"
        ),

        // MARK: - App Module
        // Main application entry point and window management
        .executableTarget(
            name: "FlightTraceApp",
            dependencies: [
                "FlightTraceCore",
                "FlightTracePlugins",
                "FlightTraceUI"
            ],
            path: "Sources/FlightTraceApp"
        ),

        // MARK: - Integration Tests
        .testTarget(
            name: "FlightTraceIntegrationTests",
            dependencies: [
                "FlightTraceCore",
                "FlightTracePlugins",
                "FlightTraceUI"
            ],
            path: "Tests/FlightTraceIntegrationTests"
        ),

        // MARK: - Manual Test
        .executableTarget(
            name: "ManualTest",
            dependencies: ["FlightTraceCore"],
            path: "Tests",
            sources: ["ManualTest.swift"]
        ),

        // MARK: - Manual Speed Gauge Plugin Test
        .executableTarget(
            name: "ManualSpeedGaugeTest",
            dependencies: ["FlightTraceCore", "FlightTracePlugins"],
            path: "Tests",
            sources: ["ManualSpeedGaugeTest.swift"]
        ),
    ]
)
