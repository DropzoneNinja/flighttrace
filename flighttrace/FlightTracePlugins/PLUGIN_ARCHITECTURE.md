# FlightTrace Plugin Architecture (Metal-Only)

This document defines the plugin system architecture and **Metal-only** rendering requirements for FlightTrace instrument plugins.

## Overview

FlightTrace uses a strict plugin architecture so instruments can be added without modifying core UI or export code. All instrument rendering is **Metal-only** and must be deterministic for frame-accurate export.

## Design Goals

1. **Isolation**: Plugins cannot access UI or export internals.
2. **Deterministic Rendering**: Same inputs always produce identical output.
3. **Serializable Configuration**: All plugin settings are Codable.
4. **Metal-Only Rendering**: No CoreGraphics/SwiftUI rendering paths.
5. **Real-Time Friendly**: Keep per-frame allocations minimal.

## Plugin Components

Each plugin consists of:

### 1) Plugin Descriptor (`InstrumentPlugin`)

Defines identity, data requirements, and factory methods.

```swift
public struct AltitudeDigitalPlugin: InstrumentPlugin {
    public static let metadata = PluginMetadata(
        id: "com.flighttrace.altitude-gauge",
        name: "Altitude Gauge",
        description: "Digital altitude display",
        version: "1.0.0",
        category: .gauge
    )

    public static let dataDependencies: Set<TelemetryDataType> = [.elevation, .timestamp]
    public static let defaultSize = CGSize(width: 240, height: 120)

    public func createConfiguration() -> any InstrumentConfiguration {
        AltitudeDigitalConfiguration()
    }

    public func createRenderer() -> any InstrumentRenderer {
        AltitudeDigitalRenderer()
    }
}
```

### 2) Configuration (`InstrumentConfiguration`)

Settings must be Codable and expose editable properties:

```swift
public struct AltitudeDigitalConfiguration: InstrumentConfiguration, Codable {
    public var units: AltitudeUnit = .feet
    public var textColor: SerializableColor = .white
    public var backgroundColor: SerializableColor = SerializableColor.black.withAlpha(0.7)
    public var fontSize: Double = 48.0

    public func encode() throws -> Data { try JSONEncoder().encode(self) }
    public static func decode(from data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }

    public func properties() -> [ConfigurationProperty] {
        [
            .enumeration(key: "units", value: units, options: AltitudeUnit.allCases),
            .color(key: "textColor", value: textColor),
            .color(key: "backgroundColor", value: backgroundColor),
            .slider(key: "fontSize", value: fontSize, range: 24...96, step: 4)
        ]
    }
}
```

### 3) Renderer (`InstrumentRenderer`) — **Metal-only**

Plugins must render using `MetalRenderContext`. Do not use CoreGraphics or SwiftUI rendering paths.

```swift
public struct AltitudeDigitalRenderer: InstrumentRenderer {
    public func render(
        context: MetalRenderContext,
        configuration: any InstrumentConfiguration,
        dataProvider: any TelemetryDataProvider
    ) {
        guard let config = configuration as? AltitudeDigitalConfiguration else { return }
        let renderer = Metal2DRenderer.shared(for: context.device)

        renderer.drawRoundedRect(
            in: context.bounds,
            radius: 8,
            color: config.backgroundColor,
            renderContext: context
        )

        // ... draw text using MetalTextRenderer
    }
}
```

## Metal Rendering Rules

- **Metal-only**: Renderers must encode Metal draw calls via `MetalRenderContext.renderEncoder`.
- **Do not end the encoder**: The caller owns encoder lifecycle.
- **Use pixel coordinates**: `MetalRenderContext.bounds` is in points; use `viewportSize` for NDC mapping.
- **Deterministic**: Avoid randomness, time-based jitter, or non-deterministic GPU state.
- **Text rendering**: Use `MetalTextRenderer` (CoreText → texture) and render via `Metal2DRenderer`.
- **Geometry helpers**: Prefer `Metal2DRenderer` helpers (`drawRoundedRect`, `drawCircleStroke`, `drawLine`, `drawTexture`) over custom pipelines.
- **Text padding**: If glyphs clip, use `extraVerticalPadding` when building text textures.
- **Color space**: Render in sRGB; assume `.bgra8Unorm` targets with premultiplied alpha. Keep color values in linear 0–1 and let the pipeline handle blending.
- **Images**: Put PNG assets in `Sources/FlightTracePlugins/Resources` and load via `Metal2DRenderer.texture(named:)`, which uses `Bundle.module`. Use the asset name without extension (for example `steam-gauge-bezel`).

## Coordinate System

- Origin is **top-left** in `Metal2DRenderer`.
- Vertex shader converts pixel coordinates to NDC with Y-axis down.

## Plugin Lifecycle

1. **Registration**: App registers plugins at startup via `PluginHost.shared.register(...)`.
2. **Discovery**: UI queries `PluginHost.shared.availablePlugins()` and filters by category/data.
3. **Instantiation**: `PluginHost.shared.createInstance(id:)` creates configuration + renderer.
4. **Rendering**: UI and Export call `renderer.render(context: MetalRenderContext, ...)`.

## Performance Guidelines

- Avoid per-frame allocations or heavy formatting work.
- Cache expensive resources (fonts, textures) in renderer helpers.
- Prefer simple geometry and batching when possible.
- Keep segment counts reasonable for circles/rings (e.g., 32–64).

## Migration Notes

- The legacy CoreGraphics render path has been removed.
- Plugins must be ported and reintroduced one-by-one.
- Until migrated, a plugin should not be registered or compiled.
- When porting, prefer Metal2DRenderer primitives over ad-hoc CoreGraphics behavior to keep a consistent render pipeline.
