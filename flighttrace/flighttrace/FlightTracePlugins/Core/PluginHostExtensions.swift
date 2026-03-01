// PluginHostExtensions.swift
// Convenience extensions for PluginHost

import Foundation

// MARK: - Convenience Methods

extension PluginHost {

    /// Get a plugin instance by ID
    ///
    /// - Parameter id: The plugin ID
    /// - Returns: A new plugin instance, or nil if not found
    public func plugin(withID id: String) -> (any InstrumentPlugin)? {
        createInstance(id: id)
    }

    /// Get all registered plugin instances
    ///
    /// - Returns: Array of all plugin instances
    public func allPlugins() -> [any InstrumentPlugin] {
        registry.values.map { $0.init() }
    }

    /// Get all plugin types
    ///
    /// - Returns: Array of all plugin types
    public func allPluginTypes() -> [any InstrumentPlugin.Type] {
        Array(registry.values)
    }

    /// Convenient registration that doesn't throw
    ///
    /// Silently ignores duplicate registrations for convenience during development
    /// - Parameter pluginType: The plugin type to register
    /// - Returns: true if registered successfully, false if duplicate
    @discardableResult
    public func registerSafely(_ pluginType: any InstrumentPlugin.Type) -> Bool {
        do {
            try register(pluginType)
            return true
        } catch {
            return false
        }
    }
}
