// CanvasViewModel.swift
// View model managing the state of the overlay canvas

import Foundation
import SwiftUI
import CoreGraphics
import FlightTraceCore
import FlightTracePlugins

/// View model for the overlay canvas
///
/// Manages:
/// - The list of instrument instances on the canvas
/// - The timeline engine for data synchronization
/// - Selection state and manipulation
/// - Canvas size and background properties
@MainActor
@Observable
public final class CanvasViewModel {

    // MARK: - Canvas Properties

    /// Canvas size (in points)
    public var canvasSize: CGSize

    /// Canvas background color
    public var backgroundColor: Color = Color.black.opacity(0.3)

    /// Whether to show safe area guides
    public var showSafeAreaGuides: Bool = false

    /// Whether to enable snapping
    public var snapEnabled: Bool = true

    /// Whether resize mode is active (shows handles, disables drag)
    public var resizeMode: Bool = false

    /// Selected aspect ratio overlay
    public var selectedAspectRatio: AspectRatioOverlayView.AspectRatio?

    /// Active snap guides (updated during drag operations)
    public var activeSnapGuides: [SnapGuideEngine.SnapGuide] = []

    /// Optional video background URL (for preview and export)
    public var videoBackgroundURL: URL?

    // MARK: - Snap Guide Engine

    /// Snap guide engine for detecting alignment points
    private let snapGuideEngine = SnapGuideEngine()

    // MARK: - Instrument Management

    /// All instrument instances on the canvas (ordered by Z-order)
    public var instruments: [InstrumentInstance] = []

    /// Currently selected instrument ID
    public var selectedInstrumentID: UUID?

    // MARK: - Timeline Integration

    /// The timeline engine for data synchronization
    public private(set) var timelineEngine: TimelineEngine

    /// Data provider for plugins
    public private(set) var dataProvider: TelemetryDataProvider

    // MARK: - Plugin Host

    /// Plugin host for accessing instrument plugins
    private let pluginHost: PluginHost

    // MARK: - Computed Properties

    /// Instruments sorted by Z-order (for rendering)
    public var sortedInstruments: [InstrumentInstance] {
        instruments.sorted { $0.zOrder < $1.zOrder }
    }

    /// Currently selected instrument
    public var selectedInstrument: InstrumentInstance? {
        get {
            guard let id = selectedInstrumentID else { return nil }
            return instruments.first { $0.id == id }
        }
    }

    // MARK: - Plugin Access

    /// Get a plugin by ID
    /// - Parameter pluginID: The plugin identifier
    /// - Returns: The plugin if found, nil otherwise
    public func plugin(withID pluginID: String) -> (any InstrumentPlugin)? {
        pluginHost.plugin(withID: pluginID)
    }

    // MARK: - Initialization

    public init(
        canvasSize: CGSize = CGSize(width: 1920, height: 1080),
        timelineEngine: TimelineEngine = TimelineEngine(),
        pluginHost: PluginHost = .shared
    ) {
        self.canvasSize = canvasSize
        self.timelineEngine = timelineEngine
        self.dataProvider = timelineEngine.asDataProvider()
        self.pluginHost = pluginHost
    }

    // MARK: - Instrument Management

    /// Add a new instrument to the canvas
    /// - Parameters:
    ///   - pluginID: The plugin ID
    ///   - position: Initial position (defaults to center)
    ///   - configuration: Optional initial configuration
    /// - Returns: The created instrument instance
    @discardableResult
    public func addInstrument(
        pluginID: String,
        at position: CGPoint? = nil,
        configuration: (any InstrumentConfiguration)? = nil
    ) -> InstrumentInstance? {
        guard let plugin = pluginHost.plugin(withID: pluginID) else {
            print("Warning: Plugin not found: \(pluginID)")
            return nil
        }

        // Get default size from plugin metadata
        let pluginType = type(of: plugin)
        let defaultSize = pluginType.defaultSize

        // Use provided position or center of canvas
        let instrumentPosition = position ?? CGPoint(
            x: (canvasSize.width - defaultSize.width) / 2,
            y: (canvasSize.height - defaultSize.height) / 2
        )

        // Serialize configuration if provided
        var configData: Data?
        if let config = configuration {
            configData = try? config.encode()
        } else {
            // Use default configuration
            let defaultConfig = plugin.createConfiguration()
            configData = try? defaultConfig.encode()
        }

        // Determine next Z-order
        let maxZOrder = instruments.map(\.zOrder).max() ?? 0

        // Create instrument instance
        let instance = InstrumentInstance(
            pluginID: pluginID,
            name: pluginType.metadata.name,
            position: instrumentPosition,
            size: defaultSize,
            zOrder: maxZOrder + 1,
            configurationData: configData
        )

        instruments.append(instance)
        return instance
    }

    /// Remove an instrument from the canvas
    /// - Parameter id: The instrument ID
    public func removeInstrument(id: UUID) {
        instruments.removeAll { $0.id == id }

        // Clear selection if removed instrument was selected
        if selectedInstrumentID == id {
            selectedInstrumentID = nil
        }
    }

    /// Update an instrument instance
    /// - Parameters:
    ///   - id: The instrument ID
    ///   - transform: Closure to modify the instrument
    public func updateInstrument(id: UUID, transform: (inout InstrumentInstance) -> Void) {
        guard let index = instruments.firstIndex(where: { $0.id == id }) else {
            return
        }

        transform(&instruments[index])
    }

    /// Clear all instruments from the canvas
    public func clearInstruments() {
        instruments.removeAll()
        selectedInstrumentID = nil
    }

    /// Update an instrument's configuration property
    /// - Parameters:
    ///   - instrumentID: The instrument ID
    ///   - pluginID: The plugin ID
    ///   - propertyKey: The property key to update
    ///   - propertyValue: The new property value
    public func updateInstrumentConfigurationProperty(
        instrumentID: UUID,
        pluginID: String,
        propertyKey: String,
        propertyValue: Any
    ) {
        guard let plugin = pluginHost.plugin(withID: pluginID) else {
            print("Warning: Plugin not found: \(pluginID)")
            return
        }

        print("🔍 CanvasViewModel: Configuration property update requested: \(propertyKey) = \(propertyValue)")

        updateInstrument(id: instrumentID) { instrument in
            // Get the current configuration (decode from data or create default)
            var currentConfig: any InstrumentConfiguration
            if let configData = instrument.configurationData {
                let configType = type(of: plugin.createConfiguration())
                if let decoded = try? configType.decode(from: configData) {
                    currentConfig = decoded
                    print("🔍 CanvasViewModel: Decoded existing configuration")
                } else {
                    currentConfig = plugin.createConfiguration()
                    print("🔍 CanvasViewModel: Failed to decode, using default configuration")
                }
            } else {
                currentConfig = plugin.createConfiguration()
                print("🔍 CanvasViewModel: No existing configuration, using default")
            }

            // Update the property
            if let updatedConfig = currentConfig.updatingProperty(key: propertyKey, value: propertyValue) {
                print("🔍 CanvasViewModel: Configuration updated successfully")

                // Encode the updated configuration back to data
                if let encodedData = try? updatedConfig.encode() {
                    instrument.configurationData = encodedData
                    print("🔍 CanvasViewModel: Configuration data saved to instrument")
                } else {
                    print("🔍 CanvasViewModel: ERROR - Failed to encode updated configuration")
                }
            } else {
                print("🔍 CanvasViewModel: ERROR - Failed to update property '\(propertyKey)'")
            }
        }
    }

    /// Update a configuration property using the configuration's updatingProperty method
    private func updateConfigurationProperty(
        config: any InstrumentConfiguration,
        key: String,
        value: Any
    ) -> any InstrumentConfiguration {
        // Use the configuration's own update method
        if let updated = config.updatingProperty(key: key, value: value) {
            return updated
        }

        // If update failed, return original
        print("Warning: Failed to update property '\(key)' - property not found or invalid value")
        return config
    }

    // MARK: - Selection Management

    /// Select an instrument
    /// - Parameter id: The instrument ID to select
    public func selectInstrument(id: UUID) {
        selectedInstrumentID = id
    }

    /// Deselect the current instrument
    public func deselectInstrument() {
        selectedInstrumentID = nil
    }

    /// Find instrument at a specific point
    /// - Parameter point: The point to test
    /// - Returns: The topmost instrument at that point, or nil
    public func instrumentAt(point: CGPoint) -> InstrumentInstance? {
        // Check instruments in reverse Z-order (topmost first)
        return sortedInstruments.reversed().first { instrument in
            instrument.isVisible && instrument.contains(point: point)
        }
    }

    // MARK: - Z-Order Management

    /// Bring an instrument forward
    /// - Parameter id: The instrument ID
    public func bringForward(id: UUID) {
        guard let index = instruments.firstIndex(where: { $0.id == id }) else {
            return
        }

        let currentZOrder = instruments[index].zOrder

        // Find the instrument directly above this one
        let instrumentsAbove = instruments.filter { $0.zOrder > currentZOrder }
        guard let nextZOrder = instrumentsAbove.map(\.zOrder).min() else {
            return // Already at top
        }

        // Swap Z-orders
        if let swapIndex = instruments.firstIndex(where: { $0.zOrder == nextZOrder }) {
            instruments[swapIndex].zOrder = currentZOrder
            instruments[index].zOrder = nextZOrder
        }
    }

    /// Send an instrument backward
    /// - Parameter id: The instrument ID
    public func sendBackward(id: UUID) {
        guard let index = instruments.firstIndex(where: { $0.id == id }) else {
            return
        }

        let currentZOrder = instruments[index].zOrder

        // Find the instrument directly below this one
        let instrumentsBelow = instruments.filter { $0.zOrder < currentZOrder }
        guard let prevZOrder = instrumentsBelow.map(\.zOrder).max() else {
            return // Already at bottom
        }

        // Swap Z-orders
        if let swapIndex = instruments.firstIndex(where: { $0.zOrder == prevZOrder }) {
            instruments[swapIndex].zOrder = currentZOrder
            instruments[index].zOrder = prevZOrder
        }
    }

    /// Bring an instrument to the front
    /// - Parameter id: The instrument ID
    public func bringToFront(id: UUID) {
        guard let index = instruments.firstIndex(where: { $0.id == id }) else {
            return
        }

        let maxZOrder = instruments.map(\.zOrder).max() ?? 0
        instruments[index].zOrder = maxZOrder + 1
    }

    /// Send an instrument to the back
    /// - Parameter id: The instrument ID
    public func sendToBack(id: UUID) {
        guard let index = instruments.firstIndex(where: { $0.id == id }) else {
            return
        }

        let minZOrder = instruments.map(\.zOrder).min() ?? 0
        instruments[index].zOrder = minZOrder - 1
    }

    // MARK: - Snap Guide Support

    /// Calculate snap position for an instrument
    /// - Parameters:
    ///   - id: Instrument ID
    ///   - desiredPosition: Desired position
    /// - Returns: Snapped position and active guides
    public func calculateSnapPosition(
        for id: UUID,
        desiredPosition: CGPoint
    ) -> (position: CGPoint, guides: [SnapGuideEngine.SnapGuide]) {
        guard snapEnabled,
              let instrument = instruments.first(where: { $0.id == id }) else {
            return (desiredPosition, [])
        }

        // Get other instruments for alignment
        let otherInstruments = instruments
            .filter { $0.id != id && $0.isVisible }
            .map { (position: $0.position, size: $0.size) }

        let result = snapGuideEngine.calculateSnap(
            position: desiredPosition,
            size: instrument.size,
            canvasSize: canvasSize,
            otherInstruments: otherInstruments
        )

        return (result.snappedPosition, result.activeGuides)
    }

    /// Update active snap guides
    /// - Parameter guides: New snap guides to display
    public func updateSnapGuides(_ guides: [SnapGuideEngine.SnapGuide]) {
        activeSnapGuides = guides
    }

    /// Clear active snap guides
    public func clearSnapGuides() {
        activeSnapGuides = []
    }

    // MARK: - Resize and Rotation

    /// Resize an instrument
    /// - Parameters:
    ///   - id: Instrument ID
    ///   - newSize: New size
    ///   - handle: Resize handle used (affects position)
    public func resizeInstrument(
        id: UUID,
        to newSize: CGSize,
        fromHandle handle: SelectionHandlesView.ResizeHandle
    ) {
        guard let index = instruments.firstIndex(where: { $0.id == id }) else {
            return
        }

        let oldSize = instruments[index].size
        let oldPosition = instruments[index].position

        // Adjust position based on which handle was dragged
        var newPosition = oldPosition

        switch handle {
        case .topLeft:
            newPosition.x = oldPosition.x + (oldSize.width - newSize.width)
            newPosition.y = oldPosition.y + (oldSize.height - newSize.height)

        case .topRight:
            newPosition.y = oldPosition.y + (oldSize.height - newSize.height)

        case .bottomLeft:
            newPosition.x = oldPosition.x + (oldSize.width - newSize.width)

        case .bottomRight:
            // Position stays the same
            break

        case .top:
            newPosition.y = oldPosition.y + (oldSize.height - newSize.height)

        case .bottom:
            // Position stays the same
            break

        case .left:
            newPosition.x = oldPosition.x + (oldSize.width - newSize.width)

        case .right:
            // Position stays the same
            break
        }

        instruments[index].size = newSize
        instruments[index].position = newPosition
    }

    /// Rotate an instrument
    /// - Parameters:
    ///   - id: Instrument ID
    ///   - angle: Rotation angle in degrees
    public func rotateInstrument(id: UUID, by angle: Double) {
        guard let index = instruments.firstIndex(where: { $0.id == id }) else {
            return
        }

        instruments[index].rotation += angle
    }

    /// Set absolute rotation for an instrument
    /// - Parameters:
    ///   - id: Instrument ID
    ///   - angle: Absolute rotation angle in degrees
    public func setRotation(id: UUID, to angle: Double) {
        guard let index = instruments.firstIndex(where: { $0.id == id }) else {
            return
        }

        instruments[index].rotation = angle
    }

    // MARK: - Timeline Control

    /// Load a telemetry track
    /// - Parameter track: The track to load
    public func loadTrack(_ track: TelemetryTrack) {
        timelineEngine.loadTrack(track)

        // Automatically seek to a position with data
        // If there's a track duration, seek to 1 second in to ensure we're past the start
        if let duration = track.duration, duration > 0 {
            let seekPosition = min(1.0, duration * 0.1)
            timelineEngine.seek(to: seekPosition)
        }
    }

    /// Clear the current track
    public func clearTrack() {
        timelineEngine.clearTrack()
    }

    // MARK: - Canvas Configuration

    /// Update canvas size
    /// - Parameter size: New canvas size
    public func updateCanvasSize(_ size: CGSize) {
        canvasSize = size
    }

    // MARK: - Serialization

    /// Export the current canvas layout
    /// - Returns: Serialized canvas layout data
    public func exportLayout() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let layout = CanvasLayout(
            canvasSize: canvasSize,
            instruments: instruments
        )

        return try encoder.encode(layout)
    }

    /// Import a canvas layout
    /// - Parameter data: Serialized canvas layout data
    public func importLayout(from data: Data) throws {
        let decoder = JSONDecoder()
        let layout = try decoder.decode(CanvasLayout.self, from: data)

        canvasSize = layout.canvasSize
        instruments = layout.instruments
        selectedInstrumentID = nil
    }
}

// MARK: - Canvas Layout

/// Serializable representation of a canvas layout
private struct CanvasLayout: Codable {
    let canvasSize: CGSize
    let instruments: [InstrumentInstance]

    enum CodingKeys: String, CodingKey {
        case canvasSize, instruments
    }

    init(canvasSize: CGSize, instruments: [InstrumentInstance]) {
        self.canvasSize = canvasSize
        self.instruments = instruments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode CGSize
        let sizeArray = try container.decode([CGFloat].self, forKey: .canvasSize)
        canvasSize = CGSize(width: sizeArray[0], height: sizeArray[1])

        instruments = try container.decode([InstrumentInstance].self, forKey: .instruments)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode([canvasSize.width, canvasSize.height], forKey: .canvasSize)
        try container.encode(instruments, forKey: .instruments)
    }
}
