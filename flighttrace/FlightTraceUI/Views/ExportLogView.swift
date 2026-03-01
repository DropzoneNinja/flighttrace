// ExportLogView.swift
// Debug log viewer for export process

import SwiftUI
import Combine
import UniformTypeIdentifiers

/// A log entry for the export process
public struct ExportLogEntry: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let level: Level
    public let message: String

    public enum Level: String, Sendable {
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case debug = "DEBUG"

        var color: Color {
            switch self {
            case .info:
                return .primary
            case .warning:
                return .orange
            case .error:
                return .red
            case .debug:
                return .secondary
            }
        }

        var icon: String {
            switch self {
            case .info:
                return "info.circle"
            case .warning:
                return "exclamationmark.triangle"
            case .error:
                return "xmark.circle"
            case .debug:
                return "ladybug"
            }
        }
    }

    public init(timestamp: Date = Date(), level: Level, message: String) {
        self.timestamp = timestamp
        self.level = level
        self.message = message
    }
}

/// Observable logger for export process
@MainActor
public class ExportLogger: ObservableObject {
    @Published public private(set) var entries: [ExportLogEntry] = []

    public init() {}

    public func log(_ message: String, level: ExportLogEntry.Level = .info) {
        let entry = ExportLogEntry(level: level, message: message)
        entries.append(entry)
    }

    public func info(_ message: String) {
        log(message, level: .info)
    }

    public func warning(_ message: String) {
        log(message, level: .warning)
    }

    public func error(_ message: String) {
        log(message, level: .error)
    }

    public func debug(_ message: String) {
        log(message, level: .debug)
    }

    public func clear() {
        entries.removeAll()
    }

    public func exportToString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"

        return entries.map { entry in
            let time = formatter.string(from: entry.timestamp)
            return "[\(time)] [\(entry.level.rawValue)] \(entry.message)"
        }.joined(separator: "\n")
    }
}

/// View for displaying export logs
@MainActor
public struct ExportLogView: View {

    @ObservedObject var logger: ExportLogger

    @State private var autoScroll: Bool = true
    @State private var filterLevel: ExportLogEntry.Level? = nil
    @State private var searchText: String = ""

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            Divider()

            // Log entries
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredEntries) { entry in
                            logEntryRow(entry)
                                .id(entry.id)
                        }
                    }
                    .padding(8)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .onChange(of: logger.entries.count) { _, _ in
                    if autoScroll, let lastEntry = logger.entries.last {
                        withAnimation {
                            proxy.scrollTo(lastEntry.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 300)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)

            Spacer()

            // Filter by level
            Menu {
                Button("All Levels") {
                    filterLevel = nil
                }

                Divider()

                ForEach([ExportLogEntry.Level.info, .warning, .error, .debug], id: \.self) { level in
                    Button {
                        filterLevel = level
                    } label: {
                        HStack {
                            Image(systemName: level.icon)
                            Text(level.rawValue)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text(filterLevel?.rawValue ?? "All")
                }
            }
            .menuStyle(.borderlessButton)
            .frame(width: 100)

            // Auto-scroll toggle
            Toggle("Auto-scroll", isOn: $autoScroll)
                .toggleStyle(.switch)
                .controlSize(.small)

            // Clear button
            Button {
                logger.clear()
            } label: {
                Image(systemName: "trash")
            }
            .help("Clear all logs")

            // Export button
            Button {
                exportLogs()
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .help("Export logs to file")
        }
        .padding(8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Log Entry Row

    private func logEntryRow(_ entry: ExportLogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp
            Text(formatTimestamp(entry.timestamp))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            // Level icon
            Image(systemName: entry.level.icon)
                .foregroundColor(entry.level.color)
                .frame(width: 20)

            // Message
            Text(entry.message)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(entry.level.color)
                .textSelection(.enabled)

            Spacer()
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
    }

    // MARK: - Filtering

    private var filteredEntries: [ExportLogEntry] {
        logger.entries.filter { entry in
            // Filter by level
            if let filterLevel = filterLevel, entry.level != filterLevel {
                return false
            }

            // Filter by search text
            if !searchText.isEmpty {
                return entry.message.localizedCaseInsensitiveContains(searchText)
            }

            return true
        }
    }

    // MARK: - Helpers

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }

    private func exportLogs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "export-log.txt"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            do {
                let logContent = logger.exportToString()
                try logContent.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                // In a real app, show an error alert
                print("Failed to export logs: \(error)")
            }
        }
    }
}

// MARK: - Preview

// Note: Previews removed for CLI compatibility
// Use in Xcode to see live previews
