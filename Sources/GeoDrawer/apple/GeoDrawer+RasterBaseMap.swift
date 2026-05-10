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
    let sampling: BaseMap.Sampling
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
  }

  /// Rasterises the base map at the drawer's canvas size, using the
  /// projection's `inverse(_:)` to look up a source pixel for each output
  /// pixel.
  ///
  /// Output is a CGImage with premultiplied alpha and row 0 at the visual
  /// top of the canvas (north pole). Pixels outside the projection's image
  /// are left transparent so the surrounding `mapBackground` /
  /// `mapBackdrop` shows through. The result is cached on the drawer keyed
  /// by the `BaseMap`'s identity, so subsequent draws (e.g. triggered by
  /// toggling vector layers) reuse the same raster.
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

  private func renderBaseMap(_ baseMap: BaseMap) -> CGImage? {
    guard let projection else { return nil }

    let pointWidth = size.width
    let pointHeight = size.height
    let width = max(1, Int((pointWidth * pixelDensity).rounded()))
    let height = max(1, Int((pointHeight * pixelDensity).rounded()))
    let bytesPerRow = width * 4
    let totalBytes = bytesPerRow * height

    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: totalBytes)
    buffer.initialize(repeating: 0, count: totalBytes)

    let projSize = projection.projectionSize
    let mapBounds = projection.mapBounds
    let drawerSize = size
    let drawerZoom = zoomTo
    let drawerInsets = insets

    let sourceImage = baseMap.image
    let sourceImageSize = Size(width: Double(sourceImage.width), height: Double(sourceImage.height))
    let context = RasterContext(
      buffer: buffer,
      width: width,
      bytesPerRow: bytesPerRow,
      pixelDensity: pixelDensity,
      drawerSize: drawerSize,
      drawerZoom: drawerZoom,
      drawerInsets: drawerInsets,
      projection: projection,
      projSize: projSize,
      mapBounds: mapBounds,
      sourceProjection: baseMap.sourceProjection,
      sourceImageSize: sourceImageSize,
      wrapsLongitudinally: baseMap.sourceProjection.wrapsLongitudinally,
      sampling: baseMap.sampling,
      alpha: baseMap.alpha,
      // Holding a strong reference keeps the underlying buffer alive across
      // every parallel iteration, even if `baseMap`'s scope contracts.
      imageRef: sourceImage,
      imagePixels: sourceImage.pixels,
      imageW: sourceImage.width,
      imageH: sourceImage.height
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
      releaseData: { _, ptr, _ in
        ptr.deallocate()
      }
    )
    guard let provider else {
      buffer.deallocate()
      return nil
    }

    return CGImage(
      width: width, height: height,
      bitsPerComponent: 8,
      bitsPerPixel: 32,
      bytesPerRow: bytesPerRow,
      space: cs,
      bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
      provider: provider,
      decode: nil,
      shouldInterpolate: false,
      intent: .defaultIntent
    )
  }
}

/// Captures everything the per-row rasterisation needs in a single value so
/// `concurrentPerform` doesn't have to capture the enclosing `GeoDrawer`'s
/// `self`. Marked `@unchecked Sendable` because each iteration writes only to
/// its own row of the shared output buffer (no overlap, no races).
private struct RasterContext: @unchecked Sendable {
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
  let sourceImageSize: Size
  let wrapsLongitudinally: Bool
  let sampling: GeoDrawer.BaseMap.Sampling
  let alpha: Double
  let imageRef: GeoDrawer.BaseMapImage
  let imagePixels: UnsafeBufferPointer<UInt8>
  let imageW: Int
  let imageH: Int

  func renderRow(_ py: Int) {
    // Output rows are in backing-pixel space; convert each to the
    // drawer's point-space before asking the projection.
    let pyPoints = (Double(py) + 0.5) / pixelDensity

    for px in 0..<width {
      let pxPoints = (Double(px) + 0.5) / pixelDensity
      // Always use `.topLeft` here. The output buffer is laid out in image-
      // row order (row 0 = top of canvas) so it composites correctly via
      // `CGContext.draw(image:in:)` regardless of platform; the caller
      // counter-flips the CTM on UIKit so row 0 lands at the visual top.
      let projected = projection.untranslate(
        Point(x: pxPoints, y: pyPoints),
        from: drawerSize,
        zoomTo: drawerZoom,
        insets: drawerInsets,
        coordinateSystem: .topLeft
      )
      guard mapBounds.contains(projected, projectionSize: projSize),
            let geo = projection.inverse(projected) else {
        continue
      }

      // Forward-project the geographic coordinate through the source
      // projection to find the source-image pixel that backs this output
      // pixel. `point(for:size:coordinateSystem: .topLeft)` returns image
      // coordinates with row 0 at the visual top, which matches the source
      // image's memory layout after `BaseMapImage.decode`.
      guard let sourcePixel = sourceProjection.point(
        for: geo,
        size: sourceImageSize,
        zoomTo: nil,
        insets: .zero,
        coordinateSystem: .topLeft
      ) else { continue }

      var sx = sourcePixel.x
      let sy = sourcePixel.y

      // Out-of-image samples: wrap longitudinally for cylindrical sources
      // (no antimeridian seam); skip otherwise. The y-axis is always
      // bounded by the source image's vertical extent, so out-of-range sy
      // means the geographic point falls outside the source projection's
      // vertical coverage and we leave the output transparent.
      if wrapsLongitudinally {
        let w = Double(imageW)
        sx -= floor(sx / w) * w
      } else if sx < 0 || sx >= Double(imageW) {
        continue
      }
      if sy < 0 || sy >= Double(imageH) {
        continue
      }

      let pixel = sample(sx: sx, sy: sy)
      // Source bytes are premultiplied (kCGImageAlphaPremultipliedLast on the
      // pre-decode). Scaling all four channels by the global alpha multiplier
      // keeps them in premultiplied form.
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

  /// Returns RGBA in 0...255 from a source-pixel coordinate `(sx, sy)`. The
  /// source buffer is premultiplied — so are the returned components, and
  /// we keep them premultiplied throughout. Wraps longitudinally for
  /// cylindrical sources; clamps vertically.
  private func sample(sx: Double, sy: Double) -> (UInt8, UInt8, UInt8, UInt8) {
    switch sampling {
    case .nearest:
      let xi: Int
      if wrapsLongitudinally {
        xi = ((Int(sx.rounded(.down)) % imageW) + imageW) % imageW
      } else {
        xi = clamp(Int(sx.rounded(.down)), 0, imageW - 1)
      }
      let yi = clamp(Int(sy.rounded(.down)), 0, imageH - 1)
      let off = (yi * imageW + xi) * 4
      return (imagePixels[off], imagePixels[off + 1], imagePixels[off + 2], imagePixels[off + 3])

    case .bilinear:
      let fx = sx - 0.5
      let fy = sy - 0.5
      let x0 = Int(floor(fx))
      let y0 = Int(floor(fy))
      let tx = fx - Double(x0)
      let ty = fy - Double(y0)

      let x0w: Int
      let x1w: Int
      if wrapsLongitudinally {
        x0w = ((x0 % imageW) + imageW) % imageW
        x1w = (((x0 + 1) % imageW) + imageW) % imageW
      } else {
        x0w = clamp(x0, 0, imageW - 1)
        x1w = clamp(x0 + 1, 0, imageW - 1)
      }
      let y0c = clamp(y0, 0, imageH - 1)
      let y1c = clamp(y0 + 1, 0, imageH - 1)

      let off00 = (y0c * imageW + x0w) * 4
      let off01 = (y0c * imageW + x1w) * 4
      let off10 = (y1c * imageW + x0w) * 4
      let off11 = (y1c * imageW + x1w) * 4

      func mix(_ a: UInt8, _ b: UInt8, _ t: Double) -> UInt8 {
        let v = Double(a) * (1 - t) + Double(b) * t
        return UInt8(min(255, max(0, v.rounded())))
      }
      let r = mix(mix(imagePixels[off00 + 0], imagePixels[off01 + 0], tx),
                  mix(imagePixels[off10 + 0], imagePixels[off11 + 0], tx), ty)
      let g = mix(mix(imagePixels[off00 + 1], imagePixels[off01 + 1], tx),
                  mix(imagePixels[off10 + 1], imagePixels[off11 + 1], tx), ty)
      let b = mix(mix(imagePixels[off00 + 2], imagePixels[off01 + 2], tx),
                  mix(imagePixels[off10 + 2], imagePixels[off11 + 2], tx), ty)
      let a = mix(mix(imagePixels[off00 + 3], imagePixels[off01 + 3], tx),
                  mix(imagePixels[off10 + 3], imagePixels[off11 + 3], tx), ty)
      return (r, g, b, a)
    }
  }
}

@inline(__always)
private func clamp<T: Comparable>(_ value: T, _ lo: T, _ hi: T) -> T {
  min(max(value, lo), hi)
}

#endif
