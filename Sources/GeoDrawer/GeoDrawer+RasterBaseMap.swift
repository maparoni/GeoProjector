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
  /// same raster (same source image, sampling, alpha) share a cache slot.
  struct BaseMapCacheKey: Hashable {
    let imageID: ObjectIdentifier
    let sampling: BaseMap.Sampling
    let alphaMilli: Int

    init(_ baseMap: BaseMap) {
      self.imageID = ObjectIdentifier(baseMap.image)
      self.sampling = baseMap.sampling
      self.alphaMilli = Int((baseMap.alpha * 1000).rounded())
    }
  }

  /// Reference-typed cache shared across copies of a single `GeoDrawer` value.
  /// Owners (e.g. `GeoMapView`) discard the entire `GeoDrawer` when projection
  /// parameters change, which incidentally drops this cache.
  final class BaseMapCache: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [BaseMapCacheKey: CGImage] = [:]

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
  }

  /// Rasterises the base map at the drawer's canvas size, using the
  /// projection's `inverse(_:)` to look up a source pixel for each output
  /// pixel.
  ///
  /// Output is a CGImage with premultiplied alpha; row 0 is the top of the
  /// canvas regardless of the destination context's CTM, since
  /// `CGContext.draw(image:in:)` places the image's row 0 at the visually-top
  /// of the rect on both UIKit (flipped CTM) and AppKit (identity CTM)
  /// contexts. Pixels outside the projection's image are left transparent so
  /// the surrounding `mapBackground` / `mapBackdrop` shows through. The
  /// result is cached on the drawer keyed by the `BaseMap`'s identity, so
  /// subsequent draws (e.g. triggered by toggling vector layers) reuse the
  /// same raster.
  ///
  /// The `coordinateSystem` parameter is accepted for API symmetry with the
  /// other `GeoDrawer` entry points but is intentionally ignored — the raster
  /// is always laid out in image-row order (row 0 = visual top).
  func renderedBaseMap(_ baseMap: BaseMap, coordinateSystem _: CoordinateSystem) -> CGImage? {
    let key = BaseMapCacheKey(baseMap)
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

    let width = max(1, Int(size.width.rounded()))
    let height = max(1, Int(size.height.rounded()))
    let bytesPerRow = width * 4
    let totalBytes = bytesPerRow * height

    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: totalBytes)
    buffer.initialize(repeating: 0, count: totalBytes)

    let projSize = projection.projectionSize
    let mapBounds = projection.mapBounds
    let drawerSize = size
    let drawerZoom = zoomTo
    let drawerInsets = insets

    let context = RasterContext(
      buffer: buffer,
      width: width,
      bytesPerRow: bytesPerRow,
      drawerSize: drawerSize,
      drawerZoom: drawerZoom,
      drawerInsets: drawerInsets,
      projection: projection,
      projSize: projSize,
      mapBounds: mapBounds,
      sampling: baseMap.sampling,
      alpha: baseMap.alpha,
      // Holding a strong reference keeps the underlying buffer alive across
      // every parallel iteration, even if `baseMap`'s scope contracts.
      imageRef: baseMap.image,
      imagePixels: baseMap.image.pixels,
      imageW: baseMap.image.width,
      imageH: baseMap.image.height
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
  let drawerSize: Size
  let drawerZoom: Rect?
  let drawerInsets: EdgeInsets
  let projection: Projection
  let projSize: Size
  let mapBounds: MapBounds
  let sampling: GeoDrawer.BaseMap.Sampling
  let alpha: Double
  let imageRef: GeoDrawer.BaseMapImage
  let imagePixels: UnsafeBufferPointer<UInt8>
  let imageW: Int
  let imageH: Int

  func renderRow(_ py: Int) {
    let pyD = Double(py) + 0.5
    let twoPi = 2 * Double.pi

    for px in 0..<width {
      let pxD = Double(px) + 0.5
      // Always use `.topLeft` here. The output buffer is laid out in image-
      // row order (row 0 = top of canvas) so it composites correctly via
      // `CGContext.draw(image:in:)` against either a flipped (UIKit) or
      // identity (AppKit) CTM.
      let projected = projection.untranslate(
        Point(x: pxD, y: pyD),
        from: drawerSize,
        zoomTo: drawerZoom,
        insets: drawerInsets,
        coordinateSystem: .topLeft
      )
      guard mapBounds.contains(projected, projectionSize: projSize),
            let geo = projection.inverse(projected) else {
        continue
      }

      // Equirectangular UV. Wrap u modulo 1 so the antimeridian seam isn't
      // sampled out of bounds. Clamp v to a half-pixel inset so the topmost
      // and bottommost source rows aren't smeared across the projection's
      // pole region by bilinear sampling.
      var u = (geo.x + .pi) / twoPi
      u -= floor(u)
      var v = (.pi / 2 - geo.y) / .pi
      let vEpsilon = 0.5 / Double(imageH)
      if v < vEpsilon { v = vEpsilon }
      else if v > 1 - vEpsilon { v = 1 - vEpsilon }

      let pixel = sample(u: u, v: v)
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

  /// Returns RGBA in 0...255. The source buffer is premultiplied — so are
  /// the returned components, and we keep them premultiplied throughout.
  private func sample(u: Double, v: Double) -> (UInt8, UInt8, UInt8, UInt8) {
    switch sampling {
    case .nearest:
      let xi = clamp(Int(u * Double(imageW)), 0, imageW - 1)
      let yi = clamp(Int(v * Double(imageH)), 0, imageH - 1)
      let off = (yi * imageW + xi) * 4
      return (imagePixels[off], imagePixels[off + 1], imagePixels[off + 2], imagePixels[off + 3])

    case .bilinear:
      let fx = u * Double(imageW) - 0.5
      let fy = v * Double(imageH) - 0.5
      let x0 = Int(floor(fx))
      let y0 = Int(floor(fy))
      let tx = fx - Double(x0)
      let ty = fy - Double(y0)

      // Wrap horizontally (longitude); clamp vertically (latitude).
      let x0w = ((x0 % imageW) + imageW) % imageW
      let x1w = (((x0 + 1) % imageW) + imageW) % imageW
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
