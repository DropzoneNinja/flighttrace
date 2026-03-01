// ExportProgressView.swift
// UI for showing export progress with time estimates

import SwiftUI
import FlightTraceCore
import FlightTracePlugins

/// View that displays export progress with detailed statistics
@MainActor
public struct ExportProgressView: View {

    // MARK: - Properties

    let progress: ExportEngine.ExportProgress
    let onCancel: () -> Void

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Exporting Video")
                .font(.headline)

            // Progress Bar
            VStack(spacing: 8) {
                ProgressView(value: progress.percentComplete, total: 100)
                    .progressViewStyle(.linear)

                Text("\(Int(progress.percentComplete))% Complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Statistics Grid
            VStack(spacing: 12) {
                statisticRow(
                    label: "Frames",
                    value: "\(progress.currentFrame) / \(progress.totalFrames)"
                )

                statisticRow(
                    label: "Elapsed Time",
                    value: formatDuration(progress.elapsedTime)
                )

                if let estimatedRemaining = progress.estimatedTimeRemaining {
                    statisticRow(
                        label: "Time Remaining",
                        value: formatDuration(estimatedRemaining)
                    )
                } else {
                    statisticRow(
                        label: "Time Remaining",
                        value: "Calculating..."
                    )
                }

                statisticRow(
                    label: "Rendering Speed",
                    value: String(format: "%.1f fps", progress.renderingFPS)
                )
            }
            .padding(.vertical)

            // Cancel Button
            Button("Cancel Export") {
                onCancel()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(24)
        .frame(width: 400)
    }

    // MARK: - Helper Views

    private func statisticRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

/// Sheet wrapper for export progress with cancellation support
@MainActor
public struct ExportProgressSheet: View {

    @Binding var isPresented: Bool
    let progress: ExportEngine.ExportProgress?
    let onCancel: () -> Void

    public init(
        isPresented: Binding<Bool>,
        progress: ExportEngine.ExportProgress?,
        onCancel: @escaping () -> Void
    ) {
        self._isPresented = isPresented
        self.progress = progress
        self.onCancel = onCancel
    }

    public var body: some View {
        if let progress = progress {
            ExportProgressView(progress: progress) {
                onCancel()
                isPresented = false
            }
        } else {
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Preparing Export...")
                    .font(.headline)
            }
            .padding(40)
            .frame(width: 400, height: 200)
        }
    }
}

// MARK: - Preview

// Note: Previews removed for CLI compatibility
// Use in Xcode to see live previews
