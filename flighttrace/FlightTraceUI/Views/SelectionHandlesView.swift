// SelectionHandlesView.swift
// Visual handles for resizing and rotating selected instruments

import SwiftUI

/// View that displays selection handles around an instrument
///
/// Provides:
/// - Corner handles for resizing
/// - Edge handles for aspect-constrained resizing
/// - Rotation handle
/// - Visual selection border
public struct SelectionHandlesView: View {

    // MARK: - Properties

    /// Size of the instrument bounds
    let size: CGSize

    /// Callback for resize operations
    let onResize: (ResizeHandle, CGSize) -> Void

    /// Callback for rotation operations
    let onRotate: (Double) -> Void

    /// Callback for dragging the entire instrument (during drag)
    let onDrag: ((CGSize) -> Void)?

    /// Callback for when dragging ends
    let onDragEnded: (() -> Void)?

    // MARK: - Constants

    private let handleSize: CGFloat = 12
    private let rotationHandleOffset: CGFloat = 30
    private let borderWidth: CGFloat = 2

    // MARK: - Resize Handle Types

    public enum ResizeHandle {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
        case top
        case bottom
        case left
        case right
    }

    // MARK: - State

    @State private var isDragging = false
    @State private var currentHandle: ResizeHandle?
    @State private var initialSize: CGSize = .zero
    @State private var isRotating = false
    @State private var lastReportedAngle: Double = 0
    @State private var isMoving = false

    // MARK: - Body

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Base rectangle for selection visual (drag only if callbacks provided)
            Color.blue.opacity(0.05)
                .frame(width: size.width, height: size.height)
                .overlay(
                    Rectangle()
                        .strokeBorder(Color.blue, lineWidth: borderWidth)
                )
                .contentShape(Rectangle())
                .if(onDrag != nil && onDragEnded != nil) { view in
                    view.gesture(
                        DragGesture()
                            .onChanged { value in
                                if !isMoving {
                                    isMoving = true
                                }
                                onDrag?(value.translation)
                            }
                            .onEnded { _ in
                                isMoving = false
                                onDragEnded?()
                            }
                    )
                }

            // Corner resize handles
            cornerHandle(.topLeft, at: CGPoint(x: 0, y: 0))
            cornerHandle(.topRight, at: CGPoint(x: size.width, y: 0))
            cornerHandle(.bottomLeft, at: CGPoint(x: 0, y: size.height))
            cornerHandle(.bottomRight, at: CGPoint(x: size.width, y: size.height))

            // Edge resize handles
            edgeHandle(.top, at: CGPoint(x: size.width / 2, y: 0))
            edgeHandle(.bottom, at: CGPoint(x: size.width / 2, y: size.height))
            edgeHandle(.left, at: CGPoint(x: 0, y: size.height / 2))
            edgeHandle(.right, at: CGPoint(x: size.width, y: size.height / 2))

            // Rotation handle
            rotationHandle(at: CGPoint(x: size.width / 2, y: -rotationHandleOffset))
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Corner Handle

    @ViewBuilder
    private func cornerHandle(_ handle: ResizeHandle, at position: CGPoint) -> some View {
        Circle()
            .fill(Color.blue)
            .frame(width: handleSize, height: handleSize)
            .overlay(
                Circle()
                    .strokeBorder(Color.white, lineWidth: 1)
            )
            .offset(x: position.x - handleSize / 2, y: position.y - handleSize / 2)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if currentHandle != handle {
                            // First change - store initial size
                            currentHandle = handle
                            initialSize = size
                        }
                        handleResizeDrag(handle: handle, translation: value.translation)
                    }
                    .onEnded { _ in
                        currentHandle = nil
                        initialSize = .zero
                    }
            )
            .cursor(.resizeCorner(handle))
    }

    // MARK: - Edge Handle

    @ViewBuilder
    private func edgeHandle(_ handle: ResizeHandle, at position: CGPoint) -> some View {
        let isHorizontal = handle == .left || handle == .right
        let handleWidth = isHorizontal ? handleSize : handleSize * 2
        let handleHeight = isHorizontal ? handleSize * 2 : handleSize

        RoundedRectangle(cornerRadius: handleSize / 2)
            .fill(Color.blue)
            .frame(width: handleWidth, height: handleHeight)
            .overlay(
                RoundedRectangle(cornerRadius: handleSize / 2)
                    .strokeBorder(Color.white, lineWidth: 1)
            )
            .offset(x: position.x - handleWidth / 2, y: position.y - handleHeight / 2)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if currentHandle != handle {
                            // First change - store initial size
                            currentHandle = handle
                            initialSize = size
                        }
                        handleResizeDrag(handle: handle, translation: value.translation)
                    }
                    .onEnded { _ in
                        currentHandle = nil
                        initialSize = .zero
                    }
            )
            .cursor(.resizeEdge(handle))
    }

    // MARK: - Rotation Handle

    @ViewBuilder
    private func rotationHandle(at position: CGPoint) -> some View {
        VStack(spacing: 2) {
            // Connecting line
            Rectangle()
                .fill(Color.blue)
                .frame(width: 2, height: rotationHandleOffset - handleSize)

            // Handle circle
            Circle()
                .fill(Color.green)
                .frame(width: handleSize, height: handleSize)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 1)
                )
                .overlay(
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 8))
                        .foregroundColor(.white)
                )
        }
        .offset(x: position.x - 1, y: position.y)
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isRotating {
                        isRotating = true
                        lastReportedAngle = 0
                    }
                    handleRotationDrag(from: value.startLocation, to: value.location)
                }
                .onEnded { _ in
                    isRotating = false
                    lastReportedAngle = 0
                }
        )
        .cursor(.rotationCursor)
    }

    // MARK: - Gesture Handlers

    private func handleResizeDrag(handle: ResizeHandle, translation: CGSize) {
        // Use initial size if available, otherwise current size
        let baseSize = initialSize != .zero ? initialSize : size

        var newSize = baseSize

        switch handle {
        case .topLeft:
            newSize.width = max(50, baseSize.width - translation.width)
            newSize.height = max(50, baseSize.height - translation.height)

        case .topRight:
            newSize.width = max(50, baseSize.width + translation.width)
            newSize.height = max(50, baseSize.height - translation.height)

        case .bottomLeft:
            newSize.width = max(50, baseSize.width - translation.width)
            newSize.height = max(50, baseSize.height + translation.height)

        case .bottomRight:
            newSize.width = max(50, baseSize.width + translation.width)
            newSize.height = max(50, baseSize.height + translation.height)

        case .top:
            newSize.width = baseSize.width
            newSize.height = max(50, baseSize.height - translation.height)

        case .bottom:
            newSize.width = baseSize.width
            newSize.height = max(50, baseSize.height + translation.height)

        case .left:
            newSize.width = max(50, baseSize.width - translation.width)
            newSize.height = baseSize.height

        case .right:
            newSize.width = max(50, baseSize.width + translation.width)
            newSize.height = baseSize.height
        }

        onResize(handle, newSize)
    }

    private func handleRotationDrag(from start: CGPoint, to current: CGPoint) {
        // Calculate angle from center of instrument
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        let startVector = CGPoint(
            x: start.x - center.x,
            y: start.y - center.y
        )

        let currentVector = CGPoint(
            x: current.x - center.x,
            y: current.y - center.y
        )

        let startAngle = atan2(startVector.y, startVector.x)
        let currentAngle = atan2(currentVector.y, currentVector.x)

        // Total rotation from drag start
        let totalDeltaAngle = (currentAngle - startAngle) * 180 / .pi

        // Calculate incremental delta since last report
        let incrementalDelta = totalDeltaAngle - lastReportedAngle

        // Update last reported angle
        lastReportedAngle = totalDeltaAngle

        // Only send the incremental change
        onRotate(incrementalDelta)
    }
}

// MARK: - View Extensions

private extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onContinuousHover { phase in
            switch phase {
            case .active:
                cursor.push()
            case .ended:
                NSCursor.pop()
            }
        }
    }

    /// Conditionally apply a transformation to the view
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

private extension NSCursor {
    static func resizeCorner(_ handle: SelectionHandlesView.ResizeHandle) -> NSCursor {
        switch handle {
        case .topLeft, .bottomRight:
            return NSCursor.init(image: NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: "Resize")!, hotSpot: CGPoint(x: 8, y: 8))
        case .topRight, .bottomLeft:
            return NSCursor.init(image: NSImage(systemSymbolName: "arrow.up.right.and.arrow.down.left", accessibilityDescription: "Resize")!, hotSpot: CGPoint(x: 8, y: 8))
        default:
            return .arrow
        }
    }

    static func resizeEdge(_ handle: SelectionHandlesView.ResizeHandle) -> NSCursor {
        switch handle {
        case .top, .bottom:
            return .resizeUpDown
        case .left, .right:
            return .resizeLeftRight
        default:
            return .arrow
        }
    }

    static var rotationCursor: NSCursor {
        NSCursor.init(image: NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Rotate")!, hotSpot: CGPoint(x: 8, y: 8))
    }
}

// MARK: - Preview

#if DEBUG
struct SelectionHandlesView_Previews: PreviewProvider {
    static var previews: some View {
        SelectionHandlesView(
            size: CGSize(width: 200, height: 150),
            onResize: { handle, newSize in
                print("Resize \(handle) to \(newSize)")
            },
            onRotate: { angle in
                print("Rotate by \(angle) degrees")
            },
            onDrag: { translation in
                print("Drag by \(translation)")
            },
            onDragEnded: {
                print("Drag ended")
            }
        )
        .frame(width: 400, height: 300)
        .background(Color.gray.opacity(0.3))
    }
}
#endif
