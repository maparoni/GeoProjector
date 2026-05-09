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
  public struct TiledBaseMap {
    public let source: any TileSource
    public let zoom: Int
    public let sampling: BaseMap.Sampling
    public let alpha: Double

    public init(
      source: any TileSource,
      zoom: Int,
      sampling: BaseMap.Sampling = .bilinear,
      alpha: Double = 1.0
    ) {
      precondition(zoom >= source.minZoom && zoom <= source.maxZoom,
                   "zoom \(zoom) outside source range [\(source.minZoom), \(source.maxZoom)]")
      self.source = source
      self.zoom = zoom
      self.sampling = sampling
      self.alpha = max(0, min(1, alpha))
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
