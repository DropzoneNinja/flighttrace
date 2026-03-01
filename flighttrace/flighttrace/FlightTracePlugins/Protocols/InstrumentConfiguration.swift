// InstrumentConfiguration.swift
// Protocol for instrument configuration and customization

import Foundation
import CoreGraphics

#if canImport(AppKit)
import AppKit
typealias PlatformColor = NSColor
#elseif canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
#endif

/// Protocol for instrument configuration
///
/// Each instrument plugin provides a configuration type that exposes customizable properties.
/// Configurations must be serializable to support saving/loading overlay layouts.
///
/// ## Requirements
/// - All configuration must be declarative and serializable
/// - Configuration must be Sendable (thread-safe)
/// - Changes to configuration must be observable for real-time preview updates
/// - Configuration should provide sensible defaults
///
/// ## Example Implementation
/// ```swift
/// struct SpeedGaugeConfiguration: InstrumentConfiguration {
///     var id = UUID()
///     var units: SpeedUnit = .mph
///     var decimalPlaces: Int = 1
///     var textColor: SerializableColor = .white
///     var backgroundColor: SerializableColor = .black.withAlpha(0.7)
///     var fontSize: CGFloat = 48
///     var showLabel: Bool = true
///
///     func encode() throws -> Data {
///         try JSONEncoder().encode(self)
///     }
///
///     static func decode(from data: Data) throws -> Self {
///         try JSONDecoder().decode(Self.self, from: data)
///     }
///
///     func properties() -> [ConfigurationProperty] {
///         [
///             .enumeration("units", value: units, options: SpeedUnit.allCases),
///             .integer("decimalPlaces", value: decimalPlaces, range: 0...3),
///             .color("textColor", value: textColor),
///             .boolean("showLabel", value: showLabel)
///         ]
///     }
/// }
/// ```
public protocol InstrumentConfiguration: Identifiable where ID == UUID {

    /// Unique identifier for this configuration instance
    var id: UUID { get set }

    // MARK: - Serialization

    /// Encode the configuration to data
    /// - Returns: Serialized configuration data
    /// - Throws: Encoding errors
    func encode() throws -> Data

    /// Decode configuration from data
    /// - Parameter data: Serialized configuration data
    /// - Returns: Decoded configuration instance
    /// - Throws: Decoding errors
    static func decode(from data: Data) throws -> Self

    // MARK: - Property Introspection

    /// Return all configurable properties for UI generation
    ///
    /// This allows the inspector panel to automatically generate UI controls
    /// for configuration properties without hardcoding per-plugin UI.
    func properties() -> [ConfigurationProperty]

    // MARK: - Property Updates

    /// Update a property value by key
    /// - Parameters:
    ///   - key: The property key
    ///   - value: The new value
    /// - Returns: Updated configuration, or nil if property doesn't exist
    func updatingProperty(key: String, value: Any) -> Self?
}

// MARK: - Configuration Property

/// Represents a single configurable property with metadata
///
/// This enables automatic UI generation for configuration panels
public enum ConfigurationProperty: Sendable {
    /// Boolean toggle
    case boolean(key: String, value: Bool, label: String? = nil)

    /// Integer value with optional range
    case integer(key: String, value: Int, range: ClosedRange<Int>? = nil, label: String? = nil)

    /// Floating point value with optional range
    case double(key: String, value: Double, range: ClosedRange<Double>? = nil, label: String? = nil)

    /// Text string
    case string(key: String, value: String, label: String? = nil)

    /// Color picker
    case color(key: String, value: SerializableColor, label: String? = nil)

    /// Enumeration selection
    case enumeration(key: String, value: any Sendable & Equatable, options: [any Sendable & Equatable], label: String? = nil)

    /// Slider for numeric values
    case slider(key: String, value: Double, range: ClosedRange<Double>, step: Double? = nil, label: String? = nil)

    public var key: String {
        switch self {
        case .boolean(let key, _, _),
             .integer(let key, _, _, _),
             .double(let key, _, _, _),
             .string(let key, _, _),
             .color(let key, _, _),
             .enumeration(let key, _, _, _),
             .slider(let key, _, _, _, _):
            return key
        }
    }

    public var label: String {
        switch self {
        case .boolean(_, _, let label),
             .integer(_, _, _, let label),
             .double(_, _, _, let label),
             .string(_, _, let label),
             .color(_, _, let label),
             .enumeration(_, _, _, let label),
             .slider(_, _, _, _, let label):
            return label ?? key.capitalized
        }
    }
}

// MARK: - Serializable Color

/// Color type that can be serialized (for configuration persistence)
public struct SerializableColor: Sendable, Codable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    #if canImport(AppKit)
    public init(_ color: NSColor) {
        // Convert to RGB color space
        guard let rgb = color.usingColorSpace(.deviceRGB) else {
            self.red = 0
            self.green = 0
            self.blue = 0
            self.alpha = 1
            return
        }
        self.red = Double(rgb.redComponent)
        self.green = Double(rgb.greenComponent)
        self.blue = Double(rgb.blueComponent)
        self.alpha = Double(rgb.alphaComponent)
    }

    public var nsColor: NSColor {
        NSColor(
            red: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }
    #endif

    public var cgColor: CGColor {
        CGColor(
            red: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }

    public func withAlpha(_ alpha: Double) -> SerializableColor {
        SerializableColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    // Common colors
    public static let white = SerializableColor(red: 1, green: 1, blue: 1)
    public static let black = SerializableColor(red: 0, green: 0, blue: 0)
    public static let red = SerializableColor(red: 1, green: 0, blue: 0)
    public static let green = SerializableColor(red: 0, green: 1, blue: 0)
    public static let blue = SerializableColor(red: 0, green: 0, blue: 1)
    public static let yellow = SerializableColor(red: 1, green: 1, blue: 0)
    public static let clear = SerializableColor(red: 0, green: 0, blue: 0, alpha: 0)
}

#if canImport(SwiftUI)
import SwiftUI

extension SerializableColor {
    /// Initialize from SwiftUI Color
    public init(_ color: Color) {
        #if canImport(AppKit)
        self.init(NSColor(color))
        #elseif canImport(UIKit)
        self.init(UIColor(color))
        #endif
    }

    /// Convert to SwiftUI Color
    public var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}
#endif
