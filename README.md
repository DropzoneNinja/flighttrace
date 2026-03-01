<p align="center">
  <img src="assets/logo.png" alt="FlightTrace logo" width="220" />
</p>

# FlightTrace

FlightTrace is a native macOS application for building polished, telemetry‑driven video overlays from GPX data. It lets creators import a track, choose instruments (speed, altitude, G‑meter, minimap, etc.), compose them on a canvas, preview them against a timeline, and export frame‑accurate overlays for their footage.

## Highlights

- GPX import with derived telemetry (speed, vertical speed, distance, G‑forces)
- Canvas editor with drag/resize/rotate and snap guides
- Timeline‑driven preview for precise sync
- Metal‑based rendering for consistent output and performance
- Plugin architecture for extensible instruments

## How It Works

The project is structured into three primary modules:

- `FlightTraceCore` — GPX parsing, telemetry processing, timeline engine, export pipeline
- `FlightTracePlugins` — plugin protocols, registry, and built‑in instruments
- `FlightTraceUI` — SwiftUI interface, canvas editor, inspector, timeline, and export UI

## Requirements

- macOS 14+ (Sonoma or later)
- Xcode 15+ for building

## Build & Run

1. Open `flighttrace.xcodeproj` in Xcode.
2. Select the `flighttrace` scheme.
3. Run the app.

## Project Layout

```
flighttrace/
├── flighttraceApp.swift
├── FlightTraceCore/
├── FlightTracePlugins/
├── FlightTraceUI/
└── Assets.xcassets/
```

## Status

Active development. Expect ongoing changes to the UI, export pipeline, and plugin system.

## Contributing

Issues and draft PRs are welcome. Please include a clear description, screenshots where helpful, and sample GPX data when relevant.

## License

TBD.
