//
//  BaseMap.swift
//
//
//  Created by Adrian Schönig on 9/5/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

import Foundation

@preconcurrency import GeoProjector

extension GeoDrawer {

  /// A reference-typed wrapper around a pre-decoded source image used as a
  /// base map. Pre-decoding once into a flat RGBA8 buffer avoids paying any
  /// per-pixel decode cost in the inverse-projection sampler.
  ///
  /// On Apple platforms a `CGImage`-backed convenience initialiser is
  /// available (see `BaseMapImage.decode(_:maxDimension:)` in
  /// `apple/BaseMap+CoreGraphics.swift`); on Linux callers construct one
  /// directly from a `[UInt8]` RGBA8 buffer they decoded themselves
  /// (e.g. via `swift-png`).
  ///
  /// `Hashable` uses object identity so the `Content.baseMap` case can
  /// participate in `Content`'s synthesised `Hashable` conformance.
  public final class BaseMapImage: Hashable, @unchecked Sendable {
    public let width: Int
    public let height: Int
    let pixels: UnsafeBufferPointer<UInt8>
    private let storage: UnsafeMutablePointer<UInt8>

    /// Backing initialiser used by platform decoders. Takes ownership of
    /// `storage` and releases it on deinit.
    init(width: Int, height: Int, storage: UnsafeMutablePointer<UInt8>) {
      self.width = width
      self.height = height
      self.storage = storage
      self.pixels = UnsafeBufferPointer(start: storage, count: width * height * 4)
    }

    /// Pure-Swift initialiser for callers that already have RGBA8
    /// pre-multiplied bytes in hand — e.g. decoded via `swift-png` on
    /// Linux server-side. The buffer is copied into the wrapper's own
    /// allocation so the caller can deallocate theirs freely.
    public convenience init?(width: Int, height: Int, pixels: [UInt8]) {
      guard width > 0, height > 0 else { return nil }
      let count = width * height * 4
      guard pixels.count == count else { return nil }
      let storage = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
      pixels.withUnsafeBufferPointer { src in
        // `src.baseAddress` is non-nil because `count > 0` is enforced
        // above (and Swift's array storage guarantees a contiguous
        // base address for non-empty arrays).
        if let base = src.baseAddress {
          memcpy(storage, base, count)
        }
      }
      self.init(width: width, height: height, storage: storage)
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
  }

  /// Describes a raster image to drape under the projection's vector
  /// layers.
  ///
  /// The source image is assumed to be a complete, axis-aligned rendering
  /// of `sourceProjection` filling its `visibleBounds`. NASA Blue Marble
  /// and most public-domain world imagery ship in
  /// `Projections.Equirectangular` (the default). Web-Mercator world
  /// imagery uses `Projections.Mercator`. In principle any projection
  /// works as long as the image's aspect ratio matches the projection's
  /// natural aspect ratio; otherwise the renderer will sample non-image
  /// areas as transparent.
  ///
  /// SVG output (`drawSVG(_:)`) does not embed the raster.
  public struct BaseMap {
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
  }
}

extension GeoDrawer.BaseMap: Hashable {

  /// Two `BaseMap` values are equal when they share the same pre-decoded
  /// image (by reference), the same source-projection identity (type
  /// plus reference point), and the same sampling/alpha settings.
  /// Constructing a new `BaseMap` from a fresh image therefore
  /// invalidates the drawer's raster cache; rebuilding one with
  /// identical arguments does not.
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
