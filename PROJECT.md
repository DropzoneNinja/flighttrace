GPS Overlay macOS Application – Project Specification

Overview

This project is a native macOS application written in Swift that generates GPS-based video overlays from GPX files. The application allows users to create modern, clean, and customizable instrument overlays such as speed, altitude, G-meter, trackline, and minimap. Instruments can be positioned freely and rendered into a final video export suitable for action sports, aviation, and outdoor activities.

The architecture must be extensible via a plugin system so that new instruments can be added later without rewriting the core application.

This document defines the functional requirements, architecture, UI expectations, and export pipeline. It is intended to be used as the primary prompt and reference when generating the application.

Target Platform and Technology

Platform: macOS (latest two major versions supported)
Language: Native Swift
UI Framework: SwiftUI preferred, AppKit only where absolutely necessary
Rendering: Core Animation, Core Graphics, or Metal if required for performance
Video Processing: AVFoundation
Architecture Pattern: MVVM with Plugin Architecture
Packaging: Sandboxed macOS application

Core Features

GPX Ingestion

The application must allow importing GPX files via a file picker or drag-and-drop.
It must parse latitude, longitude, altitude, timestamps, and any available speed data.
If speed is not present, it must be derived from positional deltas.
Vertical speed must be derived from altitude changes.
Acceleration and G-force must be derived from speed deltas.
GPX files with multiple tracks and segments must be supported.
The user must be able to select which track or segment is used.

Timeline and Synchronization

The application must display a timeline representing the GPX track duration.
The user must be able to align the GPX data with video footage using a manual offset.
The system must support trimming start and end times.
A preview scrubber must show the overlay state at any selected time index.

Plugin-Based Instrument System

The overlay system must be plugin-driven.

Each plugin must define:

A unique plugin ID

A human-readable display name

Configurable properties such as colors, units, scale, smoothing, and style

A rendering method

Data dependencies such as speed, altitude, GPS position, or heading

Default size and aspect ratio

Editable parameters exposed to the UI

Plugins must be discoverable at runtime.
Plugins must be loosely coupled to the core application.
New plugins must be addable later without modifying existing plugins or core code.

Built-In Plugins (Initial Set)

Speed gauge with analog and digital variants
Altitude or height gauge
Vertical speed indicator
G-meter
Trackline or breadcrumb trail
Minimap with heading and track
Heading or compass indicator
Time or timestamp display
Distance traveled indicator

Overlay Layout and Editor

The application must provide a canvas-based overlay editor.

The user must be able to:

Add and remove instruments

Drag instruments freely

Resize and rotate instruments

Snap instruments to guides such as edges, center, and rule-of-thirds

The editor must support Z-order control such as bring forward and send backward.
Safe-area guides must be available for common aspect ratios.
A live preview must render overlays in real time and stay synchronized with the timeline.

Styling and UI Design

The UI must be modern, clean, and minimal, consistent with macOS design standards.
Dark mode and light mode must be supported.
All instruments must be vector-based and resolution independent.
Controls must be non-intrusive and use inspector-style panels where appropriate.
Real-time preview performance is a priority.

Export Pipeline

Export Options

The user must be able to configure:

Output resolution including presets and custom sizes

Aspect ratio such as 16:9, 9:16, 1:1, and custom

Frame rate

Bitrate

Video codec including H.264 and HEVC

Container format such as MP4 or MOV

Background transparency if supported by the codec

Render quality versus speed tradeoffs

Export Process

The export must be an offline render, not a screen capture.
Rendering must be frame-accurate and deterministic.
The export process must show progress with estimated time remaining.
The user must be able to cancel an export.
Export logs must be available for debugging and diagnostics.

Data Processing

The application must support smoothing options for noisy GPS data.
Interpolation must be used for missing data points.
Unit conversion between metric and imperial systems must be supported.
Optional data normalization must be available on a per-plugin basis.

Architecture

Core Modules

GPXParser
TimelineEngine
OverlayCanvas
PluginHost
ExportEngine
VideoRenderer

Plugin Interface (Conceptual)

Plugins must be implemented as Swift modules conforming to shared protocols such as:

InstrumentPlugin

InstrumentRenderer

InstrumentConfiguration

Plugins must not directly access UI internals or video export internals.

Extensibility Goals

New instruments must be addable without touching core code.
The architecture should allow future support for:

FIT or CSV telemetry formats

Live telemetry input

Presets and templates

A plugin marketplace

There must be a clean separation between data processing, rendering, and export.

Non-Goals for Initial Version

No iOS support
No cloud synchronization
No social media sharing
No real-time live overlays

Performance Requirements

The application must provide smooth real-time previews on Apple Silicon systems.
Memory usage must be efficient for long GPX tracks.
The export pipeline must scale to long videos, including durations exceeding one hour.

Deliverables

A fully native macOS application written in Swift.
A clean, extensible codebase.
Clear documentation of the plugin API.
Sample plugins demonstrating best practices.

Guiding Principles

Precision over gimmicks.
Clean visuals suitable for aviation and sports use.
Professional-grade export quality.
Long-term extensibility as a core design goal.