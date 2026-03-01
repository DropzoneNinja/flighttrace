// InspectorPanelView.swift
// Inspector panel for configuring selected instrument properties

import SwiftUI

#if canImport(AppKit)
import AppKit
import FlightTraceCore
import FlightTracePlugins
#endif

/// Inspector panel that displays configurable properties for the selected instrument
///
/// This view dynamically generates UI controls based on the selected instrument's
/// configuration properties, allowing real-time editing without hardcoded per-plugin UI.
public struct InspectorPanelView: View {

    @Bindable var viewModel: CanvasViewModel

    #if canImport(AppKit)
    @State private var keyMonitor: Any? = nil
    #endif

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
        .highPriorityGesture(TapGesture().onEnded {
            print("[Inspector] Root tap gesture")
            activateApp()
        })
        .onAppear {
            #if canImport(AppKit)
            print("[Inspector] InspectorPanelView appeared (NSApp.isActive=\(NSApp.isActive), windows=\(NSApp.windows.count), keyWindowTitle=\(NSApp.keyWindow?.title ?? "nil"))")
            if keyMonitor == nil {
                keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    print("[Inspector] Local keyDown: chars='\(event.characters ?? "")' windowTitle=\(event.window?.title ?? "nil") keyWindowTitle=\(NSApp.keyWindow?.title ?? "nil") isActive=\(NSApp.isActive)")
                    return event
                }
                print("[Inspector] Installed local keyDown monitor")
            }
            #else
            print("[Inspector] InspectorPanelView appeared")
            #endif
            activateApp()
        }
        .onDisappear {
            #if canImport(AppKit)
            if let keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
                self.keyMonitor = nil
                print("[Inspector] Removed local keyDown monitor")
            }
            #endif
        }
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
                    .onTapGesture {
                        #if canImport(AppKit)
                        print("[Inspector] IntegerInputField: onTapGesture (NSApp.isActive=\(NSApp.isActive))")
                        NSApp.activate(ignoringOtherApps: true)
                        if let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first {
                            print("[Inspector] IntegerInputField: making window key: \(window.title)")
                            window.makeKeyAndOrderFront(nil)
                        }
                        #else
                        print("[Inspector] IntegerInputField: onTapGesture")
                        #endif
                    }
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
                    .onTapGesture {
                        #if canImport(AppKit)
                        print("[Inspector] IntegerInputField: onTapGesture (NSApp.isActive=\(NSApp.isActive))")
                        NSApp.activate(ignoringOtherApps: true)
                        if let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first {
                            print("[Inspector] IntegerInputField: making window key: \(window.title)")
                            window.makeKeyAndOrderFront(nil)
                        }
                        #else
                        print("[Inspector] IntegerInputField: onTapGesture")
                        #endif
                    }
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
                    .onTapGesture {
                        #if canImport(AppKit)
                        print("[Inspector] IntegerInputField: onTapGesture (NSApp.isActive=\(NSApp.isActive))")
                        NSApp.activate(ignoringOtherApps: true)
                        if let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first {
                            print("[Inspector] IntegerInputField: making window key: \(window.title)")
                            window.makeKeyAndOrderFront(nil)
                        }
                        #else
                        print("[Inspector] IntegerInputField: onTapGesture")
                        #endif
                    }
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
                    .onTapGesture {
                        #if canImport(AppKit)
                        print("[Inspector] IntegerInputField: onTapGesture (NSApp.isActive=\(NSApp.isActive))")
                        NSApp.activate(ignoringOtherApps: true)
                        if let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first {
                            print("[Inspector] IntegerInputField: making window key: \(window.title)")
                            window.makeKeyAndOrderFront(nil)
                        }
                        #else
                        print("[Inspector] IntegerInputField: onTapGesture")
                        #endif
                    }
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

            // Actions
            HStack(spacing: 8) {
                Button {
                    viewModel.removeInstrument(id: instrument.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete selected instrument")

                Button {
                    viewModel.bringForward(id: instrument.id)
                } label: {
                    Label("Layer Up", systemImage: "arrow.up.square")
                }
                .buttonStyle(.borderless)
                .help("Move layer up")

                Button {
                    viewModel.sendBackward(id: instrument.id)
                } label: {
                    Label("Layer Down", systemImage: "arrow.down.square")
                }
                .buttonStyle(.borderless)
                .help("Move layer down")
            }
            .font(.caption)
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
                IntegerInputField(initialValue: value, range: range, width: 60) { newValue in
                    viewModel.updateInstrumentConfigurationProperty(
                        instrumentID: instrument.id,
                        pluginID: instrument.pluginID,
                        propertyKey: key,
                        propertyValue: newValue
                    )
                }
            }

        case .double(let key, let value, let range, let label):
            HStack {
                Text(label ?? key)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                DoubleInputField(initialValue: value, range: range, width: 80) { newValue in
                    viewModel.updateInstrumentConfigurationProperty(
                        instrumentID: instrument.id,
                        pluginID: instrument.pluginID,
                        propertyKey: key,
                        propertyValue: newValue
                    )
                }
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

    private func activateApp() {
        #if canImport(AppKit)
        print("[Inspector] activateApp() (isActive=\(NSApp.isActive), windows=\(NSApp.windows.count), keyWindowTitle=\(NSApp.keyWindow?.title ?? "nil"))")
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first {
            print("[Inspector] Making key window: \(window.title)")
            window.makeKeyAndOrderFront(nil)
        } else {
            print("[Inspector] No window to make key")
        }
        #endif
    }
}

private struct IntegerInputField: View {
    let initialValue: Int
    let range: ClosedRange<Int>?
    let width: CGFloat
    let onCommit: (Int) -> Void
    @State private var text: String
    @FocusState private var focused: Bool

    init(initialValue: Int, range: ClosedRange<Int>?, width: CGFloat, onCommit: @escaping (Int) -> Void) {
        self.initialValue = initialValue
        self.range = range
        self.width = width
        self.onCommit = onCommit
        _text = State(initialValue: String(initialValue))
    }

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.roundedBorder)
            .font(.caption)
            .frame(width: width)
            .focused($focused)
            .onTapGesture {
                #if canImport(AppKit)
                print("[Inspector] IntegerInputField: onTapGesture (NSApp.isActive=\(NSApp.isActive))")
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first {
                    print("[Inspector] IntegerInputField: making window key: \(window.title)")
                    window.makeKeyAndOrderFront(nil)
                }
                #else
                print("[Inspector] IntegerInputField: onTapGesture")
                #endif
            }
            .onSubmit {
                print("[Inspector] IntegerInputField: onSubmit")
                commit()
            }
            .onChange(of: focused) { _, isFocused in
                #if canImport(AppKit)
                print("[Inspector] IntegerInputField: focus changed -> \(isFocused) (NSApp.isActive=\(NSApp.isActive))")
                if isFocused {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first {
                        print("[Inspector] IntegerInputField: making window key: \(window.title)")
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                #else
                print("[Inspector] IntegerInputField: focus changed -> \(isFocused)")
                #endif
                if !isFocused { commit() }
            }
            .onChange(of: text) { _, newValue in
                print("[Inspector] IntegerInputField: text changed -> '\(newValue)'")
            }
            .onChange(of: initialValue) { _, newValue in
                if !focused { text = String(newValue) }
            }
    }

    private func commit() {
        print("[Inspector] IntegerInputField: commit() input='\(text)'")
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let intVal = Int(trimmed) {
            let clamped = range.map { min(max(intVal, $0.lowerBound), $0.upperBound) } ?? intVal
            print("[Inspector] IntegerInputField: parsed=\(intVal) clamped=\(clamped)")
            if clamped != initialValue { onCommit(clamped) }
            text = String(clamped)
        } else {
            print("[Inspector] IntegerInputField: invalid input, reverting to \(initialValue)")
            text = String(initialValue)
        }
    }
}

private struct DoubleInputField: View {
    let initialValue: Double
    let range: ClosedRange<Double>?
    let width: CGFloat
    let onCommit: (Double) -> Void

    @State private var text: String
    @FocusState private var focused: Bool

    init(initialValue: Double, range: ClosedRange<Double>?, width: CGFloat, onCommit: @escaping (Double) -> Void) {
        self.initialValue = initialValue
        self.range = range
        self.width = width
        self.onCommit = onCommit
        // Use a compact representation without trailing zeros
        if floor(initialValue) == initialValue {
            _text = State(initialValue: String(Int(initialValue)))
        } else {
            _text = State(initialValue: String(initialValue))
        }
    }

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.roundedBorder)
            .font(.caption)
            .frame(width: width)
            .focused($focused)
            .onTapGesture {
                #if canImport(AppKit)
                print("[Inspector] DoubleInputField: onTapGesture (NSApp.isActive=\(NSApp.isActive))")
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first {
                    print("[Inspector] DoubleInputField: making window key: \(window.title)")
                    window.makeKeyAndOrderFront(nil)
                }
                #else
                print("[Inspector] DoubleInputField: onTapGesture")
                #endif
            }
            .onSubmit {
                print("[Inspector] DoubleInputField: onSubmit")
                commit()
            }
            .onChange(of: focused) { _, isFocused in
                #if canImport(AppKit)
                print("[Inspector] DoubleInputField: focus changed -> \(isFocused) (NSApp.isActive=\(NSApp.isActive))")
                if isFocused {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first {
                        print("[Inspector] DoubleInputField: making window key: \(window.title)")
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                #else
                print("[Inspector] DoubleInputField: focus changed -> \(isFocused)")
                #endif
                if !isFocused { commit() }
            }
            .onChange(of: text) { _, newValue in
                print("[Inspector] DoubleInputField: text changed -> '\(newValue)'")
            }
            .onChange(of: initialValue) { _, newValue in
                if !focused {
                    if floor(newValue) == newValue {
                        text = String(Int(newValue))
                    } else {
                        text = String(newValue)
                    }
                }
            }
    }

    private func commit() {
        print("[Inspector] DoubleInputField: commit() input='\(text)'")
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Replace locale-specific decimal separators with dot if needed
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        if let doubleVal = Double(normalized) {
            let clamped = range.map { min(max(doubleVal, $0.lowerBound), $0.upperBound) } ?? doubleVal
            print("[Inspector] DoubleInputField: parsed=\(doubleVal) clamped=\(clamped)")
            if clamped != initialValue { onCommit(clamped) }
            if floor(clamped) == clamped {
                text = String(Int(clamped))
            } else {
                text = String(clamped)
            }
        } else {
            print("[Inspector] DoubleInputField: invalid input, reverting to \(initialValue)")
            // Revert to last known good value
            if floor(initialValue) == initialValue {
                text = String(Int(initialValue))
            } else {
                text = String(initialValue)
            }
        }
    }
}

