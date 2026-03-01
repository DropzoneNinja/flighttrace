// InstrumentPlugin.swift
// Core protocol that all instrument plugins must implement

import Foundation
import CoreGraphics

/// Core protocol that defines an instrument plugin
///
/// Every instrument in FlightTrace is implemented as a plugin that conforms to this protocol.
/// This ensures complete isolation between plugins and the core application.
///
/// ## Plugin Isolation Rules
/// - Plugins must NOT access UI internals or video export internals directly
/// - Plugins receive only telemetry data through the TelemetryDataProvider interface
/// - All plugin parameters must be declarative and serializable
/// - Plugins must be stateless with respect to rendering (same input = same output)
///
/// ## Example Implementation
/// ```swift
/// struct SpeedGaugePlugin: InstrumentPlugin {
///     static let metadata = PluginMetadata(
///         id: "com.flighttrace.speed-gauge",
///         name: "Speed Gauge",
///         description: "Displays current speed",
///         version: "1.0.0"
///     )
///
///     static let dataDependencies: Set<TelemetryDataType> = [.speed, .timestamp]
///     static let defaultSize = CGSize(width: 200, height: 100)
///
///     func createConfiguration() -> InstrumentConfiguration {
///         SpeedGaugeConfiguration()
///     }
///
///     func createRenderer() -> InstrumentRenderer {
///         SpeedGaugeRenderer()
///     }
/// }
/// ```
public protocol InstrumentPlugin: Sendable {

    // MARK: - Initialization

    /// Required initializer for plugins
    init()

    // MARK: - Plugin Identity

    /// Metadata identifying and describing this plugin
    static var metadata: PluginMetadata { get }

    // MARK: - Data Requirements

    /// The telemetry data types this plugin requires to function
    ///
    /// Declaring dependencies allows the system to:
    /// - Validate that required data is available before enabling the plugin
    /// - Optimize data loading and caching
    /// - Display warnings if data is missing (e.g., GPX without elevation)
    static var dataDependencies: Set<TelemetryDataType> { get }

    // MARK: - Default Properties

    /// The default size of the instrument when first added to canvas
    static var defaultSize: CGSize { get }

    /// The minimum size the instrument can be resized to
    static var minimumSize: CGSize { get }

    // MARK: - Factory Methods

    /// Create a new configuration instance for this instrument
    ///
    /// Each instrument instance has its own configuration (for customization)
    func createConfiguration() -> any InstrumentConfiguration

    /// Create a new renderer instance for this instrument
    ///
    /// Renderers should be lightweight and stateless
    func createRenderer() -> any InstrumentRenderer
}

// MARK: - Default Implementations

public extension InstrumentPlugin {
    /// Default minimum size is 50x50 points
    static var minimumSize: CGSize {
        CGSize(width: 50, height: 50)
    }
}

// MARK: - Plugin Metadata

/// Metadata that identifies and describes a plugin
public struct PluginMetadata: Sendable, Equatable, Hashable {
    /// Unique identifier for the plugin (reverse DNS notation recommended)
    public let id: String

    /// Human-readable name
    public let name: String

    /// Brief description of what the plugin does
    public let description: String

    /// Version string (semantic versioning recommended)
    public let version: String

    /// Optional category for grouping plugins
    public let category: PluginCategory

    /// Optional icon/symbol name (SF Symbol name)
    public let iconName: String?

    public init(
        id: String,
        name: String,
        description: String,
        version: String,
        category: PluginCategory = .gauge,
        iconName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.version = version
        self.category = category
        self.iconName = iconName
    }
}

// MARK: - Plugin Category

/// Categories for organizing plugins in the UI
public enum PluginCategory: String, Sendable, CaseIterable {
    case gauge          // Speed, altitude, G-force, etc.
    case indicator      // Vertical speed, heading, compass
    case map            // Minimap, trackline
    case information    // Timestamp, distance, statistics
    case visual         // Trail effects, overlays
}

// MARK: - Telemetry Data Type

/// Types of telemetry data that plugins can depend on
public enum TelemetryDataType: String, Sendable, CaseIterable {
    case coordinate         // Latitude/longitude
    case elevation          // Altitude above sea level
    case speed              // Ground speed
    case verticalSpeed      // Rate of climb/descent
    case heading            // Course/direction
    case timestamp          // Time information
    case gForce             // Acceleration forces
    case distance           // Distance metrics
    case accuracy           // GPS accuracy information
}
