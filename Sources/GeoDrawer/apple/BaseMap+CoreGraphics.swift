//
//  BaseMap+CoreGraphics.swift
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

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension GeoDrawer.BaseMapImage {

  /// Pre-decodes the supplied `CGImage` into the format used by the
  /// base-map renderer. Returns `nil` if the image can't be drawn into
  /// a deviceRGB bitmap context (extremely unusual).
  ///
  /// - Parameters:
  ///   - cgImage: Source image. Aspect ratio is preserved on downscale.
  ///   - maxDimension: Largest allowed width/height in pixels. Larger
  ///     inputs are scaled down. NASA Blue Marble at 21600×10800
  ///     decodes to ~933 MB RGBA, so a sensible cap is mandatory on
  ///     memory-constrained devices.
  public static func decode(_ cgImage: CGImage, maxDimension: Int = 4096) -> GeoDrawer.BaseMapImage? {
    let origW = cgImage.width
    let origH = cgImage.height
    guard origW > 0, origH > 0 else { return nil }

    let largest = max(origW, origH)
    let w: Int
    let h: Int
    if largest > maxDimension {
      let scale = Double(maxDimension) / Double(largest)
      w = max(1, Int((Double(origW) * scale).rounded()))
      h = max(1, Int((Double(origH) * scale).rounded()))
    } else {
      w = origW
      h = origH
    }

    let bytesPerRow = w * 4
    let total = bytesPerRow * h
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: total)
    buffer.initialize(repeating: 0, count: total)

    let cs = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let context = CGContext(
      data: buffer,
      width: w, height: h,
      bitsPerComponent: 8,
      bytesPerRow: bytesPerRow,
      space: cs,
      bitmapInfo: bitmapInfo
    ) else {
      buffer.deallocate()
      return nil
    }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
    return GeoDrawer.BaseMapImage(width: w, height: h, storage: buffer)
  }
}

extension GeoDrawer.BaseMap {

  /// Decodes `cgImage` and wraps it as a base map with the supplied source
  /// projection (defaults to equirectangular).
  public init?(
    cgImage: CGImage,
    sourceProjection: any Projection = Projections.Equirectangular(),
    sampling: GeoDrawer.Sampling = .bilinear,
    alpha: Double = 1.0,
    maxDimension: Int = 4096
  ) {
    guard let img = GeoDrawer.BaseMapImage.decode(cgImage, maxDimension: maxDimension) else {
      return nil
    }
    self.init(image: img, sourceProjection: sourceProjection, sampling: sampling, alpha: alpha)
  }

#if canImport(UIKit)
  public init?(
    uiImage: UIImage,
    sourceProjection: any Projection = Projections.Equirectangular(),
    sampling: GeoDrawer.Sampling = .bilinear,
    alpha: Double = 1.0,
    maxDimension: Int = 4096
  ) {
    guard let cg = uiImage.cgImage else { return nil }
    self.init(
      cgImage: cg,
      sourceProjection: sourceProjection,
      sampling: sampling,
      alpha: alpha,
      maxDimension: maxDimension
    )
  }
#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
  public init?(
    nsImage: NSImage,
    sourceProjection: any Projection = Projections.Equirectangular(),
    sampling: GeoDrawer.Sampling = .bilinear,
    alpha: Double = 1.0,
    maxDimension: Int = 4096
  ) {
    var rect = CGRect(origin: .zero, size: nsImage.size)
    guard let cg = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
      return nil
    }
    self.init(
      cgImage: cg,
      sourceProjection: sourceProjection,
      sampling: sampling,
      alpha: alpha,
      maxDimension: maxDimension
    )
  }
#endif
}

#endif
