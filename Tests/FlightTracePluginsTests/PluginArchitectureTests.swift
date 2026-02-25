// PluginArchitectureTests.swift
// Unit tests for the plugin architecture

import XCTest
import CoreGraphics
import CoreLocation
@testable import FlightTracePlugins
@testable import FlightTraceCore

// MARK: - Mock Plugin

/// Mock plugin for testing
struct MockSpeedPlugin: InstrumentPlugin {
    static let metadata = PluginMetadata(
        id: "com.test.mock-speed",
        name: "Mock Speed Gauge",
        description: "A test speed gauge",
        version: "1.0.0",
        category: .gauge
    )

    static let dataDependencies: Set<TelemetryDataType> = [.speed, .timestamp]
    static let defaultSize = CGSize(width: 200, height: 100)

    func createConfiguration() -> any InstrumentConfiguration {
        MockSpeedConfiguration()
    }

    func createRenderer() -> any InstrumentRenderer {
        MockSpeedRenderer()
    }
}

/// Mock configuration
struct MockSpeedConfiguration: InstrumentConfiguration, Codable {
    var id = UUID()
    var units: String = "mph"
    var textColor: SerializableColor = .white

    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    static func decode(from data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }

    func properties() -> [ConfigurationProperty] {
        [
            .string(key: "units", value: units, label: "Units"),
            .color(key: "textColor", value: textColor, label: "Text Color")
        ]
    }
}

/// Mock renderer
struct MockSpeedRenderer: InstrumentRenderer {
    func render(
        context: CGContext,
        renderContext: RenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        // Simple test rendering
        context.setFillColor(.black)
        context.fill(renderContext.bounds)
    }
}

// MARK: - Another Mock Plugin

struct MockAltitudePlugin: InstrumentPlugin {
    static let metadata = PluginMetadata(
        id: "com.test.mock-altitude",
        name: "Mock Altitude Gauge",
        description: "A test altitude gauge",
        version: "1.0.0",
        category: .gauge
    )

    static let dataDependencies: Set<TelemetryDataType> = [.elevation, .timestamp]
    static let defaultSize = CGSize(width: 150, height: 150)

    func createConfiguration() -> any InstrumentConfiguration {
        MockAltitudeConfiguration()
    }

    func createRenderer() -> any InstrumentRenderer {
        MockSpeedRenderer()
    }
}

struct MockAltitudeConfiguration: InstrumentConfiguration, Codable {
    var id = UUID()

    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    static func decode(from data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }

    func properties() -> [ConfigurationProperty] {
        []
    }
}

// MARK: - Mock Data Provider

class MockDataProvider: TelemetryDataProvider {
    var currentPointValue: TelemetryPoint?
    var trackValue: TelemetryTrack?

    init(currentPoint: TelemetryPoint? = nil, track: TelemetryTrack? = nil) {
        self.currentPointValue = currentPoint
        self.trackValue = track
    }

    func currentPoint() -> TelemetryPoint? {
        currentPointValue
    }

    func point(at timestamp: Date) -> TelemetryPoint? {
        currentPointValue
    }

    func points(from startTime: Date, to endTime: Date) -> [TelemetryPoint] {
        guard let point = currentPointValue else { return [] }
        return [point]
    }

    func lastPoints(_ count: Int) -> [TelemetryPoint] {
        guard let point = currentPointValue else { return [] }
        return [point]
    }

    func track() -> TelemetryTrack? {
        trackValue
    }

    func trackStatistics() -> TrackStatistics? {
        guard let track = trackValue else { return nil }
        return TrackStatistics(from: track)
    }
}

// MARK: - Tests

@MainActor
final class PluginArchitectureTests: XCTestCase {

    override func setUp() async throws {
        // Clean plugin registry before each test
        PluginHost.shared.unregisterAll()
    }

    // MARK: - Plugin Registration Tests

    func testPluginRegistration() throws {
        // Test registering a single plugin
        try PluginHost.shared.register(MockSpeedPlugin.self)

        let plugins = PluginHost.shared.availablePlugins()
        XCTAssertEqual(plugins.count, 1)
        XCTAssertEqual(plugins.first?.id, "com.test.mock-speed")
        XCTAssertEqual(plugins.first?.name, "Mock Speed Gauge")
    }

    func testMultiplePluginRegistration() throws {
        // Test registering multiple plugins at once
        try PluginHost.shared.register([
            MockSpeedPlugin.self,
            MockAltitudePlugin.self
        ])

        let plugins = PluginHost.shared.availablePlugins()
        XCTAssertEqual(plugins.count, 2)

        let ids = Set(plugins.map { $0.id })
        XCTAssertTrue(ids.contains("com.test.mock-speed"))
        XCTAssertTrue(ids.contains("com.test.mock-altitude"))
    }

    func testDuplicateRegistrationThrows() throws {
        try PluginHost.shared.register(MockSpeedPlugin.self)

        // Attempting to register the same plugin again should throw
        XCTAssertThrowsError(try PluginHost.shared.register(MockSpeedPlugin.self)) { error in
            guard case PluginError.duplicateID(let id) = error else {
                XCTFail("Expected PluginError.duplicateID, got \(error)")
                return
            }
            XCTAssertEqual(id, "com.test.mock-speed")
        }
    }

    func testPluginUnregistration() throws {
        try PluginHost.shared.register(MockSpeedPlugin.self)
        XCTAssertEqual(PluginHost.shared.availablePlugins().count, 1)

        PluginHost.shared.unregister(id: "com.test.mock-speed")
        XCTAssertEqual(PluginHost.shared.availablePlugins().count, 0)
    }

    // MARK: - Plugin Discovery Tests

    func testPluginDiscoveryByID() throws {
        try PluginHost.shared.register(MockSpeedPlugin.self)

        let plugin = PluginHost.shared.plugin(id: "com.test.mock-speed")
        XCTAssertNotNil(plugin)
        XCTAssertEqual(plugin?.name, "Mock Speed Gauge")

        let notFound = PluginHost.shared.plugin(id: "com.test.nonexistent")
        XCTAssertNil(notFound)
    }

    func testPluginDiscoveryByCategory() throws {
        try PluginHost.shared.register([
            MockSpeedPlugin.self,
            MockAltitudePlugin.self
        ])

        let gauges = PluginHost.shared.plugins(in: .gauge)
        XCTAssertEqual(gauges.count, 2)

        let maps = PluginHost.shared.plugins(in: .map)
        XCTAssertEqual(maps.count, 0)
    }

    func testPluginTypeRetrieval() throws {
        try PluginHost.shared.register(MockSpeedPlugin.self)

        let pluginType = PluginHost.shared.pluginType(id: "com.test.mock-speed")
        XCTAssertNotNil(pluginType)
        XCTAssertEqual(pluginType?.metadata.id, "com.test.mock-speed")
    }

    // MARK: - Plugin Instantiation Tests

    func testPluginInstantiation() throws {
        try PluginHost.shared.register(MockSpeedPlugin.self)

        let instance = PluginHost.shared.createInstance(id: "com.test.mock-speed")
        XCTAssertNotNil(instance)

        // Verify we can create configuration and renderer
        let config = instance?.createConfiguration()
        XCTAssertNotNil(config)

        let renderer = instance?.createRenderer()
        XCTAssertNotNil(renderer)
    }

    func testMultipleInstances() throws {
        try PluginHost.shared.register(MockSpeedPlugin.self)

        // Create multiple instances of the same plugin
        let instance1 = PluginHost.shared.createInstance(id: "com.test.mock-speed")
        let instance2 = PluginHost.shared.createInstance(id: "com.test.mock-speed")

        XCTAssertNotNil(instance1)
        XCTAssertNotNil(instance2)

        // Each should have its own configuration
        let config1 = instance1?.createConfiguration()
        let config2 = instance2?.createConfiguration()
        XCTAssertNotEqual(config1?.id, config2?.id)
    }

    // MARK: - Plugin Validation Tests

    func testPluginValidationWithAllData() throws {
        try PluginHost.shared.register(MockSpeedPlugin.self)

        let availableData: Set<TelemetryDataType> = [.speed, .timestamp, .elevation]
        let result = PluginHost.shared.validate(
            pluginID: "com.test.mock-speed",
            withAvailableData: availableData
        )

        XCTAssertEqual(result, .valid)
        XCTAssertTrue(result.isValid)
    }

    func testPluginValidationWithMissingData() throws {
        try PluginHost.shared.register(MockSpeedPlugin.self)

        let availableData: Set<TelemetryDataType> = [.elevation]  // Missing .speed and .timestamp
        let result = PluginHost.shared.validate(
            pluginID: "com.test.mock-speed",
            withAvailableData: availableData
        )

        guard case .missingData(let missing) = result else {
            XCTFail("Expected .missingData result")
            return
        }

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(missing.contains(.speed))
        XCTAssertTrue(missing.contains(.timestamp))
    }

    func testPluginValidationNotFound() throws {
        let result = PluginHost.shared.validate(
            pluginID: "com.test.nonexistent",
            withAvailableData: []
        )

        XCTAssertEqual(result, .notFound)
        XCTAssertFalse(result.isValid)
    }

    func testCompatiblePlugins() throws {
        try PluginHost.shared.register([
            MockSpeedPlugin.self,      // Requires: .speed, .timestamp
            MockAltitudePlugin.self    // Requires: .elevation, .timestamp
        ])

        let availableData: Set<TelemetryDataType> = [.speed, .timestamp]
        let compatible = PluginHost.shared.compatiblePlugins(withAvailableData: availableData)

        XCTAssertEqual(compatible.count, 1)
        XCTAssertEqual(compatible.first?.id, "com.test.mock-speed")
    }

    // MARK: - Configuration Tests

    func testConfigurationSerialization() throws {
        var config = MockSpeedConfiguration()
        config.units = "kph"
        config.textColor = .red

        let data = try config.encode()
        XCTAssertFalse(data.isEmpty)

        let decoded = try MockSpeedConfiguration.decode(from: data)
        XCTAssertEqual(decoded.units, "kph")
        XCTAssertEqual(decoded.textColor, .red)
        XCTAssertEqual(decoded.id, config.id)
    }

    func testConfigurationProperties() {
        let config = MockSpeedConfiguration()
        let properties = config.properties()

        XCTAssertEqual(properties.count, 2)
        XCTAssertEqual(properties[0].key, "units")
        XCTAssertEqual(properties[1].key, "textColor")
    }

    // MARK: - RenderContext Tests

    func testRenderContextCreation() {
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 100)
        let time = Date()

        let context = RenderContext(
            bounds: bounds,
            scale: 2.0,
            currentTime: time,
            isPreview: true,
            frameRate: 60.0
        )

        XCTAssertEqual(context.bounds, bounds)
        XCTAssertEqual(context.scale, 2.0)
        XCTAssertEqual(context.currentTime, time)
        XCTAssertTrue(context.isPreview)
        XCTAssertEqual(context.frameRate, 60.0)
        XCTAssertNil(context.frameNumber)
    }

    func testRenderContextWithFrameNumber() {
        let context = RenderContext(
            bounds: .zero,
            currentTime: Date(),
            isPreview: false,
            frameNumber: 42
        )

        XCTAssertFalse(context.isPreview)
        XCTAssertEqual(context.frameNumber, 42)
    }

    // MARK: - SerializableColor Tests

    func testSerializableColorCreation() {
        let color = SerializableColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.8)

        XCTAssertEqual(color.red, 1.0)
        XCTAssertEqual(color.green, 0.5)
        XCTAssertEqual(color.blue, 0.0)
        XCTAssertEqual(color.alpha, 0.8)
    }

    func testSerializableColorPresets() {
        XCTAssertEqual(SerializableColor.white.red, 1.0)
        XCTAssertEqual(SerializableColor.white.green, 1.0)
        XCTAssertEqual(SerializableColor.white.blue, 1.0)

        XCTAssertEqual(SerializableColor.black.red, 0.0)
        XCTAssertEqual(SerializableColor.black.green, 0.0)
        XCTAssertEqual(SerializableColor.black.blue, 0.0)

        XCTAssertEqual(SerializableColor.clear.alpha, 0.0)
    }

    func testSerializableColorWithAlpha() {
        let original = SerializableColor.red
        let transparent = original.withAlpha(0.5)

        XCTAssertEqual(transparent.red, 1.0)
        XCTAssertEqual(transparent.alpha, 0.5)
    }

    func testSerializableColorSerialization() throws {
        let color = SerializableColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)

        let data = try JSONEncoder().encode(color)
        let decoded = try JSONDecoder().decode(SerializableColor.self, from: data)

        XCTAssertEqual(decoded.red, color.red, accuracy: 0.001)
        XCTAssertEqual(decoded.green, color.green, accuracy: 0.001)
        XCTAssertEqual(decoded.blue, color.blue, accuracy: 0.001)
        XCTAssertEqual(decoded.alpha, color.alpha, accuracy: 0.001)
    }

    // MARK: - TelemetryDataProvider Tests

    func testMockDataProvider() {
        let point = TelemetryPoint(
            timestamp: Date(),
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            elevation: 100.0,
            speed: 25.0
        )

        let provider = MockDataProvider(currentPoint: point)

        XCTAssertNotNil(provider.currentPoint())
        XCTAssertEqual(provider.currentPoint()?.speed, 25.0)
        XCTAssertEqual(provider.currentPoint()?.elevation, 100.0)

        let points = provider.lastPoints(10)
        XCTAssertEqual(points.count, 1)
    }

    func testMockDataProviderWithTrack() {
        let point = TelemetryPoint(
            timestamp: Date(),
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            elevation: 100.0,
            speed: 25.0
        )

        let track = TelemetryTrack(
            name: "Test Track",
            points: [point]
        )

        let provider = MockDataProvider(track: track)

        XCTAssertNotNil(provider.track())
        XCTAssertEqual(provider.track()?.name, "Test Track")
        XCTAssertEqual(provider.track()?.points.count, 1)

        let stats = provider.trackStatistics()
        XCTAssertNotNil(stats)
    }

    // MARK: - Integration Tests

    func testFullPluginLifecycle() throws {
        // 1. Register plugin
        try PluginHost.shared.register(MockSpeedPlugin.self)

        // 2. Discover plugin
        let metadata = PluginHost.shared.plugin(id: "com.test.mock-speed")
        XCTAssertNotNil(metadata)

        // 3. Validate plugin
        let availableData: Set<TelemetryDataType> = [.speed, .timestamp, .elevation]
        let validation = PluginHost.shared.validate(
            pluginID: "com.test.mock-speed",
            withAvailableData: availableData
        )
        XCTAssertTrue(validation.isValid)

        // 4. Create instance
        guard let instance = PluginHost.shared.createInstance(id: "com.test.mock-speed") else {
            XCTFail("Failed to create plugin instance")
            return
        }

        // 5. Create configuration
        let config = instance.createConfiguration()
        XCTAssertNotNil(config)

        // 6. Serialize configuration
        let configData = try config.encode()
        XCTAssertFalse(configData.isEmpty)

        // 7. Create renderer
        let renderer = instance.createRenderer()
        XCTAssertNotNil(renderer)

        // 8. Render (basic test)
        let point = TelemetryPoint(
            timestamp: Date(),
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            speed: 50.0
        )
        let dataProvider = MockDataProvider(currentPoint: point)

        // Create a bitmap context for testing
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 200,
            height: 100,
            bitsPerComponent: 8,
            bytesPerRow: 800,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Failed to create CGContext")
            return
        }

        let renderContext = RenderContext(
            bounds: CGRect(x: 0, y: 0, width: 200, height: 100),
            currentTime: Date()
        )

        // Should not crash
        renderer.render(
            context: context,
            renderContext: renderContext,
            configuration: config,
            dataProvider: dataProvider
        )
    }
}
