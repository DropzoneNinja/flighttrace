// FlightTracePlugins Module
// Plugin architecture and instrument implementations

import FlightTraceCore

/// Version information for FlightTracePlugins
public enum FlightTracePluginsVersion {
    public static let version = "0.1.0"
}

// MARK: - Module Documentation

/// FlightTracePlugins provides a complete plugin architecture for instrument overlays.
///
/// ## Key Components
///
/// ### Protocols
/// - `InstrumentPlugin`: Core protocol all plugins must implement
/// - `InstrumentRenderer`: Protocol for rendering instrument visuals
/// - `InstrumentConfiguration`: Protocol for plugin configuration
/// - `TelemetryDataProvider`: Interface for accessing telemetry data
///
/// ### Core Types
/// - `PluginHost`: Central registry for plugin discovery and management
/// - `RenderContext`: Context information for rendering
/// - `PluginMetadata`: Plugin identification and metadata
///
/// ### Supporting Types
/// - `SerializableColor`: Cross-platform color serialization
/// - `ConfigurationProperty`: Declarative property definitions
/// - `TelemetryDataType`: Telemetry data type enumeration
/// - `PluginCategory`: Plugin categorization
///
/// ## Usage
///
/// ```swift
/// import FlightTracePlugins
///
/// // Define a plugin
/// struct MyPlugin: InstrumentPlugin {
///     static let metadata = PluginMetadata(...)
///     static let dataDependencies: Set<TelemetryDataType> = [.speed]
///     static let defaultSize = CGSize(width: 200, height: 100)
///
///     func createConfiguration() -> any InstrumentConfiguration { ... }
///     func createRenderer() -> any InstrumentRenderer { ... }
/// }
///
/// // Register at app startup
/// try await PluginHost.shared.register(MyPlugin.self)
/// ```
///
/// See `PLUGIN_ARCHITECTURE.md` for complete documentation.
