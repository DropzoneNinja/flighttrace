// InstrumentRendererCache.swift
// Caches instrument renderers to avoid per-frame allocations

import Foundation
import Combine
import FlightTraceCore
import FlightTracePlugins

final class InstrumentRendererCache: ObservableObject {
    private var cache: [String: any InstrumentRenderer] = [:]

    func renderer(for pluginID: String, plugin: any InstrumentPlugin) -> any InstrumentRenderer {
        if let existing = cache[pluginID] {
            return existing
        }
        let renderer = plugin.createRenderer()
        cache[pluginID] = renderer
        return renderer
    }
}
