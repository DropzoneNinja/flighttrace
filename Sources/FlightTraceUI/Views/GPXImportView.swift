// GPXImportView.swift
// View for importing GPX files via file picker or drag-and-drop

import SwiftUI
import UniformTypeIdentifiers
import FlightTraceCore

/// View for importing GPX telemetry files
///
/// Supports:
/// - File picker (Open dialog)
/// - Drag and drop
/// - Multi-track GPX files with track selection
public struct GPXImportView: View {

    @Bindable var viewModel: CanvasViewModel
    @State private var showFilePicker = false
    @State private var showTrackSelector = false
    @State private var availableTracks: [TelemetryTrack] = []
    @State private var selectedTrackIndex: Int = 0
    @State private var isTargeted = false
    @State private var errorMessage: String?

    let onSuccess: (String) -> Void

    public init(viewModel: CanvasViewModel, onSuccess: @escaping (String) -> Void = { _ in }) {
        self.viewModel = viewModel
        self.onSuccess = onSuccess
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Drag and drop zone
            VStack(spacing: 16) {
                Image(systemName: "doc.badge.arrow.up")
                    .font(.system(size: 48))
                    .foregroundColor(isTargeted ? .accentColor : .secondary)

                Text("Drop GPX file here")
                    .font(.headline)
                    .foregroundColor(isTargeted ? .accentColor : .primary)

                Text("or")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Choose File...") {
                    showFilePicker = true
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, dash: [10, 5])
                    )
            )
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }

            // Error message
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                    Button("Dismiss") {
                        errorMessage = nil
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }
                .padding(8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.gpx],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
        .sheet(isPresented: $showTrackSelector) {
            TrackSelectorSheet(
                tracks: availableTracks,
                selectedIndex: $selectedTrackIndex,
                onSelect: { track in
                    viewModel.loadTrack(track)
                    showTrackSelector = false
                    let successMsg = "\(track.points.count) GPS points loaded (\(formatDuration(track.duration ?? 0)))"
                    onSuccess(successMsg)
                },
                onCancel: {
                    showTrackSelector = false
                }
            )
        }
    }

    // MARK: - File Import Handling

    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            loadGPXFile(url: url)

        case .failure(let error):
            errorMessage = "Failed to open file: \(error.localizedDescription)"
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        _ = provider.loadObject(ofClass: URL.self) { url, error in
            DispatchQueue.main.async {
                if let error = error {
                    errorMessage = "Failed to load file: \(error.localizedDescription)"
                    return
                }

                guard let url = url else { return }

                // Check if it's a GPX file
                let fileExtension = url.pathExtension.lowercased()
                if fileExtension != "gpx" {
                    errorMessage = "Invalid file type. Please select a GPX file."
                    return
                }

                loadGPXFile(url: url)
            }
        }
    }

    private func loadGPXFile(url: URL) {
        do {
            // Parse GPX file
            let parsedTracks = try GPXParser.parse(fileURL: url)

            if parsedTracks.isEmpty {
                errorMessage = "No tracks found in GPX file"
                return
            }

            // Process tracks to calculate derived metrics (speed, distance, etc.)
            let tracks = parsedTracks.map { TelemetryCalculator.process(track: $0, smoothing: true) }

            // If single track, load it directly
            if tracks.count == 1 {
                let track = tracks[0]

                viewModel.loadTrack(track)
                errorMessage = nil
                let successMsg = "\(track.points.count) GPS points loaded (\(formatDuration(track.duration ?? 0)))"
                onSuccess(successMsg)
            } else {
                // Multiple tracks - show selector
                availableTracks = tracks
                selectedTrackIndex = 0
                showTrackSelector = true
                errorMessage = nil
            }

        } catch let error as GPXParserError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to parse GPX file: \(error.localizedDescription)"
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

// MARK: - Track Selector Sheet

/// Sheet for selecting a track from multi-track GPX files
private struct TrackSelectorSheet: View {

    let tracks: [TelemetryTrack]
    @Binding var selectedIndex: Int
    let onSelect: (TelemetryTrack) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Select Track")
                        .font(.headline)
                    Text("This GPX file contains \(tracks.count) tracks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Track list
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
                        trackRow(index: index, track: track)
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)

                Button("Select") {
                    if selectedIndex < tracks.count {
                        onSelect(tracks[selectedIndex])
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }

    @ViewBuilder
    private func trackRow(index: Int, track: TelemetryTrack) -> some View {
        Button(action: {
            selectedIndex = index
        }) {
            HStack(alignment: .top, spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if selectedIndex == index {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 12, height: 12)
                    }
                }

                // Track info
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.name ?? "Track \(index + 1)")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if let description = track.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 12) {
                        Label("\(track.points.count) points", systemImage: "point.3.connected.trianglepath.dotted")
                        if let duration = track.duration {
                            Label(formatDuration(duration), systemImage: "clock")
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedIndex == index ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        selectedIndex == index ? Color.accentColor : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

// MARK: - GPX UTType Extension

extension UTType {
    /// GPX file type
    static var gpx: UTType {
        UTType(importedAs: "com.topografix.gpx")
    }
}

