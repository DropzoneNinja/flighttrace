// InstrumentInstance.swift
// Represents a single instrument placed on the overlay canvas

import Foundation
import CoreGraphics
import FlightTraceCore
import FlightTracePlugins

/// Represents a single instrument instance placed on the overlay canvas
///
/// Each instrument instance has:
/// - A position and size on the canvas
/// - A reference to the plugin that renders it
/// - A configuration instance with customized settings
/// - Z-order for layering
public struct InstrumentInstance: Identifiable, Sendable {

    // MARK: - Identity

    /// Unique identifier for this instrument instance
    public let id: UUID

    // MARK: - Plugin Reference

    /// The plugin ID (e.g., "com.flighttrace.speed-gauge")
    public let pluginID: String

    /// Human-readable name for this instance (defaults to plugin name)
    public var name: String

    // MARK: - Position and Size

    /// Position on the canvas (in points, origin at top-left)
    public var position: CGPoint

    /// Size of the instrument (in points)
    public var size: CGSize

    /// Rotation angle in degrees (0 = no rotation)
    public var rotation: Double

    // MARK: - Layer Order

    /// Z-order for layering (higher values render on top)
    public var zOrder: Int

    // MARK: - Visibility

    /// Whether this instrument is currently visible
    public var isVisible: Bool

    // MARK: - Configuration

    /// Serialized configuration data
    ///
    /// Configuration is stored as Data to maintain Sendable conformance.
    /// The actual configuration object is created by the plugin when rendering.
    public var configurationData: Data?

    // MARK: - Computed Properties

    /// The bounds of this instrument on the canvas
    public var bounds: CGRect {
        CGRect(origin: position, size: size)
    }

    /// The center point of this instrument
    public var center: CGPoint {
        CGPoint(
            x: position.x + size.width / 2,
            y: position.y + size.height / 2
        )
    }

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        pluginID: String,
        name: String,
        position: CGPoint = .zero,
        size: CGSize,
        rotation: Double = 0,
        zOrder: Int = 0,
        isVisible: Bool = true,
        configurationData: Data? = nil
    ) {
        self.id = id
        self.pluginID = pluginID
        self.name = name
        self.position = position
        self.size = size
        self.rotation = rotation
        self.zOrder = zOrder
        self.isVisible = isVisible
        self.configurationData = configurationData
    }

    // MARK: - Mutation Methods

    /// Move the instrument to a new position
    public mutating func move(to newPosition: CGPoint) {
        position = newPosition
    }

    /// Resize the instrument to a new size
    public mutating func resize(to newSize: CGSize) {
        size = newSize
    }

    /// Rotate the instrument to a new angle
    public mutating func rotate(to angle: Double) {
        rotation = angle
    }

    /// Update the Z-order
    public mutating func setZOrder(_ order: Int) {
        zOrder = order
    }

    /// Toggle visibility
    public mutating func toggleVisibility() {
        isVisible.toggle()
    }

    // MARK: - Hit Testing

    /// Check if a point intersects with this instrument's bounds
    public func contains(point: CGPoint) -> Bool {
        bounds.contains(point)
    }
}

// MARK: - Codable Conformance

extension InstrumentInstance: Codable {
    enum CodingKeys: String, CodingKey {
        case id, pluginID, name, position, size, rotation, zOrder, isVisible, configurationData
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        pluginID = try container.decode(String.self, forKey: .pluginID)
        name = try container.decode(String.self, forKey: .name)

        // Decode CGPoint
        let positionArray = try container.decode([CGFloat].self, forKey: .position)
        position = CGPoint(x: positionArray[0], y: positionArray[1])

        // Decode CGSize
        let sizeArray = try container.decode([CGFloat].self, forKey: .size)
        size = CGSize(width: sizeArray[0], height: sizeArray[1])

        rotation = try container.decode(Double.self, forKey: .rotation)
        zOrder = try container.decode(Int.self, forKey: .zOrder)
        isVisible = try container.decode(Bool.self, forKey: .isVisible)
        configurationData = try container.decodeIfPresent(Data.self, forKey: .configurationData)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(pluginID, forKey: .pluginID)
        try container.encode(name, forKey: .name)
        try container.encode([position.x, position.y], forKey: .position)
        try container.encode([size.width, size.height], forKey: .size)
        try container.encode(rotation, forKey: .rotation)
        try container.encode(zOrder, forKey: .zOrder)
        try container.encode(isVisible, forKey: .isVisible)
        try container.encodeIfPresent(configurationData, forKey: .configurationData)
    }
}
