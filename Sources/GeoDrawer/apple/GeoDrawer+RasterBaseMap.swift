//
//  GeoDrawer+RasterBaseMap.swift
//
//
//  Created by Adrian Schönig on 9/5/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

#if canImport(CoreGraphics)
import CoreGraphics
import Foundation

import GeoProjector

extension GeoDrawer {

  /// Identifier for a cached raster — independent of the drawer's
  /// `(projection, size, zoomTo, insets)` tuple, which is captured implicitly
  /// by the cache instance's lifetime. Two `BaseMap` values that produce the
  /// same raster (same source image, sampling, alpha, pixel density) share a
  /// cache slot.
  struct BaseMapCacheKey: Hashable {
    let imageID: ObjectIdentifier
    let sampling: GeoDrawer.Sampling
    let alphaMilli: Int
    let pixelDensityMilli: Int

    init(_ baseMap: BaseMap, pixelDensity: Double) {
      self.imageID = ObjectIdentifier(baseMap.image)
      self.sampling = baseMap.sampling
      self.alphaMilli = Int((baseMap.alpha * 1000).rounded())
      self.pixelDensityMilli = Int((pixelDensity * 1000).rounded())
    }
  }

  /// Reference-typed cache shared across copies of a single `GeoDrawer` value.
  /// Owners (e.g. `GeoMapView`) discard the entire `GeoDrawer` when projection
  /// parameters change, which incidentally drops this cache.
  final class BaseMapCache: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [BaseMapCacheKey: CGImage] = [:]
    private var tiledEntries: [TiledRasterCacheKey: CGImage] = [:]

    func get(_ key: BaseMapCacheKey) -> CGImage? {
      lock.lock()
      defer { lock.unlock() }
      return entries[key]
    }

    func set(_ key: BaseMapCacheKey, _ image: CGImage) {
      lock.lock()
      defer { lock.unlock() }
      entries[key] = image
    }

    func getTiled(_ key: TiledRasterCacheKey) -> CGImage? {
      lock.lock()
      defer { lock.unlock() }
      return tiledEntries[key]
    }

    func setTiled(_ key: TiledRasterCacheKey, _ image: CGImage) {
      lock.lock()
      defer { lock.unlock() }
      tiledEntries[key] = image
    }

    /// Drops every rendered tiled raster whose key matches `sourceID`.
    /// Called when new tiles arrive for that source — the prior render
    /// has stale tile coverage and must be recomputed.
    func invalidateTiled(matching sourceID: AnyHashable) {
      lock.lock()
      defer { lock.unlock() }
      tiledEntries = tiledEntries.filter { $0.key.sourceID != sourceID }
    }
  }

  /// Rasterises the base map at the drawer's canvas size via the pure-Swift
  /// `renderBaseMapBitmap(_:)` sampler, wrapped in a CGImage with
  /// premultiplied alpha and row 0 at the visual top of the canvas (north
  /// pole). Pixels outside the projection's image are left transparent so
  /// the surrounding `mapBackground` / `mapBackdrop` shows through. The
  /// result is cached on the drawer keyed by the `BaseMap`'s identity, so
  /// subsequent draws (e.g. triggered by toggling vector layers) reuse the
  /// same raster.
  ///
  /// The `coordinateSystem` parameter is accepted for API symmetry with the
  /// other `GeoDrawer` entry points but is intentionally ignored — the
  /// caller (`draw(_:mapBackground:mapOutline:mapBackdrop:in:)`) is
  /// responsible for counter-flipping the CTM on UIKit so the raster's
  /// row 0 lands at the visual top in either coordinate system.
  func renderedBaseMap(_ baseMap: BaseMap, coordinateSystem _: CoordinateSystem) -> CGImage? {
    let key = BaseMapCacheKey(baseMap, pixelDensity: pixelDensity)
    if let cached = baseMapCache.get(key) {
      return cached
    }
    guard let raster = renderBaseMap(baseMap) else {
      return nil
    }
    baseMapCache.set(key, raster)
    return raster
  }

  /// Wraps the pure-Swift sampler's bitmap in a `CGImage` for the
  /// CoreGraphics draw path.
  private func renderBaseMap(_ baseMap: BaseMap) -> CGImage? {
    guard let bitmap = renderBaseMapBitmap(baseMap) else { return nil }
    let cs = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let provider = CGDataProvider(data: Data(bitmap.pixels) as CFData) else { return nil }
    return CGImage(
      width: bitmap.width, height: bitmap.height,
      bitsPerComponent: 8, bitsPerPixel: 32,
      bytesPerRow: bitmap.width * 4,
      space: cs,
      bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
      provider: provider, decode: nil,
      shouldInterpolate: false, intent: .defaultIntent
    )
  }
}

#endif
