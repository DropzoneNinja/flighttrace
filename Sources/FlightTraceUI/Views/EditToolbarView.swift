// EditToolbarView.swift
// Right-side toolbar for canvas editing modes and tools

import SwiftUI

/// Toolbar for canvas editing modes and tools
///
/// Provides:
/// - Resize mode toggle
/// - Future: Additional editing tools
struct EditToolbarView: View {

    // MARK: - Properties

    /// The canvas view model
    @Bindable var viewModel: CanvasViewModel

    // MARK: - Constants

    private let toolbarWidth: CGFloat = 60
    private let buttonSize: CGFloat = 44

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            // Resize mode toggle
            ToolButton(
                icon: "arrow.up.left.and.arrow.down.right",
                label: "Resize",
                isActive: viewModel.resizeMode,
                action: {
                    viewModel.resizeMode.toggle()
                    // Deselect when leaving resize mode
                    if !viewModel.resizeMode {
                        viewModel.deselectInstrument()
                    }
                }
            )

            Spacer()
        }
        .padding(.top, 16)
        .frame(width: toolbarWidth)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Tool Button

private struct ToolButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44)
                    .background(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(8)

                Text(label)
                    .font(.caption2)
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(isActive ? .accentColor : .primary)
        .help(label)
    }
}

// MARK: - Preview

#if DEBUG
struct EditToolbarView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = CanvasViewModel(
            canvasSize: CGSize(width: 1920, height: 1080)
        )

        EditToolbarView(viewModel: viewModel)
            .frame(height: 600)
    }
}
#endif
