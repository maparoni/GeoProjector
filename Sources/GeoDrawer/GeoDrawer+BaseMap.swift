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
  /// In v1 the source image must be **equirectangular** (longitude on x ∈
  /// `[-π, π]`, latitude on y ∈ `[π/2, -π/2]`, top of the image is the north
  /// pole). NASA Blue Marble / Visible Earth and most public-domain world
  /// imagery ships in this form. Other source projections are reserved for
  /// future versions.
  ///
  /// SVG output (`drawSVG(_:)`) does not embed the raster in v1.
  public struct BaseMap: Hashable {

    public enum SourceProjection: Hashable {
      case equirectangular
    }

    public enum Sampling: Hashable {
      /// Pick the closest source pixel. Cheapest and produces visible
      /// stair-stepping when the source is upsampled.
      case nearest
      /// Linearly blend the four nearest source pixels. Wraps on the antimeridian
      /// so cylindrical projections don't show a vertical seam at ±180°.
      case bilinear
    }

    public let image: BaseMapImage
    public let sourceProjection: SourceProjection
    public let sampling: Sampling
    public let alpha: Double

    public init(
      image: BaseMapImage,
      sourceProjection: SourceProjection = .equirectangular,
      sampling: Sampling = .bilinear,
      alpha: Double = 1.0
    ) {
      self.image = image
      self.sourceProjection = sourceProjection
      self.sampling = sampling
      self.alpha = max(0, min(1, alpha))
    }

    /// Decodes `cgImage` and wraps it as an equirectangular base map.
    public init?(
      cgImage: CGImage,
      sampling: Sampling = .bilinear,
      alpha: Double = 1.0,
      maxDimension: Int = 4096
    ) {
      guard let img = BaseMapImage.decode(cgImage, maxDimension: maxDimension) else {
        return nil
      }
      self.init(image: img, sourceProjection: .equirectangular, sampling: sampling, alpha: alpha)
    }

#if canImport(UIKit)
    public init?(
      uiImage: UIImage,
      sampling: Sampling = .bilinear,
      alpha: Double = 1.0,
      maxDimension: Int = 4096
    ) {
      guard let cg = uiImage.cgImage else { return nil }
      self.init(cgImage: cg, sampling: sampling, alpha: alpha, maxDimension: maxDimension)
    }
#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public init?(
      nsImage: NSImage,
      sampling: Sampling = .bilinear,
      alpha: Double = 1.0,
      maxDimension: Int = 4096
    ) {
      var rect = CGRect(origin: .zero, size: nsImage.size)
      guard let cg = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
        return nil
      }
      self.init(cgImage: cg, sampling: sampling, alpha: alpha, maxDimension: maxDimension)
    }
#endif
  }
}

#endif
