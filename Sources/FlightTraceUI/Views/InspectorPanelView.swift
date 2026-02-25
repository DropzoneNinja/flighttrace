// InspectorPanelView.swift
// Inspector panel for configuring selected instrument properties

import SwiftUI
import FlightTraceCore
import FlightTracePlugins

/// Inspector panel that displays configurable properties for the selected instrument
///
/// This view dynamically generates UI controls based on the selected instrument's
/// configuration properties, allowing real-time editing without hardcoded per-plugin UI.
public struct InspectorPanelView: View {

    @Bindable var viewModel: CanvasViewModel

    public init(viewModel: CanvasViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Inspector")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Content
            if let instrument = viewModel.selectedInstrument {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Instrument Info Section
                        instrumentInfoSection(instrument: instrument)

                        Divider()

                        // Transform Section
                        transformSection(instrument: instrument)

                        Divider()

                        // Configuration Section
                        configurationPlaceholder(instrument: instrument)
                    }
                    .padding()
                }
            } else {
                // No selection placeholder
                VStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "cursorarrow.click")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Instrument Selected")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Select an instrument to view its properties")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)
    }

    // MARK: - Instrument Info Section

    @ViewBuilder
    private func instrumentInfoSection(instrument: InstrumentInstance) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Instrument Info")
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack {
                Text("Name:")
                    .foregroundColor(.secondary)
                Text(instrument.name)
                    .fontWeight(.medium)
            }
            .font(.caption)

            HStack {
                Text("Plugin ID:")
                    .foregroundColor(.secondary)
                Text(instrument.pluginID)
                    .font(.system(.caption, design: .monospaced))
            }
            .font(.caption)

            Toggle("Visible", isOn: Binding(
                get: { instrument.isVisible },
                set: { newValue in
                    viewModel.updateInstrument(id: instrument.id) { inst in
                        inst.isVisible = newValue
                    }
                }
            ))
            .font(.caption)
        }
    }

    // MARK: - Transform Section

    @ViewBuilder
    private func transformSection(instrument: InstrumentInstance) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transform")
                .font(.subheadline)
                .fontWeight(.semibold)

            // Position
            HStack {
                Text("Position")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("X")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("X", value: Binding(
                        get: { Double(instrument.position.x) },
                        set: { newValue in
                            viewModel.updateInstrument(id: instrument.id) { inst in
                                inst.position.x = CGFloat(newValue)
                            }
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Y")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("Y", value: Binding(
                        get: { Double(instrument.position.y) },
                        set: { newValue in
                            viewModel.updateInstrument(id: instrument.id) { inst in
                                inst.position.y = CGFloat(newValue)
                            }
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                }
            }

            // Size
            HStack {
                Text("Size")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Width")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("Width", value: Binding(
                        get: { Double(instrument.size.width) },
                        set: { newValue in
                            viewModel.updateInstrument(id: instrument.id) { inst in
                                inst.size.width = max(10, CGFloat(newValue))
                            }
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Height")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("Height", value: Binding(
                        get: { Double(instrument.size.height) },
                        set: { newValue in
                            viewModel.updateInstrument(id: instrument.id) { inst in
                                inst.size.height = max(10, CGFloat(newValue))
                            }
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                }
            }

            // Rotation
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Rotation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(instrument.rotation))°")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Slider(value: Binding(
                    get: { instrument.rotation },
                    set: { newValue in
                        viewModel.updateInstrument(id: instrument.id) { inst in
                            inst.rotation = newValue
                        }
                    }
                ), in: 0...360, step: 1)
            }

            // Z-Order
            HStack {
                Text("Z-Order")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(instrument.zOrder)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Configuration Section

    @ViewBuilder
    private func configurationPlaceholder(instrument: InstrumentInstance) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configuration")
                .font(.subheadline)
                .fontWeight(.semibold)

            // Get the plugin and decode configuration
            if let plugin = viewModel.plugin(withID: instrument.pluginID) {
                let config = getConfiguration(for: instrument, plugin: plugin)
                let properties = config.properties()

                if properties.isEmpty {
                    Text("No configurable properties")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(properties, id: \.key) { property in
                            configurationPropertyView(property: property, instrument: instrument)
                        }
                    }
                }
            } else {
                Text("Plugin not found")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - Configuration Helper

    private func getConfiguration(
        for instrument: InstrumentInstance,
        plugin: any InstrumentPlugin
    ) -> any InstrumentConfiguration {
        if let configData = instrument.configurationData {
            let configType = type(of: plugin.createConfiguration())
            if let decoded = try? configType.decode(from: configData) {
                return decoded
            }
        }
        return plugin.createConfiguration()
    }

    @ViewBuilder
    private func configurationPropertyView(property: ConfigurationProperty, instrument: InstrumentInstance) -> some View {
        switch property {
        case .boolean(let key, let value, let label):
            Toggle(label ?? key, isOn: Binding(
                get: { value },
                set: { newValue in
                    viewModel.updateInstrumentConfigurationProperty(
                        instrumentID: instrument.id,
                        pluginID: instrument.pluginID,
                        propertyKey: key,
                        propertyValue: newValue
                    )
                }
            ))
            .font(.caption)

        case .slider(let key, let value, let range, let step, let label):
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label ?? key)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f", value))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { value },
                    set: { newValue in
                        viewModel.updateInstrumentConfigurationProperty(
                            instrumentID: instrument.id,
                            pluginID: instrument.pluginID,
                            propertyKey: key,
                            propertyValue: newValue
                        )
                    }
                ), in: range, step: step ?? 1.0)
            }

        case .integer(let key, let value, let range, let label):
            HStack {
                Text(label ?? key)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                TextField("", value: Binding(
                    get: { value },
                    set: { newValue in
                        let clamped = range != nil ? min(max(newValue, range!.lowerBound), range!.upperBound) : newValue
                        viewModel.updateInstrumentConfigurationProperty(
                            instrumentID: instrument.id,
                            pluginID: instrument.pluginID,
                            propertyKey: key,
                            propertyValue: clamped
                        )
                    }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .frame(width: 60)
            }

        case .color(let key, let value, let label):
            HStack {
                Text(label ?? key)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                ColorPicker("", selection: Binding(
                    get: { value.color },
                    set: { newColor in
                        viewModel.updateInstrumentConfigurationProperty(
                            instrumentID: instrument.id,
                            pluginID: instrument.pluginID,
                            propertyKey: key,
                            propertyValue: SerializableColor(newColor)
                        )
                    }
                ))
                .labelsHidden()
            }

        case .enumeration(let key, let value, let options, let label):
            VStack(alignment: .leading, spacing: 4) {
                Text(label ?? key)
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Try to extract raw value using reflection
                if let valueWithRawValue = value as? any RawRepresentable,
                   let rawValue = valueWithRawValue.rawValue as? String {
                    Picker("", selection: Binding(
                        get: { rawValue },
                        set: { newRawValue in
                            print("🔍 InspectorPanel: enumeration changed for key '\(key)' to '\(newRawValue)'")
                            // Find the enum value matching the raw value
                            if let newValue = options.first(where: {
                                if let optionWithRawValue = $0 as? any RawRepresentable,
                                   let optionRawValue = optionWithRawValue.rawValue as? String {
                                    return optionRawValue == newRawValue
                                }
                                return false
                            }) {
                                print("🔍 InspectorPanel: calling updateInstrumentConfigurationProperty with enum value")
                                viewModel.updateInstrumentConfigurationProperty(
                                    instrumentID: instrument.id,
                                    pluginID: instrument.pluginID,
                                    propertyKey: key,
                                    propertyValue: newValue
                                )
                            } else {
                                print("🔍 InspectorPanel: ERROR - could not find enum value for raw value '\(newRawValue)'")
                            }
                        }
                    )) {
                        ForEach(options.compactMap { option -> String? in
                            if let optionWithRawValue = option as? any RawRepresentable,
                               let rawValue = optionWithRawValue.rawValue as? String {
                                return rawValue
                            }
                            return nil
                        }, id: \.self) { optionRawValue in
                            Text(optionRawValue).tag(optionRawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.caption)
                } else {
                    Text("Unsupported enum type")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

        default:
            Text("Unsupported property type: \(property.key)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
