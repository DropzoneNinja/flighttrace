// PluginCatalogView.swift
// Sidebar catalog for browsing and adding instrument plugins

import SwiftUI
import FlightTraceCore
import FlightTracePlugins

/// Plugin catalog sidebar showing available instruments organized by category
///
/// This view allows users to:
/// - Browse all available plugins by category
/// - See plugin descriptions and metadata
/// - Add plugins to the canvas with a single click
public struct PluginCatalogView: View {

    @Bindable var viewModel: CanvasViewModel
    @State private var searchText = ""
    @State private var selectedCategory: PluginCategory?

    public init(viewModel: CanvasViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Instruments")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search instruments...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryFilterButton(category: nil, label: "All")

                    ForEach(PluginCategory.allCases, id: \.self) { category in
                        categoryFilterButton(category: category, label: categoryDisplayName(category))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            Divider()

            // Plugin list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(filteredPlugins.enumerated()), id: \.offset) { index, plugin in
                        pluginRow(plugin: plugin)
                        Divider()
                    }
                }
            }
        }
        .frame(minWidth: 250, idealWidth: 280, maxWidth: 350)
    }

    // MARK: - Filtered Plugins

    private var filteredPlugins: [any InstrumentPlugin] {
        let allPlugins = PluginHost.shared.allPlugins()

        // Filter by category
        var filtered = allPlugins
        if let category = selectedCategory {
            filtered = filtered.filter { type(of: $0).metadata.category == category }
        }

        // Filter by search text
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            filtered = filtered.filter { plugin in
                let pluginType = type(of: plugin)
                let metadata = pluginType.metadata
                return metadata.name.lowercased().contains(searchLower) ||
                       metadata.description.lowercased().contains(searchLower) ||
                       metadata.id.lowercased().contains(searchLower)
            }
        }

        // Sort by name
        return filtered.sorted { type(of: $0).metadata.name < type(of: $1).metadata.name }
    }

    // MARK: - Category Filter Button

    @ViewBuilder
    private func categoryFilterButton(category: PluginCategory?, label: String) -> some View {
        Button(action: {
            if selectedCategory == category {
                selectedCategory = nil
            } else {
                selectedCategory = category
            }
        }) {
            Text(label)
                .font(.caption)
                .fontWeight(selectedCategory == category ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    selectedCategory == category ?
                        Color.accentColor.opacity(0.2) :
                        Color(nsColor: .controlBackgroundColor)
                )
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            selectedCategory == category ? Color.accentColor : Color.clear,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Plugin Row

    @ViewBuilder
    private func pluginRow(plugin: any InstrumentPlugin) -> some View {
        let metadata = type(of: plugin).metadata

        Button(action: {
            addPlugin(plugin: plugin)
        }) {
            HStack(alignment: .top, spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 44, height: 44)

                    if let iconName = metadata.iconName {
                        Image(systemName: iconName)
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)
                    } else {
                        Image(systemName: defaultIcon(for: metadata.category))
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(metadata.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(metadata.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 4) {
                        Text(categoryDisplayName(metadata.category))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(4)

                        if !type(of: plugin).dataDependencies.isEmpty {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Add button
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.accentColor)
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Add \(metadata.name) to canvas")
    }

    // MARK: - Helper Methods

    /// Add a plugin to the canvas
    private func addPlugin(plugin: any InstrumentPlugin) {
        let pluginType = type(of: plugin)
        let metadata = pluginType.metadata

        // Add to canvas at center with slight offset for multiple additions
        let offset = CGFloat(viewModel.instruments.count % 5) * 20
        let position = CGPoint(
            x: (viewModel.canvasSize.width - pluginType.defaultSize.width) / 2 + offset,
            y: (viewModel.canvasSize.height - pluginType.defaultSize.height) / 2 + offset
        )

        if let instrument = viewModel.addInstrument(
            pluginID: metadata.id,
            at: position,
            configuration: plugin.createConfiguration()
        ) {
            // Select the newly added instrument
            viewModel.selectInstrument(id: instrument.id)
        }
    }

    /// Get display name for a category
    private func categoryDisplayName(_ category: PluginCategory) -> String {
        switch category {
        case .gauge:
            return "Gauges"
        case .indicator:
            return "Indicators"
        case .map:
            return "Maps"
        case .information:
            return "Info"
        case .visual:
            return "Visual"
        }
    }

    /// Get default icon for a category
    private func defaultIcon(for category: PluginCategory) -> String {
        switch category {
        case .gauge:
            return "speedometer"
        case .indicator:
            return "arrow.up.arrow.down"
        case .map:
            return "map"
        case .information:
            return "info.circle"
        case .visual:
            return "eye"
        }
    }
}

