//
//  TilePrefetchCoverageTests.swift
//
//
//  Created by Adrian Schönig on 11/5/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

#if canImport(Testing) && canImport(CoreGraphics)

import Testing
import Foundation
import CoreGraphics

import GeoJSONKit
@testable import GeoDrawer
import GeoProjector
import GeoProjectorDanseiji

/// Tests for the prefetch + render pipeline using a mock `TileSource`
/// that gives us deterministic control over which tiles load instantly,
/// which take time, and which error. Drives out the user-visible
/// behaviour that "the progress thing just doesn't work" after a
/// quality switch with mixed tile outcomes.
struct TilePrefetchCoverageTests {

  // MARK: - Mock source

  /// A `TileSource` partitioned into three buckets. Tiles in
  /// `instantTiles` return immediately. Tiles in `slowTiles` await
  /// `slowDelay` before returning. Tiles in `failingTiles` throw.
  /// Anything else returns `nil` (the source-doesn't-have-this-key
  /// case).
  final class MockTileSource: TileSource, @unchecked Sendable {
    let projection: any Projection
    let tileSize: Int
    let minZoom: Int
    let maxZoom: Int
    let tileSourceID: AnyHashable

    let instantTiles: Set<TileKey>
    let slowTiles: Set<TileKey>
    let failingTiles: Set<TileKey>
    let slowDelay: Duration

    /// Records of every `tile(for:)` invocation, in arrival order.
    /// Locked because the renderer fetches in parallel.
    private let lock = NSLock()
    private var _calls: [TileKey] = []
    var calls: [TileKey] {
      lock.lock(); defer { lock.unlock() }
      return _calls
    }

    init(
      tileSize: Int = 16,
      zoom: Int,
      instantTiles: Set<TileKey> = [],
      slowTiles: Set<TileKey> = [],
      failingTiles: Set<TileKey> = [],
      slowDelay: Duration = .milliseconds(50),
      projection: any Projection = Projections.Mercator()
    ) {
      self.projection = projection
      self.tileSize = tileSize
      self.minZoom = zoom
      self.maxZoom = zoom
      self.tileSourceID = UUID()
      self.instantTiles = instantTiles
      self.slowTiles = slowTiles
      self.failingTiles = failingTiles
      self.slowDelay = slowDelay
    }

    /// Single-colour tile for the requested bucket. The renderer reads
    /// only the byte buffer, so a solid fill is enough to differentiate
    /// success buckets visually if a test later wants to.
    private func makeTile(rgba: (UInt8, UInt8, UInt8, UInt8)) -> TileImage {
      var pixels = [UInt8](repeating: 0, count: tileSize * tileSize * 4)
      for i in stride(from: 0, to: pixels.count, by: 4) {
        pixels[i + 0] = rgba.0
        pixels[i + 1] = rgba.1
        pixels[i + 2] = rgba.2
        pixels[i + 3] = rgba.3
      }
      return TileImage(width: tileSize, height: tileSize, pixels: pixels)
    }

    func tile(for key: TileKey) async throws -> TileImage? {
      lock.lock()
      _calls.append(key)
      lock.unlock()

      if failingTiles.contains(key) {
        throw NSError(domain: "MockTileSource", code: 1, userInfo: nil)
      }
      if slowTiles.contains(key) {
        try await Task.sleep(for: slowDelay)
        return makeTile(rgba: (0, 128, 255, 255))  // blueish
      }
      if instantTiles.contains(key) {
        return makeTile(rgba: (0, 200, 0, 255))    // green
      }
      return nil
    }
  }

  // MARK: - Helpers

  /// Records every `TileFetchProgress` snapshot a prefetch emits, in
  /// order. Used to assert the call shape rather than just the final
  /// values.
  final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _snapshots: [TileFetchProgress] = []
    var snapshots: [TileFetchProgress] {
      lock.lock(); defer { lock.unlock() }
      return _snapshots
    }
    func record(_ snapshot: TileFetchProgress) {
      lock.lock()
      _snapshots.append(snapshot)
      lock.unlock()
    }
  }

  /// A small drawer sized so the Mercator output fully covers its 2×2
  /// zoom=1 source grid — every tile in `(z=1, x∈{0,1}, y∈{0,1})` is
  /// hit by at least one output pixel.
  private static func makeDrawer() -> GeoDrawer {
    GeoDrawer(
      size: .init(width: 32, height: 32),
      projection: Projections.Mercator()
    )
  }

  // MARK: - Tests

  /// Baseline: everything resolves successfully. Final progress should
  /// report (total, total, 0) and the recorder should observe one
  /// initial snapshot plus one per resolved tile.
  @Test func prefetch_allInstant_reportsCleanCompletion() async throws {
    let needed = Set([
      TileKey(z: 1, x: 0, y: 0),
      TileKey(z: 1, x: 1, y: 0),
      TileKey(z: 1, x: 0, y: 1),
      TileKey(z: 1, x: 1, y: 1),
    ])
    let source = MockTileSource(zoom: 1, instantTiles: needed)
    let tiled = GeoDrawer.TiledBaseMap(source: source, zoom: .fixed(1))
    let drawer = Self.makeDrawer()
    let recorder = ProgressRecorder()

    await drawer.prefetchTiles(for: tiled) { recorder.record($0) }

    let final = try #require(recorder.snapshots.last)
    #expect(final.total == needed.count)
    #expect(final.loaded == needed.count)
    #expect(final.failed == 0)
    #expect(final.isComplete)
    // Initial snapshot + one per tile = `total + 1` snapshots.
    #expect(recorder.snapshots.count == needed.count + 1)
  }

  /// Failed tiles must be counted, never re-thrown. Caller should see
  /// `failed > 0` and `isComplete == true` at the end.
  @Test func prefetch_failedTiles_accumulateIntoCount() async throws {
    let good = TileKey(z: 1, x: 0, y: 0)
    let bad = TileKey(z: 1, x: 1, y: 1)
    let source = MockTileSource(
      zoom: 1,
      instantTiles: [good],
      failingTiles: [bad]
    )
    // Use the actual `tilesNeeded(for:)` set so the test mirrors the
    // production prefetch's call shape — for this drawer the Mercator
    // source needs all four (z=1) tiles, two of which our mock leaves
    // out as "missing" (returns nil) and one of which fails.
    let tiled = GeoDrawer.TiledBaseMap(source: source, zoom: .fixed(1))
    let drawer = Self.makeDrawer()
    let recorder = ProgressRecorder()

    await drawer.prefetchTiles(for: tiled) { recorder.record($0) }

    let final = try #require(recorder.snapshots.last)
    #expect(final.failed == 1)
    #expect(final.isComplete)
    // Loaded + failed always equals total at completion.
    #expect(final.loaded + final.failed == final.total)
  }

  /// A render against a cache that's missing some tiles must:
  ///   - Succeed (return a non-nil CGImage).
  ///   - Leave the affected output pixels transparent (alpha == 0).
  /// This is the "tiles still in progress / failed" steady state — the
  /// renderer should *not* refuse to render just because coverage is
  /// incomplete.
  @Test func render_partialCache_leavesUncachedRegionsTransparent() throws {
    let cached = TileKey(z: 1, x: 0, y: 0)              // covers NW
    let missing = [
      TileKey(z: 1, x: 1, y: 0),                        // NE
      TileKey(z: 1, x: 0, y: 1),                        // SW
      TileKey(z: 1, x: 1, y: 1),                        // SE
    ]
    let source = MockTileSource(zoom: 1, instantTiles: [cached])

    // Hand-fill the drawer's tileCache with just the NW tile.
    let drawer = Self.makeDrawer()
    let nwTile = TileImage(
      width: source.tileSize,
      height: source.tileSize,
      pixels: {
        var p = [UInt8](repeating: 0, count: source.tileSize * source.tileSize * 4)
        for i in stride(from: 0, to: p.count, by: 4) {
          p[i + 0] = 0; p[i + 1] = 200; p[i + 2] = 0; p[i + 3] = 255  // green
        }
        return p
      }()
    )
    let nwKey = GeoDrawer.TileCacheKey(sourceID: source.tileSourceID, tileKey: cached)
    drawer.tileCache.set(nwKey, nwTile)

    let tiled = GeoDrawer.TiledBaseMap(source: source, zoom: .fixed(1), sampling: .nearest)
    let raster = try #require(drawer.renderedTiledBaseMap(tiled, coordinateSystem: .topLeft))

    let nw = Self.readPixel(raster, x: 8, y: 8)
    #expect(nw.0 < 50)
    #expect(nw.1 > 150)
    #expect(nw.2 < 50)
    #expect(nw.3 > 200)

    for (x, y) in [(24, 8), (8, 24), (24, 24)] {
      let pixel = Self.readPixel(raster, x: x, y: y)
      #expect(pixel.3 == 0, "(\(x),\(y)) should be transparent (missing tile)")
    }

    _ = missing  // referenced for clarity, not asserted directly
  }

  /// After a tile arrives, the next `renderedTiledBaseMap` call (with
  /// the rendered-raster cache invalidated, as `prefetchTiles` does
  /// internally) must reflect the newly-cached tile.
  @Test func render_afterTileArrival_picksUpNewTile() throws {
    let nw = TileKey(z: 1, x: 0, y: 0)
    let ne = TileKey(z: 1, x: 1, y: 0)
    let source = MockTileSource(zoom: 1, instantTiles: [nw, ne])

    let drawer = Self.makeDrawer()
    let greenTile = TileImage(
      width: source.tileSize, height: source.tileSize,
      pixels: {
        var p = [UInt8](repeating: 0, count: source.tileSize * source.tileSize * 4)
        for i in stride(from: 0, to: p.count, by: 4) {
          p[i + 1] = 200; p[i + 3] = 255
        }
        return p
      }()
    )
    let nwCacheKey = GeoDrawer.TileCacheKey(sourceID: source.tileSourceID, tileKey: nw)
    drawer.tileCache.set(nwCacheKey, greenTile)

    let tiled = GeoDrawer.TiledBaseMap(source: source, zoom: .fixed(1), sampling: .nearest)
    let first = try #require(drawer.renderedTiledBaseMap(tiled, coordinateSystem: .topLeft))
    #expect(Self.readPixel(first, x: 24, y: 8).3 == 0, "NE empty initially")

    // Tile arrives.
    let blueTile = TileImage(
      width: source.tileSize, height: source.tileSize,
      pixels: {
        var p = [UInt8](repeating: 0, count: source.tileSize * source.tileSize * 4)
        for i in stride(from: 0, to: p.count, by: 4) {
          p[i + 2] = 200; p[i + 3] = 255
        }
        return p
      }()
    )
    let neCacheKey = GeoDrawer.TileCacheKey(sourceID: source.tileSourceID, tileKey: ne)
    drawer.tileCache.set(neCacheKey, blueTile)
    // Match production: `prefetchTiles` invalidates the rendered
    // raster cache on every tile arrival so the next render rebuilds
    // its tileGrid snapshot.
    drawer.baseMapCache.invalidateTiled(matching: source.tileSourceID)

    let second = try #require(drawer.renderedTiledBaseMap(tiled, coordinateSystem: .topLeft))
    let ne_pixel = Self.readPixel(second, x: 24, y: 8)
    #expect(ne_pixel.2 > 150, "NE should now be blue")
    #expect(ne_pixel.3 > 200)
  }

  /// End-to-end: prefetch with mixed outcomes, then render. The render
  /// should reflect everything that landed in the cache, even though
  /// `prefetchTiles` reported a non-zero `failed` count.
  @Test func prefetch_thenRender_partialOutcomesProduceCoverage() async throws {
    let nw = TileKey(z: 1, x: 0, y: 0)
    let ne = TileKey(z: 1, x: 1, y: 0)
    let sw = TileKey(z: 1, x: 0, y: 1)
    let se = TileKey(z: 1, x: 1, y: 1)
    let source = MockTileSource(
      zoom: 1,
      instantTiles: [nw],
      slowTiles: [ne],
      failingTiles: [se]
      // sw → nil
    )
    let tiled = GeoDrawer.TiledBaseMap(source: source, zoom: .fixed(1), sampling: .nearest)
    let drawer = Self.makeDrawer()

    let recorder = ProgressRecorder()
    await drawer.prefetchTiles(for: tiled) { recorder.record($0) }

    let final = try #require(recorder.snapshots.last)
    #expect(final.isComplete)
    #expect(final.failed == 1, "exactly one tile should be reported as failed: \(final)")
    // loaded covers everything that wasn't a throw — `nw` (instant),
    // `ne` (slow but succeeds), `sw` (source returned nil — counted
    // as resolved rather than failed). So loaded == 3.
    #expect(final.loaded == 3)

    let raster = try #require(drawer.renderedTiledBaseMap(tiled, coordinateSystem: .topLeft))
    // NW: instant → cached → rendered.
    #expect(Self.readPixel(raster, x: 8, y: 8).3 > 200, "NW should be opaque")
    // NE: slow but eventually succeeded → cached → rendered.
    #expect(Self.readPixel(raster, x: 24, y: 8).3 > 200, "NE should be opaque after slow load")
    // SW: source returned nil → not cached → transparent.
    #expect(Self.readPixel(raster, x: 8, y: 24).3 == 0, "SW (nil) should be transparent")
    // SE: source threw → not cached → transparent.
    #expect(Self.readPixel(raster, x: 24, y: 24).3 == 0, "SE (failed) should be transparent")
  }

  /// Reproduces the user-visible flow: render Draft to seed the
  /// shared tileCache, then build a *fresh* drawer sharing the same
  /// cache (mirroring `GeoMapView.cycleDrawer`) and render at Display
  /// density. Any opacity that Draft produces must also be opaque in
  /// Display — anything else is the "stuck with gaps" symptom.
  ///
  /// Uses the same projection / canvas shape the user reported
  /// (Danseiji IV with reference pinned at the pole). All tiles are
  /// "instant" so success is on the library, not the network.
  @Test func qualitySwitch_displayCovers_everywhereDraftCovers() async throws {
    let canvas = Size(width: 480, height: 360)
    let projection: any Projection = Projections.DanseijiIV(
      reference: GeoJSON.Position(latitude: 90, longitude: 0)
    )
    let zoom = 3
    let n = 1 << zoom
    let allTiles: Set<TileKey> = Set((0..<n).flatMap { ty in
      (0..<n).map { tx in TileKey(z: zoom, x: tx, y: ty) }
    })
    let source = MockTileSource(tileSize: 32, zoom: zoom, instantTiles: allTiles)
    let tiled = GeoDrawer.TiledBaseMap(source: source, zoom: .fixed(zoom), sampling: .nearest)
    let sharedCache = GeoDrawer.TileCache()

    // Draft: pixelDensity 0.5, fresh drawer, shared cache.
    var draft = GeoDrawer(size: canvas, projection: projection)
    draft.tileCache = sharedCache
    draft.pixelDensity = 0.5
    await draft.prefetchTiles(for: tiled) { _ in }
    let draftRaster = try #require(draft.renderedTiledBaseMap(tiled, coordinateSystem: .topLeft))

    // Display: pixelDensity 2.0, fresh drawer (matches cycleDrawer),
    // same shared cache.
    var display = GeoDrawer(size: canvas, projection: projection)
    display.tileCache = sharedCache
    display.pixelDensity = 2.0
    await display.prefetchTiles(for: tiled) { _ in }
    let displayRaster = try #require(display.renderedTiledBaseMap(tiled, coordinateSystem: .topLeft))

    // Sample on the canvas — anywhere Draft is opaque, Display must
    // be opaque too. Walk both rasters on a coarse grid sufficient to
    // catch the wedge-shaped gaps the user reported.
    let dW = draftRaster.width
    let dH = draftRaster.height
    let xW = displayRaster.width
    let xH = displayRaster.height
    let draftBytes = Self.readAll(draftRaster)
    let displayBytes = Self.readAll(displayRaster)
    let step = 4

    // Find every Display pixel that's transparent but where the
    // renderer's per-pixel logic *would* have wanted a tile (i.e.
    // inside both the canvas and the projection's `mapBounds`).
    // Boundary-edge artifacts — pixels the renderer correctly skips
    // because they're outside `mapBounds` at this density — don't
    // count as bugs.
    let tileSize = source.tileSize
    let totalSize = Size(
      width: Double(tileSize * n),
      height: Double(tileSize * n)
    )
    var realGaps: [(Int, Int, TileKey)] = []
    let needed = display.tilesNeeded(for: tiled)

    for dy in stride(from: 0, to: xH, by: step) {
      for dx in stride(from: 0, to: xW, by: step) {
        let displayA = displayBytes[(dy * xW + dx) * 4 + 3]
        guard displayA < 100 else { continue }
        // Re-derive what the renderer would have computed for this
        // pixel — if it would have skipped (mapBounds, inverse,
        // etc.), the transparency is correct, not a gap.
        let pxPoints = (Double(dx) + 0.5) / 2.0
        let pyPoints = (Double(dy) + 0.5) / 2.0
        let projected = projection.untranslate(
          Point(x: pxPoints, y: pyPoints),
          from: canvas, zoomTo: nil, insets: .zero,
          coordinateSystem: .topLeft
        )
        guard projection.mapBounds.contains(projected, projectionSize: projection.projectionSize),
              let geo = projection.inverse(projected),
              let sp = source.projection.point(
                for: geo,
                size: totalSize,
                zoomTo: nil, insets: .zero,
                coordinateSystem: .topLeft
              )
        else { continue }
        var sx = sp.x
        let sy = sp.y
        if source.projection.wrapsLongitudinally {
          sx -= floor(sx / totalSize.width) * totalSize.width
        } else if sx < 0 || sx >= totalSize.width { continue }
        if sy < 0 || sy >= totalSize.height { continue }
        let tx = Int(sx.rounded(.down)) / tileSize
        let ty = Int(sy.rounded(.down)) / tileSize
        guard tx >= 0, tx < n, ty >= 0, ty < n else { continue }
        let key = TileKey(z: zoom, x: tx, y: ty)
        realGaps.append((dx, dy, key))
      }
    }

    if !realGaps.isEmpty {
      let (dx, dy, key) = realGaps[0]
      let cacheKey = GeoDrawer.TileCacheKey(sourceID: source.tileSourceID, tileKey: key)
      let inNeeded = needed.contains(key)
      let inCache = sharedCache.contains(cacheKey)
      Issue.record(Comment(rawValue:
        "\(realGaps.count) interior gap pixels found. First: (\(dx),\(dy)) wanted tile \(key.description); inNeeded=\(inNeeded), inCache=\(inCache)."
      ))
    }
  }

  /// Returns the full RGBA byte buffer of the given image. Avoids
  /// repeated CGContext draws inside the comparison loop.
  private static func readAll(_ image: CGImage) -> [UInt8] {
    let width = image.width
    let height = image.height
    let bytesPerRow = width * 4
    var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)
    let cs = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    let context = buffer.withUnsafeMutableBufferPointer { ptr -> CGContext? in
      CGContext(
        data: ptr.baseAddress,
        width: width, height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: cs,
        bitmapInfo: bitmapInfo
      )
    }!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return buffer
  }

  // MARK: - Pixel reader

  private static func readPixel(_ image: CGImage, x: Int, y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
    let width = image.width
    let height = image.height
    let bytesPerRow = width * 4
    var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)
    let cs = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    let context = buffer.withUnsafeMutableBufferPointer { ptr -> CGContext? in
      CGContext(
        data: ptr.baseAddress,
        width: width, height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: cs,
        bitmapInfo: bitmapInfo
      )
    }!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    let off = y * bytesPerRow + x * 4
    return (buffer[off], buffer[off + 1], buffer[off + 2], buffer[off + 3])
  }
}

#endif
