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

  /// Cache key for the rendered raster — independent of the drawer's
  /// `(projection, size, zoomTo, insets)` tuple, which is captured by
  /// the cache instance's lifetime. Uses the *resolved* zoom level so
  /// `.auto` and `.fixed(z)` that pick the same level share a slot.
  /// `pixelDensityMilli` is included so a raster rendered at one
  /// backing scale isn't served from cache at another.
  struct TiledRasterCacheKey: Hashable {
    let sourceID: AnyHashable
    let resolvedZoom: Int
    let sampling: Sampling
    let alphaMilli: Int
    let pixelDensityMilli: Int
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
      alphaMilli: Int((tiledBaseMap.alpha * 1000).rounded()),
      pixelDensityMilli: Int((pixelDensity * 1000).rounded())
    )
    if let cached = baseMapCache.getTiled(cacheKey) {
      return cached
    }
    guard let raster = renderTiledBaseMap(tiledBaseMap, zoom: z) else { return nil }
    baseMapCache.setTiled(cacheKey, raster)
    return raster
  }

  /// Wraps the pure-Swift compositor's bitmap in a `CGImage` for the
  /// CoreGraphics draw path.
  private func renderTiledBaseMap(_ tiledBaseMap: TiledBaseMap, zoom z: Int) -> CGImage? {
    guard let bitmap = renderTiledBaseMapBitmap(tiledBaseMap, zoom: z) else { return nil }
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
