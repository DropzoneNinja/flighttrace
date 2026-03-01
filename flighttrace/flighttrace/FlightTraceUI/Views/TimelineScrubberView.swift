// TimelineScrubberView.swift
// Timeline scrubber control for navigating telemetry data

import SwiftUI
import FlightTraceCore
import FlightTracePlugins

/// Timeline scrubber view for navigating through telemetry data
///
/// Provides:
/// - Visual timeline representation
/// - Playhead scrubbing
/// - Play/pause controls
/// - Current time display
public struct TimelineScrubberView: View {

    // MARK: - Properties

    /// The timeline engine to control
    @ObservedObject var timelineEngine: TimelineEngine

    // MARK: - State

    /// Whether the timeline is playing
    @State private var isPlaying = false

    /// Timer for playback
    @State private var playbackTimer: Timer?

    /// Playback speed multiplier
    @State private var playbackSpeed: Double = 1.0

    // MARK: - Constants

    private let scrubberHeight: CGFloat = 60
    private let trackHeight: CGFloat = 4
    private let thumbSize: CGFloat = 16

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 8) {
            // Timeline track with scrubber
            timelineTrack

            // Controls and info
            HStack(spacing: 16) {
                // Playback controls
                playbackControls

                Spacer()

                // Time display
                timeDisplay

                Spacer()

                // Speed controls
                speedControls
            }
            .padding(.horizontal)
        }
        .frame(height: scrubberHeight + 40)
        .background(Color(.windowBackgroundColor).opacity(0.95))
        .onDisappear {
            stopPlayback()
        }
    }

    // MARK: - Timeline Track

    private var timelineTrack: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: trackHeight)

                // Progress track
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color.blue)
                    .frame(
                        width: geometry.size.width * CGFloat(timelineEngine.currentPosition.normalizedPosition),
                        height: trackHeight
                    )

                // Playhead thumb
                Circle()
                    .fill(Color.blue)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(
                        x: geometry.size.width * CGFloat(timelineEngine.currentPosition.normalizedPosition) - thumbSize / 2
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleScrub(value: value, width: geometry.size.width)
                            }
                    )
            }
            .frame(height: scrubberHeight)
            .contentShape(Rectangle())
            .onTapGesture { location in
                handleTrackTap(location: location, width: geometry.size.width)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 12) {
            // Jump to start
            Button(action: jumpToStart) {
                Image(systemName: "backward.end.fill")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .help("Jump to start")

            // Play/Pause
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .help(isPlaying ? "Pause" : "Play")

            // Jump to end
            Button(action: jumpToEnd) {
                Image(systemName: "forward.end.fill")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .help("Jump to end")
        }
    }

    // MARK: - Time Display

    private var timeDisplay: some View {
        VStack(spacing: 2) {
            Text(formatTime(timelineEngine.currentPosition.videoTime))
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.medium)

            Text("/ \(formatTime(timelineEngine.duration))")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Speed Controls

    private var speedControls: some View {
        HStack(spacing: 8) {
            Text("Speed:")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("Speed", selection: $playbackSpeed) {
                Text("0.25×").tag(0.25)
                Text("0.5×").tag(0.5)
                Text("1×").tag(1.0)
                Text("2×").tag(2.0)
                Text("4×").tag(4.0)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
    }

    // MARK: - Gesture Handlers

    private func handleScrub(value: DragGesture.Value, width: CGFloat) {
        let normalizedPosition = max(0, min(1, value.location.x / width))
        let targetTime = normalizedPosition * timelineEngine.duration

        timelineEngine.seek(to: targetTime)

        // Pause playback while scrubbing
        if isPlaying {
            stopPlayback()
        }
    }

    private func handleTrackTap(location: CGPoint, width: CGFloat) {
        let normalizedPosition = max(0, min(1, location.x / width))
        let targetTime = normalizedPosition * timelineEngine.duration

        timelineEngine.seek(to: targetTime)
    }

    // MARK: - Playback Control

    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        isPlaying = true

        // Calculate frame duration based on playback speed
        let frameRate = 30.0 // 30 fps for smooth preview
        let frameDuration = (1.0 / frameRate) / playbackSpeed

        playbackTimer = Timer.scheduledTimer(withTimeInterval: frameDuration, repeats: true) { [weak timelineEngine] _ in
            guard let timelineEngine = timelineEngine else { return }

            Task { @MainActor in
                // Advance timeline by one frame
                let delta = (1.0 / frameRate) * self.playbackSpeed

                if timelineEngine.currentPosition.videoTime + delta >= timelineEngine.duration {
                    // Reached end - stop playback
                    self.stopPlayback()
                    timelineEngine.jumpToStart()
                } else {
                    timelineEngine.advance(by: delta)
                }
            }
        }
    }

    private func stopPlayback() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func jumpToStart() {
        stopPlayback()
        timelineEngine.jumpToStart()
    }

    private func jumpToEnd() {
        stopPlayback()
        timelineEngine.jumpToEnd()
    }

    // MARK: - Helper Methods

    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        let milliseconds = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)

        if hours > 0 {
            return String(format: "%d:%02d:%02d.%02d", hours, minutes, secs, milliseconds)
        } else {
            return String(format: "%02d:%02d.%02d", minutes, secs, milliseconds)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct TimelineScrubberView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock timeline engine with sample data
        let mockTrack = TelemetryTrack(
            name: "Sample Flight",
            points: []
        )

        @Previewable @State var engine = TimelineEngine(track: mockTrack)

        return TimelineScrubberView(timelineEngine: engine)
            .frame(width: 800)
            .padding()
            .background(Color.gray.opacity(0.2))
    }
}
#endif
