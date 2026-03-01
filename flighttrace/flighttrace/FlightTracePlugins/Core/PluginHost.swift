// PluginHost.swift
// Plugin registry and discovery system

import Foundation
import CoreGraphics

/// Central registry for managing instrument plugins
///
/// The PluginHost is responsible for:
/// - Registering available plugins
/// - Discovering and enumerating plugins
/// - Validating plugin compatibility
/// - Creating plugin instances
///
/// ## Usage
/// ```swift
/// // Register built-in plugins at app startup
/// PluginHost.shared.register(SpeedGaugePlugin.self)
/// PluginHost.shared.register(AltitudeDigitalPlugin.self)
///
/// // Enumerate available plugins
/// let plugins = PluginHost.shared.availablePlugins()
///
/// // Get a specific plugin
/// if let plugin = PluginHost.shared.plugin(id: "com.flighttrace.speed-gauge") {
///     let instance = PluginHost.shared.createInstance(of: plugin)
/// }
/// ```
@MainActor
public final class PluginHost {

    // MARK: - Singleton

    /// Shared plugin host instance
    public static let shared = PluginHost()

    // MARK: - Internal Properties

    /// Registry of all registered plugins (keyed by plugin ID)
    internal var registry: [String: any InstrumentPlugin.Type] = [:]

    /// Initialization lock
    private var isInitialized = false

    // MARK: - Initialization

    private init() {}

    // MARK: - Registration

    /// Register a plugin type with the host
    ///
    /// - Parameter pluginType: The plugin type to register
    /// - Throws: `PluginError.duplicateID` if a plugin with the same ID is already registered
    public func register(_ pluginType: any InstrumentPlugin.Type) throws {
        let metadata = pluginType.metadata

        // Check for duplicate IDs
        if registry[metadata.id] != nil {
            throw PluginError.duplicateID(metadata.id)
        }

        registry[metadata.id] = pluginType
    }

    /// Register multiple plugin types at once
    ///
    /// - Parameter pluginTypes: Array of plugin types to register
    /// - Throws: `PluginError.duplicateID` if any plugin has a duplicate ID
    public func register(_ pluginTypes: [any InstrumentPlugin.Type]) throws {
        for pluginType in pluginTypes {
            try register(pluginType)
        }
    }

    /// Unregister a plugin by ID
    ///
    /// - Parameter id: The plugin ID to unregister
    public func unregister(id: String) {
        registry.removeValue(forKey: id)
    }

    /// Remove all registered plugins
    public func unregisterAll() {
        registry.removeAll()
    }

    // MARK: - Discovery

    /// Get all available plugins
    ///
    /// - Returns: Array of plugin metadata for all registered plugins
    public func availablePlugins() -> [PluginMetadata] {
        registry.values.map { $0.metadata }
    }

    /// Get plugins filtered by category
    ///
    /// - Parameter category: The category to filter by
    /// - Returns: Array of plugin metadata matching the category
    public func plugins(in category: PluginCategory) -> [PluginMetadata] {
        registry.values
            .map { $0.metadata }
            .filter { $0.category == category }
    }

    /// Get a specific plugin by ID
    ///
    /// - Parameter id: The plugin ID
    /// - Returns: Plugin metadata if found, nil otherwise
    public func plugin(id: String) -> PluginMetadata? {
        registry[id]?.metadata
    }

    /// Get plugin type by ID
    ///
    /// - Parameter id: The plugin ID
    /// - Returns: The plugin type if found, nil otherwise
    public func pluginType(id: String) -> (any InstrumentPlugin.Type)? {
        registry[id]
    }

    // MARK: - Instance Creation

    /// Create a new instance of a plugin
    ///
    /// - Parameter id: The plugin ID
    /// - Returns: A new plugin instance, or nil if plugin not found
    public func createInstance(id: String) -> (any InstrumentPlugin)? {
        guard let pluginType = registry[id] else {
            return nil
        }
        return pluginType.init()
    }

    /// Create instances of multiple plugins
    ///
    /// - Parameter ids: Array of plugin IDs
    /// - Returns: Array of plugin instances (excludes plugins not found)
    public func createInstances(ids: [String]) -> [any InstrumentPlugin] {
        ids.compactMap { createInstance(id: $0) }
    }

    // MARK: - Validation

    /// Check if a plugin's data dependencies can be satisfied
    ///
    /// - Parameters:
    ///   - id: The plugin ID
    ///   - availableData: Set of available telemetry data types
    /// - Returns: Validation result indicating if plugin can be used
    public func validate(
        pluginID id: String,
        withAvailableData availableData: Set<TelemetryDataType>
    ) -> PluginValidationResult {
        guard let pluginType = registry[id] else {
            return .notFound
        }

        let dependencies = pluginType.dataDependencies
        let missingData = dependencies.subtracting(availableData)

        if missingData.isEmpty {
            return .valid
        } else {
            return .missingData(missingData)
        }
    }

    /// Get all plugins that can be used with the available data
    ///
    /// - Parameter availableData: Set of available telemetry data types
    /// - Returns: Array of plugin metadata for compatible plugins
    public func compatiblePlugins(withAvailableData availableData: Set<TelemetryDataType>) -> [PluginMetadata] {
        registry.values
            .filter { $0.dataDependencies.isSubset(of: availableData) }
            .map { $0.metadata }
    }

    // MARK: - Debug

    /// Get debug information about registered plugins
    public func debugInfo() -> String {
        var info = "PluginHost Registry:\n"
        info += "Total plugins: \(registry.count)\n\n"

        for (id, pluginType) in registry.sorted(by: { $0.key < $1.key }) {
            let metadata = pluginType.metadata
            info += "ID: \(id)\n"
            info += "  Name: \(metadata.name)\n"
            info += "  Version: \(metadata.version)\n"
            info += "  Category: \(metadata.category.rawValue)\n"
            info += "  Dependencies: \(pluginType.dataDependencies.map { $0.rawValue }.joined(separator: ", "))\n"
            info += "  Default Size: \(pluginType.defaultSize)\n\n"
        }

        return info
    }
}

// MARK: - Plugin Error

/// Errors that can occur during plugin operations
public enum PluginError: Error, CustomStringConvertible {
    case duplicateID(String)
    case notFound(String)
    case invalidConfiguration
    case renderingFailed(Error)

    public var description: String {
        switch self {
        case .duplicateID(let id):
            return "Plugin with ID '\(id)' is already registered"
        case .notFound(let id):
            return "Plugin with ID '\(id)' not found"
        case .invalidConfiguration:
            return "Plugin configuration is invalid"
        case .renderingFailed(let error):
            return "Plugin rendering failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Plugin Validation Result

/// Result of validating a plugin against available data
public enum PluginValidationResult: Equatable {
    case valid
    case notFound
    case missingData(Set<TelemetryDataType>)

    public var isValid: Bool {
        if case .valid = self {
            return true
        }
        return false
    }
}

// MARK: - InstrumentPlugin Notes

/// Plugins should provide their own init() implementation.
/// Most plugins will be structs with no stored properties, so they get a default init() automatically.
/// If your plugin is a class or has stored properties, implement init() explicitly.
