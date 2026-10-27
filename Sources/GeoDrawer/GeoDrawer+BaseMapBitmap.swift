//
//  GeoDrawer+BaseMapBitmap.swift
//
//
//  Created by Adrian Schönig on 28/10/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

import Foundation

@preconcurrency import GeoProjector

extension GeoDrawer {

  /// Rasterises a single-image base map at the drawer's canvas size (scaled
  /// by `pixelDensity`), using the projection's `inverse(_:)` to look up a
  /// source pixel for each output pixel and the base map's
  /// `sourceProjection` to find it in the image. Works with any target
  /// projection: an orthographic globe samples a Blue Marble
  /// equirectangular just as a Mercator sheet does.
  ///
  /// Output is RGBA8 premultiplied with row 0 at the visual top. Pixels
  /// outside the projection's image, or outside the source's vertical
  /// coverage, are left transparent so the surrounding `mapBackground` /
  /// `mapBackdrop` shows through.
  ///
  /// Pure Swift, so it runs on Linux as well as Apple platforms. Nothing
  /// is cached here: the CoreGraphics renderer caches the wrapped
  /// `CGImage`, `drawSVG` encodes the bitmap as a PNG straight away.
  func renderBaseMapBitmap(_ baseMap: BaseMap) -> RasterBitmap? {
    guard let projection else { return nil }

    // Render at backing-store resolution so the result downscales (rather
    // than upscales) when it's composited onto the destination.
    let width = max(1, Int((size.width * pixelDensity).rounded()))
    let height = max(1, Int((size.height * pixelDensity).rounded()))
    let bytesPerRow = width * 4
    let totalBytes = bytesPerRow * height

    let sourceImage = baseMap.image
    let sourceImageSize = Size(width: Double(sourceImage.width), height: Double(sourceImage.height))

    let pixels = [UInt8](unsafeUninitializedCapacity: totalBytes) { buffer, initializedCount in
      buffer.initialize(repeating: 0)
      let context = BaseMapRasterContext(
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
        sourceProjection: baseMap.sourceProjection,
        sourceImageSize: sourceImageSize,
        wrapsLongitudinally: baseMap.sourceProjection.wrapsLongitudinally,
        sampling: baseMap.sampling,
        alpha: baseMap.alpha,
        // Holding a strong reference keeps the underlying buffer alive
        // across every parallel iteration, even if `baseMap`'s scope
        // contracts.
        imageRef: sourceImage,
        imagePixels: sourceImage.pixels,
        imageW: sourceImage.width,
        imageH: sourceImage.height
      )
      DispatchQueue.concurrentPerform(iterations: height) { py in
        context.renderRow(py)
      }
      initializedCount = totalBytes
    }

    return RasterBitmap(width: width, height: height, pixels: pixels)
  }
}

/// Captures everything the per-row rasterisation needs in a single value so
/// `concurrentPerform` doesn't have to capture the enclosing `GeoDrawer`'s
/// `self`. Marked `@unchecked Sendable` because each iteration writes only to
/// its own row of the shared output buffer (no overlap, no races).
private struct BaseMapRasterContext: @unchecked Sendable {
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
  let sampling: GeoDrawer.Sampling
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
      // Always `.topLeft`: the output buffer is laid out in image-row
      // order (row 0 = top of canvas), which is what both the SVG
      // `<image>` and `CGContext.draw(image:in:)` expect; the
      // CoreGraphics caller counter-flips the CTM on UIKit.
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
      // pixel. `.topLeft` gives image coordinates with row 0 at the visual
      // top, matching the source image's memory layout.
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
      // (no antimeridian seam); skip otherwise. Out-of-range sy means the
      // geographic point falls outside the source projection's vertical
      // coverage, and the output stays transparent.
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
      // Source bytes are premultiplied. Scaling all four channels by the
      // global alpha multiplier keeps them in premultiplied form.
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
  /// source buffer is premultiplied — so are the returned components. Wraps
  /// longitudinally for cylindrical sources; clamps vertically.
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
