// MinimapTileCache.swift
// OSM tile caching and lookup for the minimap instrument

import Foundation
import CoreGraphics
import ImageIO
import Metal
import MetalKit

#if canImport(AppKit)
import AppKit
#endif

public final class MinimapTileCache: @unchecked Sendable {
    struct TileStatus {
        let loaded: Int
        let inFlight: Int
        let failed: Int
        let timedOut: Int
        let lastError: String?
    }

    struct TileKey: Hashable {
        let z: Int
        let x: Int
        let y: Int
    }

    public static let shared = MinimapTileCache()
    public static let updateNotification = Notification.Name("MinimapTileCacheDidUpdate")

    private let ioQueue = DispatchQueue(label: "flighttrace.minimap.tiles", qos: .utility)
    private let lock = NSLock()
    private var texturesByDevice: [UInt64: [TileKey: MTLTexture]] = [:]
    private var dataCache: [TileKey: Data] = [:]
    private var dataCacheOrder: [TileKey] = []
    private let dataCacheLimit = 256
    private var inFlightByDevice: [UInt64: Set<TileKey>] = [:]
    private var inFlightStartByDevice: [UInt64: [TileKey: Date]] = [:]
    private var failedByDevice: [UInt64: [TileKey: Date]] = [:]
    private var lastErrorByDevice: [UInt64: String] = [:]
    private let session: URLSession
    private let cacheDirectory: URL
    private let retryInterval: TimeInterval = 2
    private let requestTimeout: TimeInterval = 15
    private let heartbeatInterval: TimeInterval = 1
    private var heartbeatTimer: DispatchSourceTimer?

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(memoryCapacity: 20 * 1024 * 1024, diskCapacity: 200 * 1024 * 1024)
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = requestTimeout + 5
        self.session = URLSession(configuration: configuration)

        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        self.cacheDirectory = (base ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("FlightTrace", isDirectory: true)
            .appendingPathComponent("OSMTiles", isDirectory: true)

        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
    }

    func texture(for key: TileKey, device: MTLDevice) -> MTLTexture? {
        let deviceID = device.registryID
        lock.lock()
        if let texture = texturesByDevice[deviceID]?[key] {
            lock.unlock()
            return texture
        }
        lock.unlock()

        if let cachedData = cachedTileData(for: key) {
            if let texture = makeTexture(from: cachedData, device: device) {
                store(texture: texture, key: key, deviceID: deviceID)
                return texture
            } else {
                removeCachedTileData(for: key)
            }
        }

        lock.lock()
        if inFlightByDevice[deviceID]?.contains(key) == true {
            print("MinimapTileCache: Tile in flight z\(key.z)/\(key.x)/\(key.y)")
            lock.unlock()
            return nil
        }

        if let failedAt = failedByDevice[deviceID]?[key] {
            if Date().timeIntervalSince(failedAt) < retryInterval {
                let remaining = retryInterval - Date().timeIntervalSince(failedAt)
                print("MinimapTileCache: Tile recently failed z\(key.z)/\(key.x)/\(key.y), retry in \(String(format: "%.1f", max(0, remaining)))s")
                lock.unlock()
                return nil
            } else {
                failedByDevice[deviceID]?.removeValue(forKey: key)
            }
        }

        if inFlightByDevice[deviceID] == nil {
            inFlightByDevice[deviceID] = []
        }
        inFlightByDevice[deviceID]?.insert(key)
        if inFlightStartByDevice[deviceID] == nil {
            inFlightStartByDevice[deviceID] = [:]
        }
        inFlightStartByDevice[deviceID]?[key] = Date()
        startHeartbeatIfNeededLocked()
        lock.unlock()

        print("MinimapTileCache: Scheduling request z\(key.z)/\(key.x)/\(key.y)")
        ioQueue.async { [weak self] in
            self?.loadTile(key: key, device: device, deviceID: deviceID)
        }

        return nil
    }

    private func loadTile(key: TileKey, device: MTLDevice, deviceID: UInt64) {
        let fileURL = cacheDirectory
            .appendingPathComponent("\(key.z)", isDirectory: true)
            .appendingPathComponent("\(key.x)", isDirectory: true)
            .appendingPathComponent("\(key.y).png")

        if let data = try? Data(contentsOf: fileURL) {
            if let texture = makeTexture(from: data, device: device) {
                storeCachedTileData(data, for: key)
                store(texture: texture, key: key, deviceID: deviceID)
                return
            } else {
                print("MinimapTileCache: Failed to decode cached tile z\(key.z)/\(key.x)/\(key.y) (\(data.count) bytes), deleting cache file.")
                try? FileManager.default.removeItem(at: fileURL)
            }
        }

        guard let url = tileURL(for: key) else {
            recordFailure("Invalid tile URL", key: key, deviceID: deviceID)
            return
        }

        var request = URLRequest(url: url)
        request.setValue("image/png,image/*;q=0.8,*/*;q=0.5", forHTTPHeaderField: "Accept")
        request.setValue("FlightTrace/1.0", forHTTPHeaderField: "User-Agent")

        print("MinimapTileCache: Requesting tile z\(key.z)/\(key.x)/\(key.y)")
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self, let data, !data.isEmpty else {
                if let error = error {
                    print("MinimapTileCache: Tile request failed with error: \(error.localizedDescription)")
                }
                self?.recordFailure(error?.localizedDescription ?? "No data from tile server", key: key, deviceID: deviceID)
                return
            }

            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                print("MinimapTileCache: Tile HTTP status \(http.statusCode) for z\(key.z)/\(key.x)/\(key.y)")
                self.recordFailure("HTTP \(http.statusCode)", key: key, deviceID: deviceID)
                return
            }

            if let http = response as? HTTPURLResponse,
               let contentType = http.value(forHTTPHeaderField: "Content-Type") {
                if !contentType.lowercased().starts(with: "image/") {
                    print("MinimapTileCache: Unexpected content type \(contentType) for z\(key.z)/\(key.x)/\(key.y)")
                    self.recordFailure("Unexpected content type \(contentType)", key: key, deviceID: deviceID)
                    return
                } else {
                    print("MinimapTileCache: Content-Type \(contentType) for z\(key.z)/\(key.x)/\(key.y)")
                }
            }

            if !MinimapTileCache.isLikelyImageData(data) {
                let preview = MinimapTileCache.previewText(from: data)
                print("MinimapTileCache: Non-image payload for z\(key.z)/\(key.x)/\(key.y): \(preview)")
                self.recordFailure("Non-image payload", key: key, deviceID: deviceID)
                return
            }

            let directory = fileURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            try? data.write(to: fileURL, options: .atomic)

            if let texture = self.makeTexture(from: data, device: device) {
                print("MinimapTileCache: Loaded tile z\(key.z)/\(key.x)/\(key.y) (\(data.count) bytes)")
                self.storeCachedTileData(data, for: key)
                self.store(texture: texture, key: key, deviceID: deviceID)
            } else {
                let preview = MinimapTileCache.previewText(from: data)
                print("MinimapTileCache: Failed to decode tile z\(key.z)/\(key.x)/\(key.y) (\(data.count) bytes). Preview: \(preview)")
                self.recordFailure("Failed to decode tile image", key: key, deviceID: deviceID)
            }
        }
        task.resume()
    }

    private func makeTexture(from data: Data, device: MTLDevice) -> MTLTexture? {
        // First try MTKTextureLoader directly
        if let texture = try? MTKTextureLoader(device: device).newTexture(
            data: data,
            options: [
                .SRGB: true,
                .origin: MTKTextureLoader.Origin.topLeft,
                .allocateMipmaps: false
            ]
        ) {
            return texture
        }

        if let texture = makeTextureWithCGImageSource(data: data, device: device) {
            return texture
        }

        #if canImport(AppKit)
        // Fallback: decode with NSImage/CGImage, then load CGImage into a texture.
        if let image = NSImage(data: data) {
            let size = NSSize(width: image.size.width, height: image.size.height)
            var rect = NSRect(origin: .zero, size: size)
            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) ??
                image.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
                if let texture = makeTextureFromCGImage(cgImage, device: device) {
                    return texture
                }
            }
        }
        #endif

        return nil
    }

    private func makeTextureWithCGImageSource(data: Data, device: MTLDevice) -> MTLTexture? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return makeTextureFromCGImage(cgImage, device: device)
    }

    private func makeTextureFromCGImage(_ cgImage: CGImage, device: MTLDevice) -> MTLTexture? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let dataSize = bytesPerRow * height
        var rawData = [UInt8](repeating: 0, count: dataSize)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }

        rawData.withUnsafeBytes { bytes in
            if let baseAddress = bytes.baseAddress {
                let region = MTLRegionMake2D(0, 0, width, height)
                texture.replace(region: region, mipmapLevel: 0, withBytes: baseAddress, bytesPerRow: bytesPerRow)
            }
        }

        return texture
    }

    private func store(texture: MTLTexture, key: TileKey, deviceID: UInt64) {
        lock.lock()
        var deviceTextures = texturesByDevice[deviceID] ?? [:]
        deviceTextures[key] = texture
        texturesByDevice[deviceID] = deviceTextures
        failedByDevice[deviceID]?.removeValue(forKey: key)
        finishRequestLocked(key: key, deviceID: deviceID)
        lock.unlock()

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: MinimapTileCache.updateNotification, object: nil)
        }
    }

    private func cachedTileData(for key: TileKey) -> Data? {
        lock.lock()
        let data = dataCache[key]
        lock.unlock()
        return data
    }

    private func storeCachedTileData(_ data: Data, for key: TileKey) {
        lock.lock()
        dataCache[key] = data
        if let existingIndex = dataCacheOrder.firstIndex(of: key) {
            dataCacheOrder.remove(at: existingIndex)
        }
        dataCacheOrder.append(key)
        if dataCacheOrder.count > dataCacheLimit {
            let removed = dataCacheOrder.removeFirst()
            dataCache.removeValue(forKey: removed)
        }
        lock.unlock()
    }

    private func removeCachedTileData(for key: TileKey) {
        lock.lock()
        dataCache.removeValue(forKey: key)
        if let existingIndex = dataCacheOrder.firstIndex(of: key) {
            dataCacheOrder.remove(at: existingIndex)
        }
        lock.unlock()
    }

    private func finishRequest(key: TileKey, deviceID: UInt64) {
        lock.lock()
        finishRequestLocked(key: key, deviceID: deviceID)
        lock.unlock()
    }

    private func finishRequestLocked(key: TileKey, deviceID: UInt64) {
        inFlightByDevice[deviceID]?.remove(key)
        inFlightStartByDevice[deviceID]?.removeValue(forKey: key)
        stopHeartbeatIfNeededLocked()
    }

    private func recordFailure(_ message: String, key: TileKey, deviceID: UInt64) {
        lock.lock()
        if failedByDevice[deviceID] == nil {
            failedByDevice[deviceID] = [:]
        }
        failedByDevice[deviceID]?[key] = Date()
        lastErrorByDevice[deviceID] = message
        finishRequestLocked(key: key, deviceID: deviceID)
        lock.unlock()

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: MinimapTileCache.updateNotification, object: nil)
        }
    }

    private func startHeartbeatIfNeededLocked() {
        if heartbeatTimer != nil { return }
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + heartbeatInterval, repeating: heartbeatInterval)
        timer.setEventHandler { [weak self] in
            guard self != nil else { return }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: MinimapTileCache.updateNotification, object: nil)
            }
        }
        heartbeatTimer = timer
        timer.resume()
    }

    private func stopHeartbeatIfNeededLocked() {
        let hasInFlight = inFlightByDevice.values.contains { !$0.isEmpty }
        if hasInFlight { return }
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
    }

    private func tileURL(for key: TileKey) -> URL? {
        URL(string: "https://tile.openstreetmap.org/\(key.z)/\(key.x)/\(key.y).png")
    }

    private static func isLikelyImageData(_ data: Data) -> Bool {
        let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        if data.count >= pngSignature.count {
            let prefix = [UInt8](data.prefix(pngSignature.count))
            if prefix == pngSignature { return true }
        }
        // JPEG
        if data.count >= 3 {
            let prefix3 = [UInt8](data.prefix(3))
            if prefix3[0] == 0xFF && prefix3[1] == 0xD8 && prefix3[2] == 0xFF { return true }
        }
        // GIF
        if data.count >= 3 {
            let prefix3 = [UInt8](data.prefix(3))
            if prefix3[0] == 0x47 && prefix3[1] == 0x49 && prefix3[2] == 0x46 { return true }
        }
        return false
    }

    private static func previewText(from data: Data) -> String {
        let limit = min(160, data.count)
        let slice = data.prefix(limit)
        if let text = String(data: slice, encoding: .utf8) {
            let cleaned = text
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")
            return cleaned
        }
        return "binary \(limit) bytes"
    }

    func status(for keys: [TileKey], device: MTLDevice) -> TileStatus {
        let deviceID = device.registryID
        let now = Date()
        lock.lock()
        let textures = texturesByDevice[deviceID] ?? [:]
        let inFlight = inFlightByDevice[deviceID] ?? []
        let inFlightStart = inFlightStartByDevice[deviceID] ?? [:]
        var failed = failedByDevice[deviceID] ?? [:]
        let lastError = lastErrorByDevice[deviceID]
        lock.unlock()

        var loadedCount = 0
        var inFlightCount = 0
        var failedCount = 0
        var timedOutCount = 0
        var timedOutKeys: [TileKey] = []
        for key in keys {
            if textures[key] != nil {
                loadedCount += 1
            }
            if inFlight.contains(key) {
                inFlightCount += 1
                if let started = inFlightStart[key], now.timeIntervalSince(started) > requestTimeout {
                    timedOutCount += 1
                    failed[key] = started
                    timedOutKeys.append(key)
                }
            }
            if failed[key] != nil {
                failedCount += 1
            }
        }

        if timedOutCount > 0 {
            lock.lock()
            if failedByDevice[deviceID] == nil {
                failedByDevice[deviceID] = [:]
            }
            for (key, started) in failed {
                failedByDevice[deviceID]?[key] = started
            }
            if !timedOutKeys.isEmpty {
                for key in timedOutKeys {
                    inFlightByDevice[deviceID]?.remove(key)
                    inFlightStartByDevice[deviceID]?.removeValue(forKey: key)
                }
            }
            lastErrorByDevice[deviceID] = "Tile request timed out"
            lock.unlock()
        }

        return TileStatus(
            loaded: loadedCount,
            inFlight: inFlightCount,
            failed: failedCount,
            timedOut: timedOutCount,
            lastError: lastError
        )
    }

    static func tileZoom(for zoomLevel: Double) -> Int {
        let zoom = 12.0 + (zoomLevel - 1.0) * 3.0
        return max(1, min(19, Int(round(zoom))))
    }

    static func tilesForBounds(
        minLat: Double,
        maxLat: Double,
        minLon: Double,
        maxLon: Double,
        zoom: Int
    ) -> [TileKey] {
        let clampedMinLat = max(-85.05112878, min(85.05112878, minLat))
        let clampedMaxLat = max(-85.05112878, min(85.05112878, maxLat))

        let n = Double(1 << zoom)
        let minX = Int(floor((minLon + 180.0) / 360.0 * n))
        let maxX = Int(floor((maxLon + 180.0) / 360.0 * n))

        let minY = Int(floor(latToTileY(lat: clampedMaxLat, n: n)))
        let maxY = Int(floor(latToTileY(lat: clampedMinLat, n: n)))

        let clampedMinX = max(0, min(Int(n - 1), minX))
        let clampedMaxX = max(0, min(Int(n - 1), maxX))
        let clampedMinY = max(0, min(Int(n - 1), minY))
        let clampedMaxY = max(0, min(Int(n - 1), maxY))

        guard clampedMinX <= clampedMaxX, clampedMinY <= clampedMaxY else {
            return []
        }

        var tiles: [TileKey] = []
        for x in clampedMinX...clampedMaxX {
            for y in clampedMinY...clampedMaxY {
                tiles.append(TileKey(z: zoom, x: x, y: y))
            }
        }
        return tiles
    }

    static func tileRect(for key: TileKey, viewState: MinimapViewState) -> CGRect {
        let n = Double(1 << key.z)
        let lonLeft = tileToLon(x: key.x, n: n)
        let lonRight = tileToLon(x: key.x + 1, n: n)
        let latTop = tileToLat(y: key.y, n: n)
        let latBottom = tileToLat(y: key.y + 1, n: n)

        let topLeft = viewState.transform(latTop, lonLeft)
        let bottomRight = viewState.transform(latBottom, lonRight)

        let minX = min(topLeft.x, bottomRight.x)
        let minY = min(topLeft.y, bottomRight.y)
        let maxX = max(topLeft.x, bottomRight.x)
        let maxY = max(topLeft.y, bottomRight.y)

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func latToTileY(lat: Double, n: Double) -> Double {
        let latRad = lat * Double.pi / 180.0
        let value = log(tan(Double.pi / 4 + latRad / 2))
        return (1 - value / Double.pi) / 2 * n
    }

    private static func tileToLon(x: Int, n: Double) -> Double {
        Double(x) / n * 360.0 - 180.0
    }

    private static func tileToLat(y: Int, n: Double) -> Double {
        let value = Double.pi - 2 * Double.pi * Double(y) / n
        return 180.0 / Double.pi * atan(sinh(value))
    }
}

