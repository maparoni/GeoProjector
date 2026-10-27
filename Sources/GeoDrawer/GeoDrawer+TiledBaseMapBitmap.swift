//
//  GeoDrawer+TiledBaseMapBitmap.swift
//
//
//  Created by Adrian Schönig on 27/10/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

import Foundation

@preconcurrency import GeoProjector

extension GeoDrawer {

  /// Composites the tiled base map at the drawer's canvas size (scaled by
  /// `pixelDensity`) from the tiles already in `tileCache`, sampling each
  /// output pixel through the projection's `inverse(_:)` and the source's
  /// forward projection. Pixels outside the projection's image, outside
  /// the source's coverage, or in tiles that haven't been fetched are left
  /// transparent.
  ///
  /// Pure Swift, so it runs on Linux as well as Apple platforms. Callers
  /// are expected to have run `prefetchTiles(for:)` first; nothing is
  /// fetched here.
  func renderTiledBaseMapBitmap(_ tiledBaseMap: TiledBaseMap, zoom z: Int) -> RasterBitmap? {
    guard let projection else { return nil }

    // Render at backing-store resolution so the result downscales (rather
    // than upscales) when it's composited onto the destination.
    let width = max(1, Int((size.width * pixelDensity).rounded()))
    let height = max(1, Int((size.height * pixelDensity).rounded()))
    let bytesPerRow = width * 4
    let totalBytes = bytesPerRow * height

    let source = tiledBaseMap.source
    let sourceID = source.tileSourceID
    let n = 1 << z
    let tileSize = source.tileSize
    let totalSize = Size(width: Double(tileSize * n), height: Double(tileSize * n))

    // Snapshot the tile grid into a flat array up-front so the per-pixel
    // sampler can look up tiles by integer index — no NSLock acquire and
    // no `AnyHashable` hash per pixel. The drawer's `tileCache` is a
    // shared resource (one lock per render's tile-snapshot, not per
    // sample), and the per-pixel cost drops to a bounds-checked array
    // load.
    var tileGrid: [TileImage?] = Array(repeating: nil, count: n * n)
    for ty in 0..<n {
      for tx in 0..<n {
        let cacheKey = GeoDrawer.TileCacheKey(
          sourceID: sourceID,
          tileKey: TileKey(z: z, x: tx, y: ty)
        )
        tileGrid[ty * n + tx] = tileCache.get(cacheKey)
      }
    }

    let pixels = [UInt8](unsafeUninitializedCapacity: totalBytes) { buffer, initializedCount in
      buffer.initialize(repeating: 0)
      let context = TiledRasterContext(
        buffer: buffer.baseAddress!,
        width: width,
        bytesPerRow: bytesPerRow,
        pixelDensity: pixelDensity,
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
        tileGrid: tileGrid,
        wrapsLongitudinally: source.projection.wrapsLongitudinally
      )
      DispatchQueue.concurrentPerform(iterations: height) { py in
        context.renderRow(py)
      }
      initializedCount = totalBytes
    }

    return RasterBitmap(width: width, height: height, pixels: pixels)
  }
}

/// Captures everything the per-row compositing needs so `concurrentPerform`
/// doesn't capture the enclosing `GeoDrawer`. Marked `@unchecked Sendable`
/// because each iteration writes only to its own row of the shared output
/// buffer (no overlap, no races).
private struct TiledRasterContext: @unchecked Sendable {
  let buffer: UnsafeMutablePointer<UInt8>
  let width: Int
  let bytesPerRow: Int
  let pixelDensity: Double
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
  let sampling: GeoDrawer.Sampling
  let alpha: Double
  /// Flat row-major grid of the tiles this render needs — pre-resolved
  /// from the shared `TileCache` once, before the per-pixel sweep
  /// starts. Index is `ty * gridDimension + tx`.
  let tileGrid: [TileImage?]
  let wrapsLongitudinally: Bool

  func renderRow(_ py: Int) {
    // Convert pixel-space row to point-space so the projection's screen
    // transform (which operates in points) maps correctly.
    let pyPoints = (Double(py) + 0.5) / pixelDensity

    for px in 0..<width {
      let pxPoints = (Double(px) + 0.5) / pixelDensity

      let projected = projection.untranslate(
        Point(x: pxPoints, y: pyPoints),
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

      guard let tile = tileGrid[ty * gridDimension + tx] else { continue }

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
