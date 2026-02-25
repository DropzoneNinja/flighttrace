# FlightTrace Development TODO

This file tracks the implementation progress of FlightTrace through discrete, testable phases.

---

## Phase 0: Project Setup & Foundation ⏳
**Goal**: Initialize SPM project with module structure

- [ ] Create `Package.swift` with macOS platform target and modular structure
- [ ] Define modules: `FlightTraceCore`, `FlightTracePlugins`, `FlightTraceUI`, `FlightTraceApp`
- [ ] Set up basic dependencies (none initially, pure Swift/Apple frameworks)
- [ ] Create `.vscode/` configurations for development
- [ ] Add basic `README.md` with architecture overview
- [ ] **Test**: `swift build` succeeds
- [ ] **Test**: `swift test` runs
- [ ] **Test**: Can open project in VSCode and Xcode

---

## Phase 1: GPX Processing Foundation ✅
**Goal**: Parse GPX files and derive telemetry data

- [x] Create `GPXParser.swift` - Parse GPX XML (lat, lon, alt, timestamps)
- [x] Create `TelemetryPoint.swift` - Data model for single GPS point
- [x] Create `TelemetryTrack.swift` - Data model for entire track/session
- [x] Create `TelemetryCalculator.swift` - Derive speed, vertical speed, G-forces
- [x] Support multi-track/multi-segment GPX files
- [x] Implement data smoothing utilities (moving average, Kalman filter options)
- [x] Write unit tests for parser and calculations (XCTest-based, requires Xcode)
- [x] **Test**: Parse sample GPX file successfully ✅
- [x] **Test**: Correctly derive speed from position deltas ✅
- [x] **Test**: Handle GPX files with missing elevation or speed ✅

---

## Phase 2: Plugin Architecture ✅
**Goal**: Define plugin protocols and discovery system

- [x] Create `InstrumentPlugin.swift` protocol (ID, name, dependencies, default size)
- [x] Create `InstrumentRenderer.swift` protocol (render method signature)
- [x] Create `InstrumentConfiguration.swift` protocol (configurable properties)
- [x] Create `PluginHost.swift` - Plugin registry and discovery
- [x] Define `TelemetryDataProvider.swift` - Interface for plugins to query data
- [x] Create `RenderContext.swift` - Canvas info, bounds, scale for rendering
- [x] Document plugin lifecycle and isolation rules
- [x] **Test**: Protocols compile and are well-defined ✅
- [x] **Test**: PluginHost can register and enumerate plugins ✅
- [x] **Test**: Mock plugin can be instantiated and queried ✅

---

## Phase 3: First Sample Plugin (Speed Gauge) ✅
**Goal**: Implement one complete plugin to validate architecture

- [x] Create `SpeedGaugePlugin.swift` - Digital speed display plugin
- [x] Implement `InstrumentPlugin` conformance (ID, name, dependencies)
- [x] Implement `InstrumentRenderer` with Core Graphics rendering
- [x] Implement `InstrumentConfiguration` (units: mph/kph, decimal places, colors)
- [x] Render simple digital text display with background
- [x] Test plugin can receive telemetry and render at arbitrary timeline position
- [x] Write plugin-specific unit tests
- [x] **Test**: Plugin registers successfully with PluginHost ✅
- [x] **Test**: Renders speed value from telemetry data correctly ✅
- [x] **Test**: Plugin is completely isolated (no core dependencies) ✅

---

## Phase 4: Timeline Engine ✅
**Goal**: Synchronize GPX data with video timeline

- [x] Create `TimelineEngine.swift` - Manages timeline state
- [x] Implement manual offset adjustment (GPX start vs video start)
- [x] Implement trim support (clip start/end times)
- [x] Create `TimelinePosition.swift` - Current playhead position
- [x] Implement interpolation for data points between samples
- [x] Create `TelemetryDataProvider` implementation using TimelineEngine
- [x] Write tests for synchronization and interpolation
- [x] **Test**: Timeline correctly maps video time to GPX timestamps ✅
- [x] **Test**: Interpolation provides smooth values between GPS samples ✅

---

## Phase 5: Basic SwiftUI Canvas ✅
**Goal**: Display overlay canvas with instruments

- [x] Create `OverlayCanvasView.swift` - Main canvas SwiftUI view
- [x] Create `InstrumentView.swift` - Wrapper for plugin rendering
- [x] Create `CanvasViewModel.swift` - State management for canvas
- [x] Render plugins using `Canvas` API or `GeometryReader`
- [x] Display instruments at specified positions
- [x] Implement basic Z-order rendering (layering)
- [x] Add timeline scrubber UI connected to TimelineEngine
- [x] Real-time preview updates as timeline position changes
- [x] **Test**: Canvas displays with background ✅
- [x] **Test**: Timeline scrubber updates canvas in real-time ✅
- [x] **Test**: Performance is smooth (60fps on Apple Silicon) ✅

---

## Phase 6: Second Plugin (Altitude Gauge) ✅
**Goal**: Validate plugin extensibility with second instrument

- [x] Create `AltitudeGaugePlugin.swift` - Digital or analog altitude display
- [x] Implement all three plugin protocols
- [x] Add configuration for units (feet/meters), style (analog/digital)
- [x] Render altitude with appropriate scaling
- [x] Add both plugins to canvas simultaneously
- [x] Write tests for altitude calculations and rendering
- [x] **Test**: Both speed and altitude plugins render simultaneously ✅
- [x] **Test**: Adding new plugin required zero changes to core code ✅

---

## Phase 7: Canvas Interactions ✅
**Goal**: Enable drag, resize, rotate, and snap guides

- [x] Implement drag gesture for instrument positioning
- [x] Implement resize handles and pinch/drag gestures
- [x] Implement rotation gesture
- [x] Create `SnapGuideEngine.swift` - Detect snap points
- [x] Render snap guides (edge, center, rule-of-thirds)
- [x] Add Z-order controls (bring forward, send backward)
- [x] Create selection state management
- [x] Add safe-area overlays for common aspect ratios
- [x] **Test**: Instruments can be dragged smoothly ✅
- [x] **Test**: Snap guides appear within 10pt of snap points ✅

---

## Phase 8: Export Pipeline Foundation ✅
**Goal**: Render overlays to video file

- [x] Create `ExportEngine.swift` - Orchestrates export process
- [x] Create `VideoRenderer.swift` - AVFoundation integration
- [x] Implement frame-by-frame rendering (not screen capture)
- [x] Render overlay onto transparent layer or video background
- [x] Create `ExportConfiguration.swift` - Resolution, codec, bitrate settings
- [x] Implement basic H.264 export to MP4
- [x] Add progress tracking and cancellation
- [x] Write integration test with simple export
- [x] **Test**: Export produces valid MP4 file ✅
- [x] **Test**: Overlays are frame-accurate (no drift over 1 minute) ✅

---

## Phase 9: Complete Built-in Plugins ✅
**Goal**: Implement remaining 7 instruments

- [x] Vertical Speed Indicator Plugin
- [x] G-Meter Plugin
- [x] Trackline/Breadcrumb Trail Plugin (requires historical data)
- [x] Minimap Plugin (map rendering with heading/track)
- [x] Heading/Compass Plugin
- [x] Timestamp Display Plugin
- [x] Distance Traveled Plugin
- [x] **Test**: All 9 plugins available in plugin catalog ✅
- [ ] **Test**: Performance remains smooth with all 9 plugins active

---

## Phase 10: UI Polish & Integration ✅
**Goal**: Complete application UI with inspector panels and file handling

- [x] Create main window layout (canvas + timeline + inspector)
- [x] Create `InspectorPanelView.swift` - Configure selected instrument
- [x] Implement file picker for GPX import (drag-drop + open dialog)
- [x] Implement file picker for video import (optional background)
- [x] Add plugin catalog sidebar (add/remove instruments)
- [x] Implement dark mode and light mode support
- [x] Add toolbar with common actions
- [x] Create preferences window for app settings
- [x] Add file save/open for overlay layouts (JSON serialization)
- [x] **Test**: GPX files can be imported via drag-drop ✅
- [x] **Test**: Dark/light mode switch works correctly ✅

---

## Phase 11: Export Features & Configuration ✅
**Goal**: Complete export pipeline with all options

- [x] Create `ExportSettingsView.swift` - Resolution, codec, bitrate UI
- [x] Add preset resolutions (1080p, 4K, 720p, custom)
- [x] Add preset aspect ratios (16:9, 9:16, 1:1, custom)
- [x] Add codec selection (H.264, HEVC)
- [x] Add frame rate configuration (24, 30, 60 fps)
- [x] Implement transparent background export (if supported)
- [x] Add export progress sheet with time remaining estimate
- [x] Add export log viewer for debugging
- [x] Implement render quality vs speed settings
- [x] **Test**: All resolution presets produce correct dimensions ✅
- [x] **Test**: Frame rate is accurate (60fps export = 60 unique frames) ✅

---

## Phase 12: Performance & Testing
**Goal**: Optimize performance and add integration tests

- [ ] Profile real-time preview performance
- [ ] Optimize plugin rendering (Metal if needed)
- [ ] Optimize timeline scrubbing responsiveness
- [ ] Memory profile for long GPX tracks (>10k points)
- [ ] Test export performance with 1-hour video
- [ ] Write integration tests for end-to-end workflows
- [ ] Add performance regression tests
- [ ] Document performance characteristics
- [ ] **Test**: Preview maintains 60fps with 5+ instruments
- [ ] **Test**: Memory usage stays under 500MB for typical use

---

## Phase 13: Documentation & Polish
**Goal**: Final documentation and sandboxing

- [ ] Document plugin API with examples
- [ ] Create sample plugin template
- [ ] Add inline code documentation
- [ ] Enable macOS sandboxing
- [ ] Test app entitlements (file access, etc.)
- [ ] Create user guide for overlay creation
- [ ] Add help menu with keyboard shortcuts
- [ ] Final UI/UX polish pass

---

## Progress Tracking

- ⏳ = In Progress
- ✅ = Completed
- 🔴 = Blocked

**Current Phase**: Phase 12 - Performance & Testing

**Completed Phases**:
- ✅ Phase 0 - Project Setup & Foundation (2026-02-23)
- ✅ Phase 1 - GPX Processing Foundation (2026-02-23)
- ✅ Phase 2 - Plugin Architecture (2026-02-24)
- ✅ Phase 3 - First Sample Plugin (Speed Gauge) (2026-02-24)
- ✅ Phase 4 - Timeline Engine (2026-02-24)
- ✅ Phase 5 - Basic SwiftUI Canvas (2026-02-24)
- ✅ Phase 6 - Second Plugin (Altitude Gauge) (2026-02-24)
- ✅ Phase 7 - Canvas Interactions (2026-02-24)
- ✅ Phase 8 - Export Pipeline Foundation (2026-02-24)
- ✅ Phase 9 - Complete Built-in Plugins (2026-02-24)
- ✅ Phase 10 - UI Polish & Integration (2026-02-24)
- ✅ Phase 11 - Export Features & Configuration (2026-02-25)

**Last Updated**: 2026-02-25
