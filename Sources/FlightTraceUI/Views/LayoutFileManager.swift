// LayoutFileManager.swift
// Helper for saving and loading canvas layouts

import SwiftUI
import UniformTypeIdentifiers

/// Manager for saving and loading canvas layout files
public struct LayoutFileManager {

    /// Save the current layout to a file
    /// - Parameters:
    ///   - viewModel: The canvas view model
    ///   - completion: Completion handler with result
    @MainActor
    public static func saveLayout(viewModel: CanvasViewModel, completion: @escaping (Result<URL, Error>) -> Void) {
        do {
            // Export layout data
            let layoutData = try viewModel.exportLayout()

            // Show save panel
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.flightTraceLayout]
            savePanel.canCreateDirectories = true
            savePanel.isExtensionHidden = false
            savePanel.title = "Save Overlay Layout"
            savePanel.message = "Choose a location to save the overlay layout"
            savePanel.nameFieldStringValue = "Overlay Layout.ftlayout"

            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    do {
                        try layoutData.write(to: url)
                        completion(.success(url))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    /// Load a layout from a file
    /// - Parameters:
    ///   - viewModel: The canvas view model
    ///   - completion: Completion handler with result
    @MainActor
    public static func loadLayout(viewModel: CanvasViewModel, completion: @escaping (Result<Void, Error>) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.flightTraceLayout]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.title = "Open Overlay Layout"
        openPanel.message = "Choose an overlay layout file to open"

        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                do {
                    let data = try Data(contentsOf: url)
                    try viewModel.importLayout(from: data)
                    completion(.success(()))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Load a layout from a specific URL
    /// - Parameters:
    ///   - url: The layout file URL
    ///   - viewModel: The canvas view model
    /// - Throws: Error if loading fails
    @MainActor
    public static func loadLayout(from url: URL, viewModel: CanvasViewModel) throws {
        let data = try Data(contentsOf: url)
        try viewModel.importLayout(from: data)
    }
}

// MARK: - FlightTrace Layout UTType

extension UTType {
    /// FlightTrace overlay layout file type
    static var flightTraceLayout: UTType {
        UTType(exportedAs: "com.flighttrace.layout", conformingTo: .json)
    }
}

// MARK: - SwiftUI Integration

/// View modifier for layout save/load actions
public struct LayoutFileActions: ViewModifier {

    @Bindable var viewModel: CanvasViewModel
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var successMessage: String?
    @State private var showSuccess = false

    public func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: $showError) {
                Button("OK") {
                    showError = false
                }
            } message: {
                Text(errorMessage ?? "Unknown error occurred")
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    showSuccess = false
                }
            } message: {
                Text(successMessage ?? "Operation completed")
            }
    }

    /// Save the current layout
    public func saveLayout() {
        LayoutFileManager.saveLayout(viewModel: viewModel) { result in
            switch result {
            case .success(let url):
                successMessage = "Layout saved to \(url.lastPathComponent)"
                showSuccess = true
            case .failure(let error):
                errorMessage = "Failed to save layout: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    /// Load a layout from file
    public func loadLayout() {
        LayoutFileManager.loadLayout(viewModel: viewModel) { result in
            switch result {
            case .success:
                successMessage = "Layout loaded successfully"
                showSuccess = true
            case .failure(let error):
                errorMessage = "Failed to load layout: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

extension View {
    /// Add layout file actions to a view
    public func layoutFileActions(viewModel: CanvasViewModel) -> some View {
        modifier(LayoutFileActions(viewModel: viewModel))
    }
}

// MARK: - Layout File Drop Support

/// View modifier for drag-and-drop layout import
public struct LayoutFileDropSupport: ViewModifier {

    @Bindable var viewModel: CanvasViewModel
    @Binding var isTargeted: Bool
    let onError: (String) -> Void

    public func body(content: Content) -> some View {
        content
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        _ = provider.loadObject(ofClass: URL.self) { url, error in
            DispatchQueue.main.async {
                if let error = error {
                    onError("Failed to load file: \(error.localizedDescription)")
                    return
                }

                guard let url = url else { return }

                // Check if it's a layout file
                let fileExtension = url.pathExtension.lowercased()
                if fileExtension != "ftlayout" {
                    onError("Invalid file type. Please select a FlightTrace layout file (.ftlayout)")
                    return
                }

                do {
                    try LayoutFileManager.loadLayout(from: url, viewModel: viewModel)
                } catch {
                    onError("Failed to load layout: \(error.localizedDescription)")
                }
            }
        }
    }
}

extension View {
    /// Add layout file drop support to a view
    public func onLayoutFileDrop(
        viewModel: CanvasViewModel,
        isTargeted: Binding<Bool>,
        onError: @escaping (String) -> Void
    ) -> some View {
        modifier(LayoutFileDropSupport(
            viewModel: viewModel,
            isTargeted: isTargeted,
            onError: onError
        ))
    }
}
