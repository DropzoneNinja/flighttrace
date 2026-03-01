// RenderEdgeInsets.swift
// Edge insets for render-safe areas

import Foundation
import CoreGraphics
import Combine

/// Edge insets for safe area rendering
public struct RenderEdgeInsets: Sendable, Equatable {
    public let top: CGFloat
    public let leading: CGFloat
    public let bottom: CGFloat
    public let trailing: CGFloat

    public init(top: CGFloat = 0, leading: CGFloat = 0, bottom: CGFloat = 0, trailing: CGFloat = 0) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    public static let zero = RenderEdgeInsets()
}
