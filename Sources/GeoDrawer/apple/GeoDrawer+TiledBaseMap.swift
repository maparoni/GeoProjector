//
//  GeoDrawer+TiledBaseMap.swift
//
//
//  Created by Adrian Schönig on 10/5/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

#if canImport(CoreGraphics)
import CoreGraphics
import Foundation

@preconcurrency import GeoProjector

extension GeoDrawer {

  /// Resolves a `TiledBaseMap.Zoom` to an integer level using this drawer's
  /// canvas size. For `.auto`, picks the level whose source-canvas pixel
  /// density most closely matches the output canvas (via
  /// `log2(max(canvas) / tileSize)`), clamped to the source's range.
  func resolvedZoom(_ zoom: TiledBaseMap.Zoom, source: any TileSource) -> Int {
    switch zoom {
    case .fixed(let z):
      return z
    case .auto:
      let canvasMax = max(size.width, size.height)
      let raw = log2(max(canvasMax, 1) / Double(source.tileSize))
      let z = Int(raw.rounded())
      return min(max(z, source.minZoom), source.maxZoom)
    }
  }

  /// Pre-fetched tile storage keyed by `(sourceID, tileKey)`. Shared across
  /// drawer copies so successive renders against the same drawer don't
  /// re-fetch unchanged tiles.
  struct TileCacheKey: Hashable {
    let sourceID: AnyHashable
    let tileKey: TileKey
  }

  final class TileCache: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [TileCacheKey: TileImage] = [:]

    func get(_ key: TileCacheKey) -> TileImage? {
      lock.lock(); defer { lock.unlock() }
      return entries[key]
    }

    func set(_ key: TileCacheKey, _ image: TileImage) {
      lock.lock(); defer { lock.unlock() }
      entries[key] = image
    }

    func contains(_ key: TileCacheKey) -> Bool {
      lock.lock(); defer { lock.unlock() }
      return entries[key] != nil
    }
  }

  // MARK: - Pre-fetch

  /// Determines the set of tiles needed to cover the canvas at this
  /// drawer's `(projection, size, zoomTo, insets)` configuration. Samples
  /// the output canvas on a coarse grid (every `stride` pixels) so the
  /// fast path avoids iterating every output pixel; small distorted
  /// regions in pseudocylindrical projections may need a smaller stride
  /// to avoid missing isolated tiles, but the default catches the
  /// common cases (Mercator, Equirectangular, EqualEarth on a typical
  /// canvas).
  func tilesNeeded(for tiledBaseMap: TiledBaseMap, stride: Int = 16) -> Set<TileKey> {
    guard let projection else { return [] }
    let source = tiledBaseMap.source
    let z = resolvedZoom(tiledBaseMap.zoom, source: source)
    let n = 1 << z
    let totalSize = Size(
      width: Double(source.tileSize * n),
      height: Double(source.tileSize * n)
    )
    let sourceProjection = source.projection
    let outputBounds = projection.mapBounds
    let outputProjSize = projection.projectionSize

    var tiles = Set<TileKey>()
    let pixelsW = max(1, Int(size.width.rounded()))
    let pixelsH = max(1, Int(size.height.rounded()))
    let step = max(1, stride)

    // Walk the canvas in coarse strides, plus include the final row and
    // column so we always touch the right and bottom edges.
    var ys: [Int] = Array(Swift.stride(from: 0, to: pixelsH, by: step))
    if ys.last != pixelsH - 1 { ys.append(pixelsH - 1) }
    var xs: [Int] = Array(Swift.stride(from: 0, to: pixelsW, by: step))
    if xs.last != pixelsW - 1 { xs.append(pixelsW - 1) }

    for py in ys {
      for px in xs {
        let projected = projection.untranslate(
          Point(x: Double(px) + 0.5, y: Double(py) + 0.5),
          from: size, zoomTo: zoomTo, insets: insets,
          coordinateSystem: .topLeft
        )
        guard outputBounds.contains(projected, projectionSize: outputProjSize),
              let geo = projection.inverse(projected),
              let sourcePoint = sourceProjection.point(
                for: geo,
                size: totalSize,
                zoomTo: nil, insets: .zero,
                coordinateSystem: .topLeft
              )
        else { continue }

        let tx = Int(sourcePoint.x.rounded(.down)) / source.tileSize
        let ty = Int(sourcePoint.y.rounded(.down)) / source.tileSize
        if tx >= 0 && tx < n && ty >= 0 && ty < n {
          tiles.insert(TileKey(z: z, x: tx, y: ty))
        }
      }
    }
    return tiles
  }

  /// Fetches every tile in `tilesNeeded(for:)` that isn't already cached
  /// and stores the results in this drawer's tile cache. Returns when
  /// every needed tile is either resolved or known-missing. Throws on
  /// transport / decode errors; callers can choose to render partial
  /// results by ignoring the error.
  func prefetchTiles(for tiledBaseMap: TiledBaseMap) async throws {
    let needed = tilesNeeded(for: tiledBaseMap)
    let source = tiledBaseMap.source
    let sourceID = source.tileSourceID

    try await withThrowingTaskGroup(of: (TileKey, TileImage?).self) { group in
      for tileKey in needed {
        let cacheKey = TileCacheKey(sourceID: sourceID, tileKey: tileKey)
        if tileCache.contains(cacheKey) { continue }
        let added = group.addTaskUnlessCancelled {
          let tile = try await source.tile(for: tileKey)
          return (tileKey, tile)
        }
        if !added { throw CancellationError() }
      }
      for try await (tileKey, tile) in group {
        if let tile {
          tileCache.set(TileCacheKey(sourceID: sourceID, tileKey: tileKey), tile)
        }
      }
    }
  }

  // MARK: - Rasterise

  /// Cache key for the rendered raster — independent of the drawer's
  /// `(projection, size, zoomTo, insets)` tuple, which is captured by
  /// the cache instance's lifetime. Uses the *resolved* zoom level so
  /// `.auto` and `.fixed(z)` that pick the same level share a slot.
  struct TiledRasterCacheKey: Hashable {
    let sourceID: AnyHashable
    let resolvedZoom: Int
    let sampling: BaseMap.Sampling
    let alphaMilli: Int
  }

  /// Renders the tiled base map at the drawer's canvas size using the
  /// pre-fetched tiles. Pixels outside the source projection's image, or
  /// in tiles that haven't been fetched, are left transparent. The
  /// rendered raster is cached on the drawer.
  func renderedTiledBaseMap(
    _ tiledBaseMap: TiledBaseMap,
    coordinateSystem: CoordinateSystem
  ) -> CGImage? {
    let z = resolvedZoom(tiledBaseMap.zoom, source: tiledBaseMap.source)
    let cacheKey = TiledRasterCacheKey(
      sourceID: tiledBaseMap.source.tileSourceID,
      resolvedZoom: z,
      sampling: tiledBaseMap.sampling,
      alphaMilli: Int((tiledBaseMap.alpha * 1000).rounded())
    )
    if let cached = baseMapCache.getTiled(cacheKey) {
      return cached
    }
    guard let raster = renderTiledBaseMap(tiledBaseMap, zoom: z) else { return nil }
    baseMapCache.setTiled(cacheKey, raster)
    return raster
  }

  private func renderTiledBaseMap(_ tiledBaseMap: TiledBaseMap, zoom z: Int) -> CGImage? {
    guard let projection else { return nil }

    let width = max(1, Int(size.width.rounded()))
    let height = max(1, Int(size.height.rounded()))
    let bytesPerRow = width * 4
    let totalBytes = bytesPerRow * height

    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: totalBytes)
    buffer.initialize(repeating: 0, count: totalBytes)

    let source = tiledBaseMap.source
    let sourceID = source.tileSourceID
    let n = 1 << z
    let tileSize = source.tileSize
    let totalSize = Size(width: Double(tileSize * n), height: Double(tileSize * n))

    let context = TiledRasterContext(
      buffer: buffer,
      width: width,
      bytesPerRow: bytesPerRow,
      drawerSize: size,
      drawerZoom: zoomTo,
      drawerInsets: insets,
      projection: projection,
      projSize: projection.projectionSize,
      mapBounds: projection.mapBounds,
      sourceProjection: source.projection,
      sourceCanvasSize: totalSize,
      tileSize: tileSize,
      gridDimension: n,
      sampling: tiledBaseMap.sampling,
      alpha: tiledBaseMap.alpha,
      tileCache: tileCache,
      sourceID: sourceID,
      zoom: z,
      wrapsLongitudinally: source.projection.wrapsLongitudinally
    )

    DispatchQueue.concurrentPerform(iterations: height) { py in
      context.renderRow(py)
    }

    let cs = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    let provider = CGDataProvider(
      dataInfo: nil,
      data: buffer,
      size: totalBytes,
      releaseData: { _, ptr, _ in ptr.deallocate() }
    )
    guard let provider else {
      buffer.deallocate()
      return nil
    }
    return CGImage(
      width: width, height: height,
      bitsPerComponent: 8, bitsPerPixel: 32,
      bytesPerRow: bytesPerRow,
      space: cs,
      bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
      provider: provider, decode: nil,
      shouldInterpolate: false, intent: .defaultIntent
    )
  }
}

private struct TiledRasterContext: @unchecked Sendable {
  let buffer: UnsafeMutablePointer<UInt8>
  let width: Int
  let bytesPerRow: Int
  let drawerSize: Size
  let drawerZoom: Rect?
  let drawerInsets: EdgeInsets
  let projection: Projection
  let projSize: Size
  let mapBounds: MapBounds
  let sourceProjection: Projection
  let sourceCanvasSize: Size
  let tileSize: Int
  let gridDimension: Int
  let sampling: GeoDrawer.BaseMap.Sampling
  let alpha: Double
  let tileCache: GeoDrawer.TileCache
  let sourceID: AnyHashable
  let zoom: Int
  let wrapsLongitudinally: Bool

  func renderRow(_ py: Int) {
    let pyD = Double(py) + 0.5

    for px in 0..<width {
      let pxD = Double(px) + 0.5

      let projected = projection.untranslate(
        Point(x: pxD, y: pyD),
        from: drawerSize, zoomTo: drawerZoom, insets: drawerInsets,
        coordinateSystem: .topLeft
      )
      guard mapBounds.contains(projected, projectionSize: projSize),
            let geo = projection.inverse(projected),
            let sourcePoint = sourceProjection.point(
              for: geo,
              size: sourceCanvasSize,
              zoomTo: nil, insets: .zero,
              coordinateSystem: .topLeft
            )
      else { continue }

      var sxFull = sourcePoint.x
      let syFull = sourcePoint.y

      // Wrap longitude for cylindrical sources, skip otherwise.
      let totalW = sourceCanvasSize.width
      if wrapsLongitudinally {
        sxFull -= floor(sxFull / totalW) * totalW
      } else if sxFull < 0 || sxFull >= totalW {
        continue
      }
      if syFull < 0 || syFull >= sourceCanvasSize.height { continue }

      // Locate which tile covers (sxFull, syFull) and the pixel inside it.
      let tx = Int(sxFull.rounded(.down)) / tileSize
      let ty = Int(syFull.rounded(.down)) / tileSize
      if tx < 0 || tx >= gridDimension || ty < 0 || ty >= gridDimension { continue }

      let key = GeoDrawer.TileCacheKey(
        sourceID: sourceID,
        tileKey: TileKey(z: zoom, x: tx, y: ty)
      )
      guard let tile = tileCache.get(key) else { continue }

      let tileX = sxFull - Double(tx * tileSize)
      let tileY = syFull - Double(ty * tileSize)
      let pixel = sample(tile: tile, sx: tileX, sy: tileY)

      let outOff = py * bytesPerRow + px * 4
      if alpha >= 1 {
        buffer[outOff + 0] = pixel.0
        buffer[outOff + 1] = pixel.1
        buffer[outOff + 2] = pixel.2
        buffer[outOff + 3] = pixel.3
      } else {
        buffer[outOff + 0] = UInt8(min(255, max(0, (Double(pixel.0) * alpha).rounded())))
        buffer[outOff + 1] = UInt8(min(255, max(0, (Double(pixel.1) * alpha).rounded())))
        buffer[outOff + 2] = UInt8(min(255, max(0, (Double(pixel.2) * alpha).rounded())))
        buffer[outOff + 3] = UInt8(min(255, max(0, (Double(pixel.3) * alpha).rounded())))
      }
    }
  }

  private func sample(
    tile: TileImage, sx: Double, sy: Double
  ) -> (UInt8, UInt8, UInt8, UInt8) {
    let w = tile.width
    let h = tile.height
    return tile.pixels.withUnsafeBufferPointer { ptr in
      switch sampling {
      case .nearest:
        let xi = min(max(Int(sx.rounded(.down)), 0), w - 1)
        let yi = min(max(Int(sy.rounded(.down)), 0), h - 1)
        let off = (yi * w + xi) * 4
        return (ptr[off], ptr[off + 1], ptr[off + 2], ptr[off + 3])

      case .bilinear:
        let fx = sx - 0.5
        let fy = sy - 0.5
        let x0 = Int(floor(fx))
        let y0 = Int(floor(fy))
        let tx = fx - Double(x0)
        let ty = fy - Double(y0)

        // Clamp at tile boundaries. Cross-tile bilinear blending isn't
        // implemented in v1; tile edges get a 1-pixel hard seam at high
        // sampling ratios. The slippy zoom-level selection should pick a
        // zoom where the seam is sub-pixel anyway.
        let x0c = min(max(x0, 0), w - 1)
        let x1c = min(max(x0 + 1, 0), w - 1)
        let y0c = min(max(y0, 0), h - 1)
        let y1c = min(max(y0 + 1, 0), h - 1)

        let off00 = (y0c * w + x0c) * 4
        let off01 = (y0c * w + x1c) * 4
        let off10 = (y1c * w + x0c) * 4
        let off11 = (y1c * w + x1c) * 4

        func mix(_ a: UInt8, _ b: UInt8, _ t: Double) -> UInt8 {
          let v = Double(a) * (1 - t) + Double(b) * t
          return UInt8(min(255, max(0, v.rounded())))
        }
        let r = mix(mix(ptr[off00 + 0], ptr[off01 + 0], tx),
                    mix(ptr[off10 + 0], ptr[off11 + 0], tx), ty)
        let g = mix(mix(ptr[off00 + 1], ptr[off01 + 1], tx),
                    mix(ptr[off10 + 1], ptr[off11 + 1], tx), ty)
        let b = mix(mix(ptr[off00 + 2], ptr[off01 + 2], tx),
                    mix(ptr[off10 + 2], ptr[off11 + 2], tx), ty)
        let a = mix(mix(ptr[off00 + 3], ptr[off01 + 3], tx),
                    mix(ptr[off10 + 3], ptr[off11 + 3], tx), ty)
        return (r, g, b, a)
      }
    }
  }
}

#endif
