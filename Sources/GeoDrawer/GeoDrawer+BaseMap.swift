//
//  GeoDrawer+BaseMap.swift
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

extension GeoDrawer {

  /// A reference-typed wrapper around a pre-decoded source image that's used
  /// as a base map. Pre-decoding once into a flat RGBA8 buffer avoids paying
  /// the Core Graphics decode cost per output pixel and keeps the per-pixel
  /// inverse-projection loop branch-free on the hot path.
  ///
  /// `Hashable` uses object identity, which is what's needed for the
  /// `Content.baseMap` case to participate in `Content`'s synthesized
  /// `Hashable` conformance.
  public final class BaseMapImage: Hashable, @unchecked Sendable {
    public let width: Int
    public let height: Int
    let pixels: UnsafeBufferPointer<UInt8>
    private let storage: UnsafeMutablePointer<UInt8>

    fileprivate init(width: Int, height: Int, storage: UnsafeMutablePointer<UInt8>) {
      self.width = width
      self.height = height
      self.storage = storage
      self.pixels = UnsafeBufferPointer(start: storage, count: width * height * 4)
    }

    deinit {
      storage.deallocate()
    }

    public static func == (lhs: BaseMapImage, rhs: BaseMapImage) -> Bool {
      lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(ObjectIdentifier(self))
    }

    /// Pre-decodes the supplied `CGImage` into the format used by the base-map
    /// renderer. Returns `nil` if the image can't be drawn into a deviceRGB
    /// bitmap context (extremely unusual).
    ///
    /// - Parameters:
    ///   - cgImage: Source image. Aspect ratio is preserved on downscale.
    ///   - maxDimension: Largest allowed width/height in pixels. Larger inputs
    ///     are scaled down. NASA Blue Marble at 21600×10800 decodes to ~933 MB
    ///     RGBA, so a sensible cap is mandatory on memory-constrained devices.
    public static func decode(_ cgImage: CGImage, maxDimension: Int = 4096) -> BaseMapImage? {
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
      return BaseMapImage(width: w, height: h, storage: buffer)
    }
  }

  /// Describes a raster image to drape under the projection's vector layers.
  ///
  /// The source image is assumed to be a complete, axis-aligned rendering of
  /// `sourceProjection` filling its `visibleBounds`. NASA Blue Marble and
  /// most public-domain world imagery ship in `Projections.Equirectangular`
  /// (the default). Web-Mercator world imagery uses `Projections.Mercator`.
  /// In principle any projection works as long as the image's aspect ratio
  /// matches the projection's natural aspect ratio; otherwise the renderer
  /// will sample non-image areas as transparent.
  ///
  /// SVG output (`drawSVG(_:)`) does not embed the raster.
  public struct BaseMap {

    public enum Sampling: Hashable {
      /// Pick the closest source pixel. Cheapest and produces visible
      /// stair-stepping when the source is upsampled.
      case nearest
      /// Linearly blend the four nearest source pixels. Wraps on the antimeridian
      /// for projections that report `wrapsLongitudinally = true`, so
      /// cylindrical sources don't show a vertical seam at ±180°.
      case bilinear
    }

    public let image: BaseMapImage
    public let sourceProjection: any Projection
    public let sampling: Sampling
    public let alpha: Double

    public init(
      image: BaseMapImage,
      sourceProjection: any Projection = Projections.Equirectangular(),
      sampling: Sampling = .bilinear,
      alpha: Double = 1.0
    ) {
      self.image = image
      self.sourceProjection = sourceProjection
      self.sampling = sampling
      self.alpha = max(0, min(1, alpha))
    }

    /// Decodes `cgImage` and wraps it as a base map with the supplied source
    /// projection (defaults to equirectangular).
    public init?(
      cgImage: CGImage,
      sourceProjection: any Projection = Projections.Equirectangular(),
      sampling: Sampling = .bilinear,
      alpha: Double = 1.0,
      maxDimension: Int = 4096
    ) {
      guard let img = BaseMapImage.decode(cgImage, maxDimension: maxDimension) else {
        return nil
      }
      self.init(image: img, sourceProjection: sourceProjection, sampling: sampling, alpha: alpha)
    }

#if canImport(UIKit)
    public init?(
      uiImage: UIImage,
      sourceProjection: any Projection = Projections.Equirectangular(),
      sampling: Sampling = .bilinear,
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
      sampling: Sampling = .bilinear,
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
}

extension GeoDrawer.BaseMap: Hashable {

  /// Two `BaseMap` values are equal when they share the same pre-decoded
  /// image (by reference), the same source-projection identity (type plus
  /// reference point), and the same sampling/alpha settings. Constructing a
  /// new `BaseMap` from a fresh image therefore invalidates the drawer's
  /// raster cache; rebuilding one with identical arguments does not.
  public static func == (lhs: GeoDrawer.BaseMap, rhs: GeoDrawer.BaseMap) -> Bool {
    lhs.image === rhs.image
      && lhs.sampling == rhs.sampling
      && lhs.alpha == rhs.alpha
      && type(of: lhs.sourceProjection) == type(of: rhs.sourceProjection)
      && lhs.sourceProjection.reference == rhs.sourceProjection.reference
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(image))
    hasher.combine(sampling)
    hasher.combine(alpha)
    hasher.combine(String(reflecting: type(of: sourceProjection)))
    hasher.combine(sourceProjection.reference)
  }
}

#endif
