// VideoImportView.swift
// View for importing video files for background overlay

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

/// View for importing video background files
///
/// Supports:
/// - File picker (Open dialog)
/// - Drag and drop
/// - Common video formats (MP4, MOV, M4V)
public struct VideoImportView: View {

    @Bindable var viewModel: CanvasViewModel
    @State private var showFilePicker = false
    @State private var isTargeted = false
    @State private var errorMessage: String?
    @State private var videoInfo: VideoInfo?

    public init(viewModel: CanvasViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 12) {
            if viewModel.videoBackgroundURL != nil {
                // Video loaded view
                loadedVideoView
            } else {
                // Import view
                importView
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
            allowedContentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
    }

    // MARK: - Import View

    @ViewBuilder
    private var importView: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.badge.arrow.up")
                .font(.system(size: 48))
                .foregroundColor(isTargeted ? .accentColor : .secondary)

            Text("Drop video file here")
                .font(.headline)
                .foregroundColor(isTargeted ? .accentColor : .primary)

            Text("Optional: Add a video background for overlay preview")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Choose Video...") {
                showFilePicker = true
            }
            .buttonStyle(.bordered)
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
    }

    // MARK: - Loaded Video View

    @ViewBuilder
    private var loadedVideoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Video Background")
                        .font(.headline)
                    if let info = videoInfo {
                        Text(info.filename)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button("Remove") {
                    viewModel.videoBackgroundURL = nil
                    videoInfo = nil
                }
                .buttonStyle(.bordered)
            }

            if let info = videoInfo {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    infoRow(label: "Duration", value: formatDuration(info.duration))
                    infoRow(label: "Resolution", value: "\(Int(info.resolution.width)) × \(Int(info.resolution.height))")
                    infoRow(label: "Frame Rate", value: String(format: "%.2f fps", info.frameRate))
                    if let codec = info.codec {
                        infoRow(label: "Codec", value: codec)
                    }
                }
                .font(.caption)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
            Text(value)
                .fontWeight(.medium)
        }
    }

    // MARK: - File Import Handling

    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            loadVideoFile(url: url)

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

                // Check if it's a video file
                let fileExtension = url.pathExtension.lowercased()
                let videoExtensions = ["mp4", "mov", "m4v", "avi", "mkv"]
                if !videoExtensions.contains(fileExtension) {
                    errorMessage = "Invalid file type. Please select a video file."
                    return
                }

                loadVideoFile(url: url)
            }
        }
    }

    private func loadVideoFile(url: URL) {
        // Extract video metadata
        let asset = AVURLAsset(url: url)

        Task {
            do {
                // Get duration
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)

                // Get video track
                let videoTracks = try await asset.loadTracks(withMediaType: .video)
                guard let videoTrack = videoTracks.first else {
                    await MainActor.run {
                        errorMessage = "No video track found in file"
                    }
                    return
                }

                // Get resolution
                let naturalSize = try await videoTrack.load(.naturalSize)

                // Get frame rate
                let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)

                // Get codec (optional)
                var codecName: String?
                if let formatDescriptions: [CMFormatDescription] = try? await videoTrack.load(.formatDescriptions),
                   let formatDescription = formatDescriptions.first {
                    let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
                    codecName = fourCCToString(codecType)
                }

                // Update UI on main thread
                await MainActor.run {
                    viewModel.videoBackgroundURL = url
                    videoInfo = VideoInfo(
                        filename: url.lastPathComponent,
                        duration: durationSeconds,
                        resolution: naturalSize,
                        frameRate: Double(nominalFrameRate),
                        codec: codecName
                    )
                    errorMessage = nil
                }

            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load video: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    private func fourCCToString(_ value: FourCharCode) -> String {
        // Build 4 bytes from the FourCharCode and trim at the first null byte
        // to mirror C-string behavior before decoding as UTF-8.
        let bytes: [UInt8] = [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
        let end = bytes.firstIndex(of: 0) ?? bytes.endIndex
        return String(decoding: bytes[..<end], as: UTF8.self)
    }
}

// MARK: - Video Info

/// Metadata about an imported video file
private struct VideoInfo {
    let filename: String
    let duration: TimeInterval
    let resolution: CGSize
    let frameRate: Double
    let codec: String?
}

