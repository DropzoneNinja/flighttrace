# FlightTrace

A native macOS application for generating GPS-based video overlays from GPX files.

## Overview

FlightTrace allows users to create customizable instrument overlays (speed, altitude, G-meter, minimap, etc.) and position them freely on a canvas before rendering them into video exports. Perfect for action sports, aviation, and outdoor activities.

## Architecture

The application follows a **plugin-driven architecture** to enable extensibility without modifying core code.

### Core Modules

```
FlightTrace/
├── FlightTraceCore       # GPX parsing, timeline, export engine
├── FlightTracePlugins    # Plugin protocols and instruments
├── FlightTraceUI         # SwiftUI views (canvas, timeline, inspector)
└── FlightTraceApp        # Main application entry point
```

#### FlightTraceCore
- **GPXParser**: Parses GPX files, derives speed/vertical speed/G-forces
- **TimelineEngine**: Synchronizes GPX data with video timeline
- **ExportEngine**: Frame-accurate offline video rendering
- **TelemetryDataProvider**: Plugin interface for querying telemetry

#### FlightTracePlugins
- **Plugin Protocols**: `InstrumentPlugin`, `InstrumentRenderer`, `InstrumentConfiguration`
- **PluginHost**: Runtime plugin discovery and registry
- **Instruments**: Speed gauge, altitude, G-meter, minimap, etc.

#### FlightTraceUI
- **OverlayCanvas**: Canvas editor with drag/resize/rotate/snap guides
- **Timeline**: Scrubber for real-time preview synchronization
- **Inspector**: Per-instrument configuration panels

#### FlightTraceApp
- Main window layout and application lifecycle

## Plugin System

Each instrument is an independent plugin conforming to:

- **InstrumentPlugin**: Defines ID, name, data dependencies, default size
- **InstrumentRenderer**: Implements rendering (Core Graphics/Core Animation/Metal)
- **InstrumentConfiguration**: Exposes configurable properties

**Key Design Principles:**
- Plugins are isolated (no direct UI/export access)
- Plugins declare data dependencies explicitly
- New plugins require zero changes to core code
- All plugin parameters are serializable

## Development

### Requirements
- macOS Sonoma (14.0) or later
- Xcode 15.0+ or Swift 5.9+
- VSCode with Swift extension (optional)

### Building

```bash
# Build the project
swift build

# Run tests
swift test

# Run the application
swift run FlightTrace

# Clean build artifacts
swift package clean
```

### VSCode Development

The project includes VSCode configurations:
- **Build Task**: `Cmd+Shift+B` to build
- **Test Task**: Configured in tasks.json
- **Debug**: Launch configuration for LLDB

## Current Status

**Phase 0: Project Setup** ✅
Foundation is complete. Ready for Phase 1 (GPX Processing).

See [TODO.md](TODO.md) for detailed phase breakdown and progress tracking.

## Project Structure

```
FlightTrace/
├── Package.swift                    # SPM configuration
├── README.md                        # This file
├── TODO.md                          # Phase tracking
├── CLAUDE.md                        # Development guidelines
├── PROJECT.md                       # Full specification
├── Sources/
│   ├── FlightTraceCore/
│   │   ├── GPX/                    # GPX parsing
│   │   ├── Models/                 # Data models
│   │   ├── Processing/             # Telemetry calculations
│   │   ├── Timeline/               # Timeline synchronization
│   │   ├── Plugin/                 # Plugin data interfaces
│   │   ├── Rendering/              # Render context
│   │   └── Export/                 # Export engine
│   ├── FlightTracePlugins/
│   │   ├── PluginProtocols/        # Plugin interfaces
│   │   ├── Instruments/            # Built-in instruments
│   │   └── PluginHost.swift        # Plugin registry
│   ├── FlightTraceUI/
│   │   ├── Canvas/                 # Overlay canvas editor
│   │   ├── Timeline/               # Timeline scrubber
│   │   ├── Inspector/              # Configuration panels
│   │   ├── MainWindow/             # Main window layout
│   │   ├── Sidebar/                # Plugin catalog
│   │   └── Export/                 # Export UI
│   └── FlightTraceApp/
│       └── main.swift              # App entry point
├── Tests/
│   ├── FlightTraceCoreTests/
│   ├── FlightTracePluginsTests/
│   └── FlightTraceIntegrationTests/
└── .vscode/                        # VSCode configuration
```

## Key Features (Planned)

- ✅ Plugin-driven architecture
- ⏳ GPX file parsing with derived telemetry
- ⏳ Timeline synchronization with manual offset
- ⏳ Canvas editor with snap guides
- ⏳ 9 built-in instruments (speed, altitude, G-meter, minimap, etc.)
- ⏳ Frame-accurate video export (H.264, HEVC)
- ⏳ Dark/light mode support
- ⏳ Preset/template system

## License

(To be determined)

## Contributing

This project follows a phased development approach. Each phase is independently testable before proceeding. See TODO.md for current development priorities.
