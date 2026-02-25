# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FlightTrace is a native macOS application (Swift/SwiftUI) that generates GPS-based video overlays from GPX files. Users can add customizable instruments (speed, altitude, G-meter, minimap, etc.) to videos, positioning them freely on a canvas before rendering the final export.

**Key Design Constraint:** The architecture must be plugin-driven to allow new instruments to be added without modifying core code.

## Architecture

### Core Modules

The application follows MVVM pattern with the following core components:

- **GPXParser**: Parses GPX files, extracts telemetry data (lat/lon/alt/timestamps), derives missing data (speed from position deltas, vertical speed, G-forces)
- **TimelineEngine**: Manages synchronization between GPX track duration and video footage, handles manual offset alignment and trimming
- **OverlayCanvas**: Canvas-based editor for positioning, resizing, rotating instruments with snap guides and Z-order control
- **PluginHost**: Discovers and manages instrument plugins at runtime
- **ExportEngine**: Offline frame-accurate renderer (not screen capture) using AVFoundation
- **VideoRenderer**: Handles actual video encoding with configurable codecs, resolutions, and frame rates

### Plugin Architecture

The plugin system is the foundation of extensibility. Each instrument is an independent plugin that conforms to shared protocols:

**Required Plugin Protocols:**
- `InstrumentPlugin`: Defines plugin ID, display name, data dependencies, default size
- `InstrumentRenderer`: Implements the rendering method (Core Graphics/Core Animation/Metal)
- `InstrumentConfiguration`: Exposes configurable properties (colors, units, scale, smoothing, style)

**Plugin Isolation Rules:**
- Plugins must NOT access UI internals or video export internals directly
- Plugins receive only the telemetry data they declared as dependencies
- All plugin parameters must be declarative and serializable for preset support

**Built-in Plugins (Initial Set):**
Speed gauge, altitude gauge, vertical speed indicator, G-meter, trackline/breadcrumb trail, minimap, heading/compass, timestamp, distance traveled

### Data Flow

1. GPX file → GPXParser → Telemetry data model (with derived values)
2. Telemetry + Timeline offset → Synchronized data points
3. Active plugins query required data at current timeline position
4. Overlay canvas composites all plugin renders in Z-order
5. Export engine renders frame-by-frame to video file

## Critical Implementation Notes

### GPX Processing
- Support multi-track and multi-segment GPX files (user selects which to use)
- Always derive missing data: speed from position deltas, vertical speed from altitude deltas, G-forces from speed deltas
- Implement smoothing for noisy GPS data (configurable per-plugin)
- Support interpolation for missing data points

### Timeline Synchronization
- The timeline scrubber must drive the preview, not the other way around
- Manual offset alignment is essential (GPX start time rarely matches video start)
- All rendering must be deterministic and frame-accurate for consistent exports

### Rendering Performance
- Instruments must be vector-based and resolution-independent
- Real-time preview is priority one (target Apple Silicon)
- Consider Metal for complex instruments if Core Graphics/Core Animation performance is insufficient
- Export pipeline must handle long videos (>1 hour) efficiently

### UI/UX Expectations
- Modern macOS native feel (SwiftUI preferred, AppKit only where necessary)
- Dark and light mode support required
- Inspector-style panels for instrument configuration
- Safe-area guides for common aspect ratios (16:9, 9:16, 1:1)
- Snap-to-edge, snap-to-center, rule-of-thirds guides

## Extensibility Goals

The architecture should support future addition of:
- FIT or CSV telemetry formats (not just GPX)
- Live telemetry input streams
- Preset/template system (save and load overlay layouts)
- Plugin marketplace or external plugin loading

**Non-goals:** iOS support, cloud sync, social sharing, real-time live overlays

## Development Commands

When the project is set up with Swift Package Manager or Xcode:

**Build:** `swift build` or build in Xcode (⌘B)
**Test:** `swift test` or test in Xcode (⌘U)
**Run:** Open in Xcode and run (⌘R)

Ensure sandboxing is enabled for macOS App Store compatibility.

## Key Files (Future)

Expected structure once implementation begins:
- `/Sources/Core/`: GPXParser, TimelineEngine, ExportEngine
- `/Sources/Plugins/`: Plugin protocols and built-in instrument implementations
- `/Sources/UI/`: SwiftUI views for canvas, timeline, inspector panels
- `/Sources/Rendering/`: VideoRenderer, frame compositing logic
- `/Tests/`: Unit tests for data processing, integration tests for export pipeline

## Testing Strategy

- **Unit tests:** GPX parsing, data derivation (speed/G-force calculations), timeline synchronization
- **Plugin tests:** Each plugin must have isolated rendering tests
- **Integration tests:** Full export pipeline with known GPX + video input
- **Performance tests:** Real-time preview smoothness, export speed benchmarks
