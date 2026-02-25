// ExportSettingsView.swift
// UI for configuring video export settings

import SwiftUI
import FlightTraceCore

/// View for configuring export settings before starting export
@MainActor
public struct ExportSettingsView: View {

    // MARK: - Bindings

    @Binding var configuration: ExportConfiguration

    // MARK: - State

    @State private var selectedResolution: ExportConfiguration.ResolutionPreset = .hd1080p
    @State private var selectedAspectRatio: ExportConfiguration.AspectRatio? = nil
    @State private var useCustomAspectRatio: Bool = false
    @State private var customWidth: String = "16"
    @State private var customHeight: String = "9"

    @State private var selectedCodec: ExportConfiguration.Codec = .h264
    @State private var selectedFrameRate: ExportConfiguration.FrameRate = .fps30
    @State private var selectedQuality: ExportConfiguration.QualityPreset = .medium

    @State private var customResolutionWidth: String = "1920"
    @State private var customResolutionHeight: String = "1080"
    @State private var useCustomResolution: Bool = false

    @State private var transparentBackground: Bool = false
    @State private var backgroundVideoPath: String = ""

    // MARK: - Initialization

    public init(configuration: Binding<ExportConfiguration>) {
        self._configuration = configuration

        // Initialize state from configuration
        _selectedResolution = State(initialValue: configuration.wrappedValue.resolution)
        _selectedCodec = State(initialValue: configuration.wrappedValue.codec)
        _selectedFrameRate = State(initialValue: configuration.wrappedValue.frameRate)
        _selectedQuality = State(initialValue: configuration.wrappedValue.quality)
        _transparentBackground = State(initialValue: configuration.wrappedValue.transparentBackground)

        if let aspectRatio = configuration.wrappedValue.aspectRatio {
            _selectedAspectRatio = State(initialValue: aspectRatio)
            _useCustomAspectRatio = State(initialValue: true)
        }
    }

    // MARK: - Body

    public var body: some View {
        Form {
            resolutionSection
            aspectRatioSection
            videoSettingsSection
            backgroundSection
            exportSummarySection
        }
        .formStyle(.grouped)
        .onChange(of: selectedResolution) { _, _ in updateConfiguration() }
        .onChange(of: selectedAspectRatio) { _, _ in updateConfiguration() }
        .onChange(of: useCustomAspectRatio) { _, _ in updateConfiguration() }
        .onChange(of: selectedCodec) { _, _ in updateConfiguration() }
        .onChange(of: selectedFrameRate) { _, _ in updateConfiguration() }
        .onChange(of: selectedQuality) { _, _ in updateConfiguration() }
        .onChange(of: transparentBackground) { _, _ in updateConfiguration() }
        .onChange(of: customResolutionWidth) { _, _ in updateConfiguration() }
        .onChange(of: customResolutionHeight) { _, _ in updateConfiguration() }
        .onChange(of: useCustomResolution) { _, _ in updateConfiguration() }
        .onAppear {
            updateConfiguration()
        }
    }

    // MARK: - Sections

    private var resolutionSection: some View {
        Section("Resolution") {
            Picker("Preset", selection: $selectedResolution) {
                ForEach(ExportConfiguration.ResolutionPreset.presets, id: \.displayName) { preset in
                    Text(preset.displayName)
                        .tag(preset)
                }
            }

            Toggle("Custom Resolution", isOn: $useCustomResolution)

            if useCustomResolution {
                HStack {
                    TextField("Width", text: $customResolutionWidth)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    Text("×")
                    TextField("Height", text: $customResolutionHeight)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
            }

            Text(resolutionDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var aspectRatioSection: some View {
        Section("Aspect Ratio") {
            Toggle("Override Aspect Ratio", isOn: $useCustomAspectRatio)

            if useCustomAspectRatio {
                Picker("Preset", selection: $selectedAspectRatio) {
                    Text("None").tag(nil as ExportConfiguration.AspectRatio?)
                    ForEach(ExportConfiguration.AspectRatio.presets, id: \.displayName) { ratio in
                        Text(ratio.displayName)
                            .tag(ratio as ExportConfiguration.AspectRatio?)
                    }
                }
            }

            if useCustomAspectRatio, let aspectRatio = selectedAspectRatio {
                Text(aspectRatioDescription(for: aspectRatio))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var videoSettingsSection: some View {
        Section("Video Settings") {
            Picker("Codec", selection: $selectedCodec) {
                ForEach(ExportConfiguration.Codec.allCases, id: \.rawValue) { codec in
                    Text(codec.rawValue)
                        .tag(codec)
                }
            }

            Picker("Frame Rate", selection: $selectedFrameRate) {
                ForEach(ExportConfiguration.FrameRate.allCases, id: \.rawValue) { frameRate in
                    Text(frameRate.displayName)
                        .tag(frameRate)
                }
            }

            Picker("Quality", selection: $selectedQuality) {
                Text(ExportConfiguration.QualityPreset.low.displayName)
                    .tag(ExportConfiguration.QualityPreset.low)
                Text(ExportConfiguration.QualityPreset.medium.displayName)
                    .tag(ExportConfiguration.QualityPreset.medium)
                Text(ExportConfiguration.QualityPreset.high.displayName)
                    .tag(ExportConfiguration.QualityPreset.high)
            }

            Text(bitrateDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var backgroundSection: some View {
        Section("Background") {
            Toggle("Transparent Background", isOn: $transparentBackground)
                .disabled(selectedCodec != .hevc)

            if transparentBackground && selectedCodec != .hevc {
                Text("Transparent background requires HEVC codec")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }

    private var exportSummarySection: some View {
        Section("Export Summary") {
            HStack {
                Text("Output Resolution:")
                Spacer()
                Text(finalResolutionText)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Estimated Bitrate:")
                Spacer()
                Text(bitrateText)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("File Format:")
                Spacer()
                Text("MP4")
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Computed Properties

    private var resolutionDescription: String {
        if useCustomResolution,
           let width = Int(customResolutionWidth),
           let height = Int(customResolutionHeight) {
            return "\(width)×\(height) pixels"
        } else {
            let dims = selectedResolution.dimensions
            return "\(dims.width)×\(dims.height) pixels"
        }
    }

    private func aspectRatioDescription(for aspectRatio: ExportConfiguration.AspectRatio) -> String {
        let baseHeight = selectedResolution.dimensions.height
        let dims = aspectRatio.dimensions(forHeight: baseHeight)
        return "Final resolution: \(dims.width)×\(dims.height) pixels"
    }

    private var bitrateDescription: String {
        let resolution = useCustomResolution
            ? ExportConfiguration.ResolutionPreset.custom(
                width: Int(customResolutionWidth) ?? 1920,
                height: Int(customResolutionHeight) ?? 1080
              )
            : selectedResolution
        let bitrate = selectedQuality.bitrate(for: resolution)
        let mbps = Double(bitrate) / 1_000_000.0
        return String(format: "%.1f Mbps", mbps)
    }

    private var finalResolutionText: String {
        let dims = finalDimensions
        return "\(dims.width)×\(dims.height)"
    }

    private var bitrateText: String {
        bitrateDescription
    }

    private var finalDimensions: (width: Int, height: Int) {
        let resolution = useCustomResolution
            ? ExportConfiguration.ResolutionPreset.custom(
                width: Int(customResolutionWidth) ?? 1920,
                height: Int(customResolutionHeight) ?? 1080
              )
            : selectedResolution

        if useCustomAspectRatio, let aspectRatio = selectedAspectRatio {
            let baseHeight = resolution.dimensions.height
            return aspectRatio.dimensions(forHeight: baseHeight)
        } else {
            return resolution.dimensions
        }
    }

    // MARK: - Actions

    private func updateConfiguration() {
        let resolution = useCustomResolution
            ? ExportConfiguration.ResolutionPreset.custom(
                width: Int(customResolutionWidth) ?? 1920,
                height: Int(customResolutionHeight) ?? 1080
              )
            : selectedResolution

        let aspectRatio = useCustomAspectRatio ? selectedAspectRatio : nil

        configuration = ExportConfiguration(
            outputURL: configuration.outputURL,
            codec: selectedCodec,
            resolution: resolution,
            aspectRatio: aspectRatio,
            frameRate: selectedFrameRate,
            quality: selectedQuality,
            backgroundVideoURL: configuration.backgroundVideoURL,
            transparentBackground: transparentBackground && selectedCodec == .hevc,
            canvasSize: configuration.canvasSize
        )
    }
}

// MARK: - Preview

// Note: Previews removed for CLI compatibility
// Use in Xcode to see live previews
