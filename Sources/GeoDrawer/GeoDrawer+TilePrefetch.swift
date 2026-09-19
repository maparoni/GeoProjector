//
//  GeoDrawer+TilePrefetch.swift
//
//
//  Created by Adrian Schönig on 10/5/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

import Foundation

@preconcurrency import GeoProjector

extension GeoDrawer {

  /// Resolves a `TiledBaseMap.Zoom` to an integer level using this drawer's
  /// canvas size. For `.auto`, picks the level whose source-canvas pixel
  /// density most closely matches the output canvas (via
  /// `log2(max(canvas) * pixelDensity / tileSize)`), clamped to the source's
  /// range. `pixelDensity` is included so Retina displays fetch the next
  /// zoom level up rather than upscaling lower-res tiles.
  func resolvedZoom(_ zoom: TiledBaseMap.Zoom, source: any TileSource) -> Int {
    switch zoom {
    case .fixed(let z):
      return z
    case .auto:
      let canvasMaxPixels = max(size.width, size.height) * pixelDensity
      let raw = log2(max(canvasMaxPixels, 1) / Double(source.tileSize))
      let z = Int(raw.rounded())
      return min(max(z, source.minZoom), source.maxZoom)
    }
  }

  // MARK: - Pre-fetch

  /// Determines the set of tiles needed to cover the canvas at this
  /// drawer's `(projection, size, zoomTo, insets, pixelDensity)`
  /// configuration.
  ///
  /// Replays the renderer's per-pixel inverse-projection sweep at the
  /// drawer's own `pixelDensity`. This *is* the renderer's hit set —
  /// no sampling shortcut, no risk of leaving tiles unfetched that the
  /// renderer then can't find in cache. Earlier implementations
  /// (canvas-stride sampling at fixed step, source-grid sampling)
  /// both missed tiles with small canvas footprints on irregular
  /// projections (Danseiji IV pole-centered was the user-visible
  /// case), so we just iterate every pixel.
  ///
  /// Cost scales with canvas area × density². Parallelised via
  /// `concurrentPerform` over rows. For a 1500×1200-pt canvas at
  /// `pixelDensity = 2.0` (~7 M iterations) this is ~50 ms on an
  /// 8-core M-series Mac.
  func tilesNeeded(for tiledBaseMap: TiledBaseMap) -> Set<TileKey> {
    guard let projection else { return [] }
    let source = tiledBaseMap.source
    let z = resolvedZoom(tiledBaseMap.zoom, source: source)
    let n = 1 << z
    let tileSize = source.tileSize
    let totalSize = Size(
      width: Double(tileSize * n),
      height: Double(tileSize * n)
    )
    let sourceProjection = source.projection
    let outputBounds = projection.mapBounds
    let outputProjSize = projection.projectionSize
    let wraps = sourceProjection.wrapsLongitudinally
    let density = max(0.1, pixelDensity)
    let width = max(1, Int((size.width * density).rounded()))
    let height = max(1, Int((size.height * density).rounded()))

    // Per-row tile sets, unioned at the end. Each row writes its own
    // slot, no synchronisation needed.
    let rowTiles = UnsafeMutablePointer<Set<TileKey>>.allocate(capacity: height)
    rowTiles.initialize(repeating: [], count: height)
    defer {
      rowTiles.deinitialize(count: height)
      rowTiles.deallocate()
    }

    let drawerSize = size
    let drawerZoom = zoomTo
    let drawerInsets = insets

    DispatchQueue.concurrentPerform(iterations: height) { py in
      let pyPoints = (Double(py) + 0.5) / density
      var local = Set<TileKey>()
      for px in 0..<width {
        let pxPoints = (Double(px) + 0.5) / density
        let projected = projection.untranslate(
          Point(x: pxPoints, y: pyPoints),
          from: drawerSize, zoomTo: drawerZoom, insets: drawerInsets,
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
        var sx = sourcePoint.x
        let sy = sourcePoint.y
        if wraps {
          sx -= floor(sx / totalSize.width) * totalSize.width
        } else if sx < 0 || sx >= totalSize.width {
          continue
        }
        if sy < 0 || sy >= totalSize.height { continue }
        let tx = Int(sx.rounded(.down)) / tileSize
        let ty = Int(sy.rounded(.down)) / tileSize
        if tx >= 0 && tx < n && ty >= 0 && ty < n {
          local.insert(TileKey(z: z, x: tx, y: ty))
        }
      }
      rowTiles[py] = local
    }

    var tiles = Set<TileKey>()
    for py in 0..<height {
      tiles.formUnion(rowTiles[py])
    }
    return tiles
  }

  /// Fetches every tile in `tilesNeeded(for:)` that isn't already cached
  /// and stores the results in this drawer's tile cache. Returns when
  /// every needed tile is either resolved or known-missing.
  ///
  /// Per-tile transport/decode errors are counted (see
  /// `TileFetchProgress.failed`) rather than re-thrown so partial
  /// coverage still renders — the caller decides whether to surface a
  /// warning. Cancellation (parent task) is honoured.
  ///
  /// Each time a tile lands (successfully), the drawer's *rendered*
  /// tiled-raster cache is invalidated for the source (when the
  /// CoreGraphics rendering layer is present) so the next draw re-renders
  /// with the newly-arrived tile. `onProgress` fires after every state
  /// change — including the initial snapshot when the call starts — so
  /// callers can drive progress UIs and schedule redraws. The caller is
  /// responsible for debouncing the resulting redraws when tiles arrive
  /// in a tight burst.
  func prefetchTiles(
    for tiledBaseMap: TiledBaseMap,
    onProgress: (@Sendable (TileFetchProgress) -> Void)? = nil
  ) async {
    let needed = tilesNeeded(for: tiledBaseMap)
    let source = tiledBaseMap.source
    let sourceID = source.tileSourceID

    // Tiles already in the cache (from a prior projection-switch) count
    // as loaded — bumps the starting fraction so the UI doesn't flash
    // back to 0% on every drag tick when most tiles are already there.
    let totalNeeded = needed.count
    var loaded = 0
    var failed = 0
    var tilesToFetch: [TileKey] = []
    tilesToFetch.reserveCapacity(needed.count)
    for tileKey in needed {
      let cacheKey = TileCacheKey(sourceID: sourceID, tileKey: tileKey)
      if tileCache.contains(cacheKey) {
        loaded += 1
      } else {
        tilesToFetch.append(tileKey)
      }
    }
    onProgress?(TileFetchProgress(total: totalNeeded, loaded: loaded, failed: failed))

    await withTaskGroup(of: TileFetchOutcome.self) { group in
      for tileKey in tilesToFetch {
        let added = group.addTaskUnlessCancelled {
          do {
            let tile = try await source.tile(for: tileKey)
            return TileFetchOutcome(key: tileKey, tile: tile, failed: false)
          } catch {
            return TileFetchOutcome(key: tileKey, tile: nil, failed: true)
          }
        }
        if !added { break }
      }
      for await outcome in group {
        if Task.isCancelled { break }
        if outcome.failed {
          failed += 1
        } else if let tile = outcome.tile {
          tileCache.set(TileCacheKey(sourceID: sourceID, tileKey: outcome.key), tile)
          // The cached rendered raster (on Apple) had partial tile
          // coverage; drop it so the next draw re-renders with the
          // newly-arrived tile. No-op on Linux where the raster cache
          // doesn't exist.
          invalidateRenderedTiledRaster(matching: sourceID)
          loaded += 1
        } else {
          // Source explicitly returned nil (no tile at that key, e.g.
          // some services skip ocean) — count as resolved, not failed.
          loaded += 1
        }
        onProgress?(TileFetchProgress(total: totalNeeded, loaded: loaded, failed: failed))
      }
    }
  }
}

private struct TileFetchOutcome: Sendable {
  let key: TileKey
  let tile: TileImage?
  let failed: Bool
}

extension GeoDrawer {
  /// Hook called when a tile arrives so the CoreGraphics-rendered raster
  /// cache can drop any stale partial-coverage entries for the source.
  /// Pure-Swift default is a no-op; the Apple-side implementation
  /// override (in `apple/GeoDrawer+RasterBaseMap.swift`) clears matching
  /// entries from `BaseMapCache`.
  func invalidateRenderedTiledRaster(matching sourceID: AnyHashable) {
#if canImport(CoreGraphics)
    baseMapCache.invalidateTiled(matching: sourceID)
#endif
  }
}
