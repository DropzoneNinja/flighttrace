# FlightTrace Plugin Architecture

This document describes the plugin system architecture, lifecycle, and isolation rules for FlightTrace instrument plugins.

## Overview

FlightTrace uses a **strict plugin architecture** to ensure extensibility without compromising core stability. Every instrument displayed on the overlay canvas is an independent plugin that conforms to well-defined protocols.

### Design Goals

1. **Complete Isolation**: Plugins cannot access core internals or affect each other
2. **Zero Core Modifications**: Adding new instruments requires zero changes to core code
3. **Declarative Configuration**: All plugin settings are serializable and inspectable
4. **Deterministic Rendering**: Same input always produces identical output (critical for video export)
5. **Performance First**: Plugins must support real-time 60fps preview on Apple Silicon

## Plugin Components

Every plugin consists of three parts:

### 1. Plugin Descriptor (`InstrumentPlugin`)

Defines plugin identity, data requirements, and factory methods.

```swift
struct SpeedGaugePlugin: InstrumentPlugin {
    static let metadata = PluginMetadata(
        id: "com.flighttrace.speed-gauge",
        name: "Speed Gauge",
        description: "Displays current ground speed",
        version: "1.0.0",
        category: .gauge
    )

    static let dataDependencies: Set<TelemetryDataType> = [.speed, .timestamp]
    static let defaultSize = CGSize(width: 200, height: 100)

    func createConfiguration() -> any InstrumentConfiguration {
        SpeedGaugeConfiguration()
    }

    func createRenderer() -> any InstrumentRenderer {
        SpeedGaugeRenderer()
    }
}
```

### 2. Configuration (`InstrumentConfiguration`)

Holds customizable settings for the instrument instance.

```swift
struct SpeedGaugeConfiguration: InstrumentConfiguration, Codable {
    var id = UUID()
    var units: SpeedUnit = .mph
    var decimalPlaces: Int = 1
    var textColor: SerializableColor = .white
    var backgroundColor: SerializableColor = .black.withAlpha(0.7)

    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    static func decode(from data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }

    func properties() -> [ConfigurationProperty] {
        [
            .enumeration("units", value: units, options: SpeedUnit.allCases),
            .integer("decimalPlaces", value: decimalPlaces, range: 0...3),
            .color("textColor", value: textColor),
            .color("backgroundColor", value: backgroundColor)
        ]
    }
}
```

### 3. Renderer (`InstrumentRenderer`)

Draws the visual representation using Core Graphics or SwiftUI.

```swift
struct SpeedGaugeRenderer: InstrumentRenderer {
    func render(
        context: CGContext,
        renderContext: RenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        guard let point = dataProvider.currentPoint(),
              let speed = point.speed,
              let config = configuration as? SpeedGaugeConfiguration else {
            return
        }

        let bounds = renderContext.bounds

        // Draw background
        context.setFillColor(config.backgroundColor.cgColor)
        context.fill(bounds)

        // Convert speed to configured units
        let displaySpeed = config.units == .mph ? speed * 2.237 : speed * 3.6

        // Draw speed value
        let text = String(format: "%.\(config.decimalPlaces)f", displaySpeed)
        // ... Core Graphics text rendering
    }
}
```

## Plugin Lifecycle

### 1. Registration Phase (App Startup)

```swift
// Main app initialization
PluginHost.shared.register([
    SpeedGaugePlugin.self,
    AltitudeGaugePlugin.self,
    GMeterPlugin.self,
    // ... more plugins
])
```

### 2. Discovery Phase (User Interaction)

When the user opens the plugin catalog:
```swift
// Get all available plugins
let plugins = PluginHost.shared.availablePlugins()

// Filter by category
let gauges = PluginHost.shared.plugins(in: .gauge)

// Check compatibility with current GPX data
let available = Set<TelemetryDataType>([.speed, .elevation, .coordinate])
let compatible = PluginHost.shared.compatiblePlugins(withAvailableData: available)
```

### 3. Instantiation Phase (User Adds Instrument)

```swift
// User selects "Speed Gauge" from catalog
let instance = PluginHost.shared.createInstance(id: "com.flighttrace.speed-gauge")

// Create configuration for this instance
let config = instance.createConfiguration()

// Create renderer
let renderer = instance.createRenderer()

// Store in canvas state
canvasState.instruments.append(InstrumentInstance(
    plugin: instance,
    configuration: config,
    renderer: renderer,
    position: .zero,
    size: type(of: instance).defaultSize
))
```

### 4. Rendering Phase (Preview & Export)

#### Preview Rendering (Real-time)
```swift
// Canvas view calls this at 60fps
for instrument in instruments {
    let renderContext = RenderContext(
        bounds: instrument.bounds,
        scale: displayScale,
        currentTime: timeline.currentTime,
        isPreview: true,
        frameRate: 60.0
    )

    instrument.renderer.render(
        context: cgContext,
        renderContext: renderContext,
        configuration: instrument.configuration,
        dataProvider: timelineEngine
    )
}
```

#### Export Rendering (Frame-by-frame)
```swift
// Export engine renders deterministically
for frameNumber in 0..<totalFrames {
    let timestamp = startTime.addingTimeInterval(Double(frameNumber) / frameRate)

    let renderContext = RenderContext(
        bounds: exportBounds,
        scale: 1.0,
        currentTime: timestamp,
        isPreview: false,
        frameRate: frameRate,
        frameNumber: frameNumber
    )

    // Render all instruments
    for instrument in instruments {
        instrument.renderer.render(
            context: exportContext,
            renderContext: renderContext,
            configuration: instrument.configuration,
            dataProvider: exportDataProvider
        )
    }
}
```

### 5. Configuration Phase (User Customization)

```swift
// User opens inspector panel
let properties = instrument.configuration.properties()

// UI automatically generates controls
for property in properties {
    switch property {
    case .color(let key, let value, let label):
        ColorPicker(label ?? key, selection: $value)
    case .enumeration(let key, let value, let options, let label):
        Picker(label ?? key, selection: $value) {
            ForEach(options) { option in
                Text(option.displayName)
            }
        }
    // ... more control types
    }
}
```

### 6. Serialization Phase (Save/Load Layout)

```swift
// Save overlay layout
let layout = OverlayLayout(
    instruments: canvasState.instruments.map { instrument in
        SavedInstrument(
            pluginID: type(of: instrument.plugin).metadata.id,
            configurationData: try instrument.configuration.encode(),
            position: instrument.position,
            size: instrument.size,
            rotation: instrument.rotation,
            zIndex: instrument.zIndex
        )
    }
)
try JSONEncoder().encode(layout).write(to: url)

// Load overlay layout
let layout = try JSONDecoder().decode(OverlayLayout.self, from: data)
for saved in layout.instruments {
    let instance = PluginHost.shared.createInstance(id: saved.pluginID)
    let config = try instance.createConfiguration().decode(from: saved.configurationData)
    // ... restore instrument
}
```

## Isolation Rules

### ✅ Plugins MAY:
- Access telemetry data through `TelemetryDataProvider`
- Read their own configuration
- Perform rendering using Core Graphics, Core Animation, or Metal
- Declare data dependencies and metadata
- Provide configurable properties

### ❌ Plugins MUST NOT:
- Access UI internals (canvas state, timeline controls, etc.)
- Access video export internals directly
- Access other plugins or their configurations
- Maintain mutable state between render calls
- Access file system, network, or system resources
- Use random numbers or timestamps (breaks determinism)

### Data Access Rules

Plugins receive data through `TelemetryDataProvider`:

```swift
protocol TelemetryDataProvider: Sendable {
    func currentPoint() -> TelemetryPoint?
    func point(at timestamp: Date) -> TelemetryPoint?
    func points(from startTime: Date, to endTime: Date) -> [TelemetryPoint]
    func lastPoints(_ count: Int) -> [TelemetryPoint]
    func track() -> TelemetryTrack?  // Use sparingly
    func trackStatistics() -> TrackStatistics?
}
```

**Guidelines:**
- Prefer `currentPoint()` for most instruments
- Use `lastPoints(_:)` for trail effects (e.g., breadcrumb trails)
- Use `track()` only when absolutely necessary (e.g., minimap)
- Cache expensive computations in configuration when possible

## Rendering Contract

### Text Rendering (CRITICAL - Common Pitfall!)

**❌ DO NOT use `NSAttributedString.draw()` in plugin renderers!**

While `NSAttributedString.draw()` works in preview mode, it **silently fails during video export** because it requires a window context that doesn't exist during background rendering.

#### ❌ WRONG - This will NOT work in exports:
```swift
func render(context: CGContext, ...) {
    #if canImport(AppKit)
    let font = NSFont.systemFont(ofSize: 48, weight: .bold)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]
    let text = NSAttributedString(string: "123", attributes: attributes)

    // ❌ This appears in preview but NOT in exported video!
    text.draw(in: textRect)
    #endif
}
```

#### ✅ CORRECT - Use Core Text instead:
```swift
import CoreText  // Add this import!

func render(context: CGContext, ...) {
    #if canImport(AppKit)
    let font = NSFont.systemFont(ofSize: 48, weight: .bold)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]
    let attributedString = NSAttributedString(string: "123", attributes: attributes)

    // Calculate text size for positioning
    let textSize = attributedString.size()
    let textRect = CGRect(
        x: bounds.midX - textSize.width / 2,
        y: bounds.midY - textSize.height / 2,
        width: textSize.width,
        height: textSize.height
    )

    // ✅ Use Core Text to draw in CGContext
    context.saveGState()

    // Flip coordinate system for text (Core Text uses different Y orientation)
    context.textMatrix = .identity
    context.translateBy(x: textRect.origin.x, y: textRect.origin.y + textSize.height)
    context.scaleBy(x: 1.0, y: -1.0)

    // Create CTLine and draw
    let line = CTLineCreateWithAttributedString(attributedString)
    CTLineDraw(line, context)

    context.restoreGState()
    #endif
}
```

**Why this matters:**
- **Preview mode**: Both approaches appear to work because there's a window context
- **Export mode**: Background rendering has no window context, so `NSAttributedString.draw()` silently fails
- **Result**: Plugin looks perfect in preview but text is completely missing in exported video!

**Complete example with background and text:**
```swift
import CoreText

private func renderAltitudeValue(
    context: CGContext,
    bounds: CGRect,
    altitudeValue: Double,
    config: AltitudeGaugeConfiguration
) {
    #if canImport(AppKit)
    // 1. Draw background (works fine with regular CGContext)
    context.setFillColor(config.backgroundColor.cgColor)
    context.fill(bounds)

    // 2. Format the text
    let text = String(format: "%.0f", altitudeValue)
    let font = NSFont.monospacedDigitSystemFont(ofSize: 48, weight: .bold)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: config.textColor.nsColor
    ]
    let attributedString = NSAttributedString(string: text, attributes: attributes)

    // 3. Calculate positioning
    let textSize = attributedString.size()
    let textRect = CGRect(
        x: bounds.midX - textSize.width / 2,
        y: bounds.midY - textSize.height / 2,
        width: textSize.width,
        height: textSize.height
    )

    // 4. Draw text using Core Text (works in both preview and export!)
    context.saveGState()
    context.textMatrix = .identity
    context.translateBy(x: textRect.origin.x, y: textRect.origin.y + textSize.height)
    context.scaleBy(x: 1.0, y: -1.0)

    let line = CTLineCreateWithAttributedString(attributedString)
    CTLineDraw(line, context)

    context.restoreGState()
    #endif
}
```

**Other AppKit APIs to avoid:**
- ❌ `NSBezierPath.stroke()` / `.fill()` - Use `CGPath` instead
- ❌ `NSColor.set()` - Use `CGContext.setFillColor()` / `setStrokeColor()` instead
- ❌ `NSImage.draw()` - Use `CGImage` and `context.draw()` instead
- ✅ Pure Core Graphics (CG*) APIs work everywhere

### Quick Reference: Export-Safe Rendering Checklist

Before submitting your plugin, verify:
- [ ] Added `import CoreText` to file imports
- [ ] Using `CTLineCreateWithAttributedString()` and `CTLineDraw()` for ALL text rendering
- [ ] NOT using `NSAttributedString.draw()`, `NSBezierPath`, or other AppKit drawing methods
- [ ] All positions calculated relative to `renderContext.bounds`, not absolute coordinates
- [ ] Tested plugin in actual export (not just preview!)
- [ ] Added debug logging to verify render method completes
- [ ] No use of `Date()`, `random()`, or other non-deterministic APIs

### Determinism Requirement

**Critical for video export:** Plugins must be **deterministic**.

```swift
// ✅ CORRECT: Deterministic rendering
let speed = dataProvider.currentPoint()?.speed ?? 0
let text = String(format: "%.1f", speed * 2.237)
drawText(text, at: center)

// ❌ WRONG: Non-deterministic rendering
let randomJitter = Double.random(in: -1...1)  // Different every frame!
drawText(text, at: center.offset(by: randomJitter))

// ❌ WRONG: Using current time instead of render context time
let now = Date()  // Will differ between preview and export!
let opacity = sin(now.timeIntervalSince1970)
```

### Performance Requirements

- **Preview**: Target 60fps on Apple Silicon (M1 or later)
- **Export**: No time limit, but should be reasonable (<1s per frame for 4K)
- Minimize allocations in render path
- Use Metal for complex rendering (particle systems, advanced effects)
- Cache bitmap representations when beneficial

### Resolution Independence

Plugins should render at any resolution:

```swift
// ✅ CORRECT: Scale relative to bounds
let fontSize = renderContext.bounds.height * 0.5

// ❌ WRONG: Fixed pixel sizes
let fontSize: CGFloat = 48  // Looks wrong at different sizes
```

## Testing Plugins

Each plugin should have:

1. **Rendering Test**: Verify visual output with known data
2. **Configuration Test**: Test serialization/deserialization
3. **Data Dependency Test**: Verify behavior with missing data
4. **Performance Test**: Measure render time

```swift
final class SpeedGaugePluginTests: XCTestCase {
    func testRendering() {
        let renderer = SpeedGaugeRenderer()
        let config = SpeedGaugeConfiguration()
        let dataProvider = MockDataProvider(speed: 50.0)

        let context = createCGContext(size: CGSize(width: 200, height: 100))
        let renderContext = RenderContext(
            bounds: CGRect(x: 0, y: 0, width: 200, height: 100),
            currentTime: Date()
        )

        renderer.render(
            context: context,
            renderContext: renderContext,
            configuration: config,
            dataProvider: dataProvider
        )

        // Verify output (snapshot test or pixel comparison)
    }

    func testConfigurationSerialization() throws {
        let config = SpeedGaugeConfiguration()
        config.units = .kph
        config.decimalPlaces = 2

        let data = try config.encode()
        let decoded = try SpeedGaugeConfiguration.decode(from: data)

        XCTAssertEqual(config.units, decoded.units)
        XCTAssertEqual(config.decimalPlaces, decoded.decimalPlaces)
    }
}
```

## Plugin Distribution

### Built-in Plugins
Located in `Sources/FlightTracePlugins/Instruments/`

### Future: External Plugins
- Plugins could be loaded from app bundle or user directory
- Must be code-signed and sandboxed
- Discovery via plugin manifest files
- Hot-reloading for development

## Debugging Plugin Rendering Issues

### "It works in preview but not in export!"

**Symptom**: Plugin renders correctly in the canvas preview, but appears blank/missing in exported video.

**Most common cause**: Using AppKit drawing APIs instead of Core Graphics/Core Text.

**How to debug:**
1. **Add debug logging** in your render method:
   ```swift
   func render(...) {
       print("DEBUG: \(type(of: self)) rendering at bounds: \(renderContext.bounds)")

       // Your rendering code

       print("DEBUG: \(type(of: self)) finished rendering")
   }
   ```

2. **Check the export logs** - if you see the start log but not the finish log, the render method is crashing silently

3. **Look for these patterns** in your code:
   - ❌ `attributedString.draw(in: rect)` → Replace with Core Text
   - ❌ `NSBezierPath.stroke()` → Replace with `CGPath`
   - ❌ `NSColor.set()` → Replace with `context.setFillColor()`

4. **Test export early** - Don't wait until your plugin is "complete" to test export functionality!

### "The position/size is wrong in export!"

**Symptom**: Plugin appears at wrong location or wrong size in export compared to preview.

**Common causes:**
- Using screen coordinates instead of render context bounds
- Not accounting for coordinate scaling between canvas and export resolution

**Fix**: Always use `renderContext.bounds` for positioning, never absolute coordinates:
```swift
// ✅ CORRECT - Relative to bounds
let centerX = renderContext.bounds.midX
let centerY = renderContext.bounds.midY

// ❌ WRONG - Absolute coordinates
let centerX: CGFloat = 960  // Assumes 1920x1080!
```

## Best Practices

1. **Keep plugins simple and focused** - Do one thing well
2. **Declare minimal dependencies** - Only request data you actually use
3. **Provide sensible defaults** - Plugin should work without configuration
4. **Document configuration properties** - Use clear labels and descriptions
5. **Test with missing data** - Handle nil values gracefully
6. **Optimize render path** - Profile and minimize allocations
7. **Use vector graphics** - Avoid bitmaps unless necessary
8. **Consider accessibility** - Support different color schemes and sizes
9. **Test export early and often** - Preview mode is NOT enough to validate rendering
10. **Use Core Text for text** - Never use `NSAttributedString.draw()` in plugins

## Example: Complete Plugin Implementation

See [SpeedGaugePlugin.swift](../Instruments/SpeedGaugePlugin.swift) for a complete working example (to be implemented in Phase 3).

## Summary

The FlightTrace plugin architecture provides:
- ✅ Complete isolation between plugins and core
- ✅ Zero-modification extensibility
- ✅ Deterministic rendering for video export
- ✅ Automatic UI generation from configuration
- ✅ Type-safe data access
- ✅ Performance-first design

This architecture enables rapid development of new instruments while maintaining stability and performance of the core application.
