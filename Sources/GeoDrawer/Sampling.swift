//
//  Sampling.swift
//
//
//  Created by Adrian Schönig on 11/5/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

extension GeoDrawer {

  /// How a raster source is sampled when its pixels don't line up
  /// one-to-one with the output canvas — applies to both single-image
  /// `BaseMap`s and `TiledBaseMap`s.
  public enum Sampling: Hashable, Sendable {
    /// Pick the closest source pixel. Cheapest and produces visible
    /// stair-stepping when the source is upsampled.
    case nearest
    /// Linearly blend the four nearest source pixels. Smoother result;
    /// for cylindrical sources, wraps across the antimeridian so there's
    /// no vertical seam at ±180°.
    case bilinear
  }
}
