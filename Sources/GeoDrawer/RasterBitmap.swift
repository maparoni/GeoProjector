//
//  RasterBitmap.swift
//
//
//  Created by Adrian Schönig on 27/10/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

import Foundation

extension GeoDrawer {

  /// A composited raster at the drawer's canvas size (times
  /// `pixelDensity`). RGBA8 premultiplied, row-major, row 0 at the visual
  /// top. Produced by the pure-Swift tile compositor; the CoreGraphics
  /// renderer wraps it in a `CGImage`, `drawSVG` encodes it as a PNG.
  struct RasterBitmap: Sendable {
    let width: Int
    let height: Int
    let pixels: [UInt8]
  }
}
