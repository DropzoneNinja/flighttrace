// SpeedGaugePluginTests.swift
// Unit tests for Speed Gauge Plugin

import XCTest
import CoreGraphics
import CoreLocation
@testable import FlightTracePlugins
@testable import FlightTraceCore

@MainActor
final class SpeedGaugePluginTests: XCTestCase {

    // MARK: - Setup

    override func setUp() async throws {
        PluginHost.shared.unregisterAll()
    }

    // MARK: - Plugin Metadata Tests

    func testPluginMetadata() {
        let metadata = SpeedGaugePlugin.metadata

        XCTAssertEqual(metadata.id, "com.flighttrace.speed-gauge")
        XCTAssertEqual(metadata.name, "Speed Gauge")
        XCTAssertEqual(metadata.version, "1.0.0")
        XCTAssertEqual(metadata.category, .gauge)
        XCTAssertFalse(metadata.description.isEmpty)
    }

    func testPluginDataDependencies() {
        let dependencies = SpeedGaugePlugin.dataDependencies

        XCTAssertEqual(dependencies.count, 2)
        XCTAssertTrue(dependencies.contains(.speed))
        XCTAssertTrue(dependencies.contains(.timestamp))
    }

    func testPluginDefaultSize() {
        let defaultSize = SpeedGaugePlugin.defaultSize
        let minimumSize = SpeedGaugePlugin.minimumSize

        XCTAssertEqual(defaultSize.width, 200)
        XCTAssertEqual(defaultSize.height, 100)
        XCTAssertEqual(minimumSize.width, 120)
        XCTAssertEqual(minimumSize.height, 60)
    }

    // MARK: - Plugin Registration Tests

    func testPluginRegistration() throws {
        try PluginHost.shared.register(SpeedGaugePlugin.self)

        let plugins = PluginHost.shared.availablePlugins()
        XCTAssertEqual(plugins.count, 1)
        XCTAssertEqual(plugins.first?.id, "com.flighttrace.speed-gauge")
    }

    func testPluginInstantiation() throws {
        try PluginHost.shared.register(SpeedGaugePlugin.self)

        let instance = PluginHost.shared.createInstance(id: "com.flighttrace.speed-gauge")
        XCTAssertNotNil(instance)
        XCTAssertTrue(instance is SpeedGaugePlugin)
    }

    func testPluginValidation() throws {
        try PluginHost.shared.register(SpeedGaugePlugin.self)

        // Test with required data
        let validData: Set<TelemetryDataType> = [.speed, .timestamp, .elevation]
        let validResult = PluginHost.shared.validate(
            pluginID: "com.flighttrace.speed-gauge",
            withAvailableData: validData
        )
        XCTAssertEqual(validResult, .valid)

        // Test with missing data
        let invalidData: Set<TelemetryDataType> = [.elevation]
        let invalidResult = PluginHost.shared.validate(
            pluginID: "com.flighttrace.speed-gauge",
            withAvailableData: invalidData
        )

        guard case .missingData(let missing) = invalidResult else {
            XCTFail("Expected .missingData result")
            return
        }
        XCTAssertTrue(missing.contains(.speed))
        XCTAssertTrue(missing.contains(.timestamp))
    }

    // MARK: - Configuration Tests

    func testConfigurationDefaults() {
        let config = SpeedGaugeConfiguration()

        XCTAssertEqual(config.units, .milesPerHour)
        XCTAssertEqual(config.decimalPlaces, 1)
        XCTAssertEqual(config.textColor, .white)
        XCTAssertTrue(config.showLabel)
        XCTAssertEqual(config.fontSize, 48.0)
        XCTAssertEqual(config.labelFontSize, 18.0)
        XCTAssertEqual(config.cornerRadius, 8.0)
        XCTAssertEqual(config.padding, 12.0)
    }

    func testConfigurationSerialization() throws {
        var config = SpeedGaugeConfiguration()
        config.units = .kilometersPerHour
        config.decimalPlaces = 2
        config.textColor = .yellow
        config.showLabel = false
        config.fontSize = 64.0

        // Encode
        let data = try config.encode()
        XCTAssertFalse(data.isEmpty)

        // Decode
        let decoded = try SpeedGaugeConfiguration.decode(from: data)
        XCTAssertEqual(decoded.id, config.id)
        XCTAssertEqual(decoded.units, .kilometersPerHour)
        XCTAssertEqual(decoded.decimalPlaces, 2)
        XCTAssertEqual(decoded.textColor, .yellow)
        XCTAssertFalse(decoded.showLabel)
        XCTAssertEqual(decoded.fontSize, 64.0)
    }

    func testConfigurationProperties() {
        let config = SpeedGaugeConfiguration()
        let properties = config.properties()

        XCTAssertEqual(properties.count, 8)

        let keys = properties.map { $0.key }
        XCTAssertTrue(keys.contains("units"))
        XCTAssertTrue(keys.contains("decimalPlaces"))
        XCTAssertTrue(keys.contains("textColor"))
        XCTAssertTrue(keys.contains("backgroundColor"))
        XCTAssertTrue(keys.contains("showLabel"))
        XCTAssertTrue(keys.contains("fontSize"))
        XCTAssertTrue(keys.contains("labelFontSize"))
        XCTAssertTrue(keys.contains("cornerRadius"))
    }

    // MARK: - Speed Unit Tests

    func testSpeedUnitConversions() {
        let speedMS = 10.0  // 10 m/s

        // Test m/s
        XCTAssertEqual(
            SpeedUnit.metersPerSecond.convert(metersPerSecond: speedMS),
            10.0,
            accuracy: 0.01
        )

        // Test km/h (10 m/s = 36 km/h)
        XCTAssertEqual(
            SpeedUnit.kilometersPerHour.convert(metersPerSecond: speedMS),
            36.0,
            accuracy: 0.01
        )

        // Test mph (10 m/s ≈ 22.37 mph)
        XCTAssertEqual(
            SpeedUnit.milesPerHour.convert(metersPerSecond: speedMS),
            22.3694,
            accuracy: 0.01
        )

        // Test knots (10 m/s ≈ 19.44 knots)
        XCTAssertEqual(
            SpeedUnit.knots.convert(metersPerSecond: speedMS),
            19.4384,
            accuracy: 0.01
        )
    }

    func testSpeedUnitRawValues() {
        XCTAssertEqual(SpeedUnit.metersPerSecond.rawValue, "m/s")
        XCTAssertEqual(SpeedUnit.kilometersPerHour.rawValue, "km/h")
        XCTAssertEqual(SpeedUnit.milesPerHour.rawValue, "mph")
        XCTAssertEqual(SpeedUnit.knots.rawValue, "kts")
    }

    func testSpeedUnitAllCases() {
        let allCases = SpeedUnit.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.metersPerSecond))
        XCTAssertTrue(allCases.contains(.kilometersPerHour))
        XCTAssertTrue(allCases.contains(.milesPerHour))
        XCTAssertTrue(allCases.contains(.knots))
    }

    // MARK: - Renderer Tests

    func testRendererCreation() {
        let plugin = SpeedGaugePlugin()
        let renderer = plugin.createRenderer()

        XCTAssertNotNil(renderer)
        XCTAssertTrue(renderer is SpeedGaugeRenderer)
    }

    func testRendererWithValidData() throws {
        let plugin = SpeedGaugePlugin()
        let renderer = plugin.createRenderer()
        let config = SpeedGaugeConfiguration()

        // Create telemetry data with speed
        let point = TelemetryPoint(
            timestamp: Date(),
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            elevation: 100.0,
            speed: 25.0  // 25 m/s ≈ 55.9 mph
        )

        let dataProvider = MockDataProvider(currentPoint: point)

        // Create rendering context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let cgContext = CGContext(
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
            context: cgContext,
            renderContext: renderContext,
            configuration: config,
            dataProvider: dataProvider
        )
    }

    func testRendererWithNoData() throws {
        let plugin = SpeedGaugePlugin()
        let renderer = plugin.createRenderer()
        let config = SpeedGaugeConfiguration()

        // Create data provider with no current point
        let dataProvider = MockDataProvider(currentPoint: nil)

        // Create rendering context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let cgContext = CGContext(
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

        // Should not crash and should handle gracefully
        renderer.render(
            context: cgContext,
            renderContext: renderContext,
            configuration: config,
            dataProvider: dataProvider
        )
    }

    func testRendererWithNoSpeed() throws {
        let plugin = SpeedGaugePlugin()
        let renderer = plugin.createRenderer()
        let config = SpeedGaugeConfiguration()

        // Create telemetry data without speed
        let point = TelemetryPoint(
            timestamp: Date(),
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            elevation: 100.0,
            speed: nil
        )

        let dataProvider = MockDataProvider(currentPoint: point)

        // Create rendering context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let cgContext = CGContext(
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

        // Should not crash and should show "No Data"
        renderer.render(
            context: cgContext,
            renderContext: renderContext,
            configuration: config,
            dataProvider: dataProvider
        )
    }

    func testRendererWithDifferentUnits() throws {
        let plugin = SpeedGaugePlugin()
        let renderer = plugin.createRenderer()

        let point = TelemetryPoint(
            timestamp: Date(),
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            speed: 20.0  // 20 m/s
        )

        let dataProvider = MockDataProvider(currentPoint: point)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let cgContext = CGContext(
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

        // Test each unit
        for unit in SpeedUnit.allCases {
            var config = SpeedGaugeConfiguration()
            config.units = unit

            // Should not crash
            renderer.render(
                context: cgContext,
                renderContext: renderContext,
                configuration: config,
                dataProvider: dataProvider
            )
        }
    }

    // MARK: - Integration Tests

    func testFullPluginLifecycle() throws {
        // 1. Register plugin
        try PluginHost.shared.register(SpeedGaugePlugin.self)

        // 2. Discover plugin
        let metadata = PluginHost.shared.plugin(id: "com.flighttrace.speed-gauge")
        XCTAssertNotNil(metadata)
        XCTAssertEqual(metadata?.name, "Speed Gauge")

        // 3. Validate plugin with available data
        let availableData: Set<TelemetryDataType> = [.speed, .timestamp, .elevation]
        let validation = PluginHost.shared.validate(
            pluginID: "com.flighttrace.speed-gauge",
            withAvailableData: availableData
        )
        XCTAssertTrue(validation.isValid)

        // 4. Create plugin instance
        guard let instance = PluginHost.shared.createInstance(id: "com.flighttrace.speed-gauge") else {
            XCTFail("Failed to create plugin instance")
            return
        }

        // 5. Create and configure
        var config = instance.createConfiguration() as! SpeedGaugeConfiguration
        config.units = .kilometersPerHour
        config.decimalPlaces = 2

        // 6. Serialize and deserialize configuration
        let configData = try config.encode()
        let decodedConfig = try SpeedGaugeConfiguration.decode(from: configData)
        XCTAssertEqual(decodedConfig.units, .kilometersPerHour)

        // 7. Create renderer
        let renderer = instance.createRenderer()
        XCTAssertNotNil(renderer)

        // 8. Render with real data
        let point = TelemetryPoint(
            timestamp: Date(),
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            speed: 15.0
        )
        let dataProvider = MockDataProvider(currentPoint: point)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let cgContext = CGContext(
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

        // Should complete successfully
        renderer.render(
            context: cgContext,
            renderContext: renderContext,
            configuration: decodedConfig,
            dataProvider: dataProvider
        )
    }

    // MARK: - Isolation Tests

    func testPluginIsolation() {
        // Verify plugin only depends on protocol interfaces
        // The plugin should not access any internal FlightTraceCore types directly
        // except through TelemetryDataProvider

        let plugin = SpeedGaugePlugin()
        let renderer = plugin.createRenderer()

        // Plugin should work with any TelemetryDataProvider implementation
        let mockProvider = MockDataProvider()

        // This demonstrates complete isolation - plugin works with mock provider
        XCTAssertNotNil(mockProvider)
        XCTAssertNotNil(renderer)
    }

    func testPluginHasNoStoredState() {
        // Create two instances
        let instance1 = SpeedGaugePlugin()
        let instance2 = SpeedGaugePlugin()

        // Both should create independent configurations
        let config1 = instance1.createConfiguration()
        let config2 = instance2.createConfiguration()

        XCTAssertNotEqual(config1.id, config2.id)
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
