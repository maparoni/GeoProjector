//
//  TiledBaseMap.swift
//
//
//  Created by Adrian Schönig on 10/5/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

import Foundation

@preconcurrency import GeoProjector

extension GeoDrawer {

  /// A raster underlay backed by a `TileSource` instead of a single
  /// pre-decoded image. The renderer fetches the tiles that cover the
  /// canvas at the chosen `zoom` level, then samples them per output
  /// pixel using the source's `projection`.
  ///
  /// Use this for high-resolution imagery you can't fit in memory as a
  /// single buffer (e.g. the 21600×10800 NASA Blue Marble composite split
  /// into a static grid) and for live slippy-map tiles
  /// (`URLTemplateTileSource`). For a single-image source, use `BaseMap`.
  ///
  /// Tiles are pre-fetched on the same async path as the projection
  /// pre-warm — see `GeoMapView.invalidateProjectedContents`.
  public struct TiledBaseMap: @unchecked Sendable {

    /// How the renderer chooses the zoom level to fetch tiles at.
    public enum Zoom: Hashable {
      /// The renderer picks a zoom level matching the canvas resolution
      /// at draw time: `round(log2(max(canvas.width, canvas.height) /
      /// source.tileSize))`, clamped to `[source.minZoom, source.maxZoom]`.
      /// Doesn't account for `zoomTo`-region scaling — for tightly zoomed
      /// regions, prefer `.fixed(_:)` with a manually-computed level.
      case auto
      /// Use this exact zoom level. Must lie in `[source.minZoom,
      /// source.maxZoom]`.
      case fixed(Int)
    }

    public let source: any TileSource
    public let zoom: Zoom
    public let sampling: BaseMap.Sampling
    public let alpha: Double

    public init(
      source: any TileSource,
      zoom: Zoom = .auto,
      sampling: BaseMap.Sampling = .bilinear,
      alpha: Double = 1.0
    ) {
      if case let .fixed(z) = zoom {
        precondition(z >= source.minZoom && z <= source.maxZoom,
                     "zoom \(z) outside source range [\(source.minZoom), \(source.maxZoom)]")
      }
      self.source = source
      self.zoom = zoom
      self.sampling = sampling
      self.alpha = max(0, min(1, alpha))
    }

    /// Convenience for `init(source:zoom:.fixed(_:),sampling:alpha:)`.
    public init(
      source: any TileSource,
      zoom: Int,
      sampling: BaseMap.Sampling = .bilinear,
      alpha: Double = 1.0
    ) {
      self.init(source: source, zoom: .fixed(zoom), sampling: sampling, alpha: alpha)
    }
  }
}

extension GeoDrawer.TiledBaseMap: Hashable {

  public static func == (lhs: GeoDrawer.TiledBaseMap, rhs: GeoDrawer.TiledBaseMap) -> Bool {
    lhs.source.tileSourceID == rhs.source.tileSourceID
      && lhs.zoom == rhs.zoom
      && lhs.sampling == rhs.sampling
      && lhs.alpha == rhs.alpha
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(source.tileSourceID)
    hasher.combine(zoom)
    hasher.combine(sampling)
    hasher.combine(alpha)
  }
}
