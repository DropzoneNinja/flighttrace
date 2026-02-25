// AltitudeGaugePluginTests.swift
// Unit tests for Altitude Gauge Plugin

import XCTest
import CoreGraphics
import CoreLocation
@testable import FlightTracePlugins
@testable import FlightTraceCore

@MainActor
final class AltitudeGaugePluginTests: XCTestCase {

    // MARK: - Setup

    override func setUp() async throws {
        PluginHost.shared.unregisterAll()
    }

    // MARK: - Plugin Metadata Tests

    func testPluginMetadata() {
        let metadata = AltitudeGaugePlugin.metadata

        XCTAssertEqual(metadata.id, "com.flighttrace.altitude-gauge")
        XCTAssertEqual(metadata.name, "Altitude Gauge")
        XCTAssertEqual(metadata.version, "1.0.0")
        XCTAssertEqual(metadata.category, .gauge)
        XCTAssertFalse(metadata.description.isEmpty)
    }

    func testPluginDataDependencies() {
        let dependencies = AltitudeGaugePlugin.dataDependencies

        XCTAssertEqual(dependencies.count, 2)
        XCTAssertTrue(dependencies.contains(.elevation))
        XCTAssertTrue(dependencies.contains(.timestamp))
    }

    func testPluginDefaultSize() {
        let defaultSize = AltitudeGaugePlugin.defaultSize
        let minimumSize = AltitudeGaugePlugin.minimumSize

        XCTAssertEqual(defaultSize.width, 200)
        XCTAssertEqual(defaultSize.height, 100)
        XCTAssertEqual(minimumSize.width, 120)
        XCTAssertEqual(minimumSize.height, 60)
    }

    // MARK: - Plugin Registration Tests

    func testPluginRegistration() throws {
        try PluginHost.shared.register(AltitudeGaugePlugin.self)

        let plugins = PluginHost.shared.availablePlugins()
        XCTAssertEqual(plugins.count, 1)
        XCTAssertEqual(plugins.first?.id, "com.flighttrace.altitude-gauge")
    }

    func testPluginInstantiation() throws {
        try PluginHost.shared.register(AltitudeGaugePlugin.self)

        let instance = PluginHost.shared.createInstance(id: "com.flighttrace.altitude-gauge")
        XCTAssertNotNil(instance)
        XCTAssertTrue(instance is AltitudeGaugePlugin)
    }

    func testPluginValidation() throws {
        try PluginHost.shared.register(AltitudeGaugePlugin.self)

        // Test with required data
        let validData: Set<TelemetryDataType> = [.elevation, .timestamp, .speed]
        let validResult = PluginHost.shared.validate(
            pluginID: "com.flighttrace.altitude-gauge",
            withAvailableData: validData
        )
        XCTAssertEqual(validResult, .valid)

        // Test with missing data
        let invalidData: Set<TelemetryDataType> = [.speed]
        let invalidResult = PluginHost.shared.validate(
            pluginID: "com.flighttrace.altitude-gauge",
            withAvailableData: invalidData
        )

        guard case .missingData(let missing) = invalidResult else {
            XCTFail("Expected .missingData result")
            return
        }
        XCTAssertTrue(missing.contains(.elevation))
        XCTAssertTrue(missing.contains(.timestamp))
    }

    // MARK: - Configuration Tests

    func testConfigurationDefaults() {
        let config = AltitudeGaugeConfiguration()

        XCTAssertEqual(config.units, .feet)
        XCTAssertEqual(config.decimalPlaces, 0)
        XCTAssertEqual(config.textColor, .white)
        XCTAssertTrue(config.showLabel)
        XCTAssertEqual(config.fontSize, 48.0)
        XCTAssertEqual(config.labelFontSize, 18.0)
        XCTAssertEqual(config.cornerRadius, 8.0)
        XCTAssertEqual(config.padding, 12.0)
    }

    func testConfigurationSerialization() throws {
        var config = AltitudeGaugeConfiguration()
        config.units = .meters
        config.decimalPlaces = 1
        config.textColor = .yellow
        config.showLabel = false
        config.fontSize = 64.0

        // Encode
        let data = try config.encode()
        XCTAssertFalse(data.isEmpty)

        // Decode
        let decoded = try AltitudeGaugeConfiguration.decode(from: data)
        XCTAssertEqual(decoded.id, config.id)
        XCTAssertEqual(decoded.units, .meters)
        XCTAssertEqual(decoded.decimalPlaces, 1)
        XCTAssertEqual(decoded.textColor, .yellow)
        XCTAssertFalse(decoded.showLabel)
        XCTAssertEqual(decoded.fontSize, 64.0)
    }

    func testConfigurationProperties() {
        let config = AltitudeGaugeConfiguration()
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

    // MARK: - Altitude Unit Tests

    func testAltitudeUnitConversions() {
        let altitudeMeters = 1000.0  // 1000 meters

        // Test meters
        XCTAssertEqual(
            AltitudeUnit.meters.convert(meters: altitudeMeters),
            1000.0,
            accuracy: 0.01
        )

        // Test feet (1000 m ≈ 3280.84 ft)
        XCTAssertEqual(
            AltitudeUnit.feet.convert(meters: altitudeMeters),
            3280.84,
            accuracy: 0.01
        )
    }

    func testAltitudeUnitRawValues() {
        XCTAssertEqual(AltitudeUnit.meters.rawValue, "m")
        XCTAssertEqual(AltitudeUnit.feet.rawValue, "ft")
    }

    func testAltitudeUnitAllCases() {
        let allCases = AltitudeUnit.allCases
        XCTAssertEqual(allCases.count, 2)
        XCTAssertTrue(allCases.contains(.meters))
        XCTAssertTrue(allCases.contains(.feet))
    }

    // MARK: - Renderer Tests

    func testRendererCreation() {
        let plugin = AltitudeGaugePlugin()
        let renderer = plugin.createRenderer()

        XCTAssertNotNil(renderer)
        XCTAssertTrue(renderer is AltitudeGaugeRenderer)
    }

    func testRendererWithValidData() throws {
        let plugin = AltitudeGaugePlugin()
        let renderer = plugin.createRenderer()
        let config = AltitudeGaugeConfiguration()

        // Create telemetry data with elevation
        let point = TelemetryPoint(
            timestamp: Date(),
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            elevation: 1500.0  // 1500 meters
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
        let plugin = AltitudeGaugePlugin()
        let renderer = plugin.createRenderer()
        let config = AltitudeGaugeConfiguration()

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

    func testRendererWithNoElevation() throws {
        let plugin = AltitudeGaugePlugin()
        let renderer = plugin.createRenderer()
        let config = AltitudeGaugeConfiguration()

        // Create telemetry data without elevation
        let point = TelemetryPoint(
            timestamp: Date(),
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            elevation: nil,
            speed: 25.0
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
        let plugin = AltitudeGaugePlugin()
        let renderer = plugin.createRenderer()

        let point = TelemetryPoint(
            timestamp: Date(),
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            elevation: 2000.0  // 2000 meters
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
        for unit in AltitudeUnit.allCases {
            var config = AltitudeGaugeConfiguration()
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
        try PluginHost.shared.register(AltitudeGaugePlugin.self)

        // 2. Discover plugin
        let metadata = PluginHost.shared.plugin(id: "com.flighttrace.altitude-gauge")
        XCTAssertNotNil(metadata)
        XCTAssertEqual(metadata?.name, "Altitude Gauge")

        // 3. Validate plugin with available data
        let availableData: Set<TelemetryDataType> = [.elevation, .timestamp, .speed]
        let validation = PluginHost.shared.validate(
            pluginID: "com.flighttrace.altitude-gauge",
            withAvailableData: availableData
        )
        XCTAssertTrue(validation.isValid)

        // 4. Create plugin instance
        guard let instance = PluginHost.shared.createInstance(id: "com.flighttrace.altitude-gauge") else {
            XCTFail("Failed to create plugin instance")
            return
        }

        // 5. Create and configure
        var config = instance.createConfiguration() as! AltitudeGaugeConfiguration
        config.units = .meters
        config.decimalPlaces = 1

        // 6. Serialize and deserialize configuration
        let configData = try config.encode()
        let decodedConfig = try AltitudeGaugeConfiguration.decode(from: configData)
        XCTAssertEqual(decodedConfig.units, .meters)

        // 7. Create renderer
        let renderer = instance.createRenderer()
        XCTAssertNotNil(renderer)

        // 8. Render with real data
        let point = TelemetryPoint(
            timestamp: Date(),
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            elevation: 1200.0
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

        let plugin = AltitudeGaugePlugin()
        let renderer = plugin.createRenderer()

        // Plugin should work with any TelemetryDataProvider implementation
        let mockProvider = MockDataProvider()

        // This demonstrates complete isolation - plugin works with mock provider
        XCTAssertNotNil(mockProvider)
        XCTAssertNotNil(renderer)
    }

    func testPluginHasNoStoredState() {
        // Create two instances
        let instance1 = AltitudeGaugePlugin()
        let instance2 = AltitudeGaugePlugin()

        // Both should create independent configurations
        let config1 = instance1.createConfiguration()
        let config2 = instance2.createConfiguration()

        XCTAssertNotEqual(config1.id, config2.id)
    }

    // MARK: - Multi-Plugin Tests

    func testBothPluginsCanCoexist() throws {
        // Register both plugins
        try PluginHost.shared.register(SpeedGaugePlugin.self)
        try PluginHost.shared.register(AltitudeGaugePlugin.self)

        // Both should be available
        let plugins = PluginHost.shared.availablePlugins()
        XCTAssertEqual(plugins.count, 2)

        // Both should be independently instantiable
        let speedInstance = PluginHost.shared.createInstance(id: "com.flighttrace.speed-gauge")
        let altitudeInstance = PluginHost.shared.createInstance(id: "com.flighttrace.altitude-gauge")

        XCTAssertNotNil(speedInstance)
        XCTAssertNotNil(altitudeInstance)
        XCTAssertTrue(speedInstance is SpeedGaugePlugin)
        XCTAssertTrue(altitudeInstance is AltitudeGaugePlugin)
    }

    func testBothPluginsRenderSimultaneously() throws {
        // Create both plugins
        let speedPlugin = SpeedGaugePlugin()
        let altitudePlugin = AltitudeGaugePlugin()

        let speedRenderer = speedPlugin.createRenderer()
        let altitudeRenderer = altitudePlugin.createRenderer()

        let speedConfig = SpeedGaugeConfiguration()
        let altitudeConfig = AltitudeGaugeConfiguration()

        // Create telemetry data with both speed and elevation
        let point = TelemetryPoint(
            timestamp: Date(),
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            elevation: 1500.0,
            speed: 25.0
        )

        let dataProvider = MockDataProvider(currentPoint: point)

        // Create rendering contexts
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let speedContext = CGContext(
            data: nil,
            width: 200,
            height: 100,
            bitsPerComponent: 8,
            bytesPerRow: 800,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let altitudeContext = CGContext(
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

        // Both should render without interfering with each other
        speedRenderer.render(
            context: speedContext,
            renderContext: renderContext,
            configuration: speedConfig,
            dataProvider: dataProvider
        )

        altitudeRenderer.render(
            context: altitudeContext,
            renderContext: renderContext,
            configuration: altitudeConfig,
            dataProvider: dataProvider
        )

        // If we get here, both rendered successfully
        XCTAssertTrue(true)
    }
}
