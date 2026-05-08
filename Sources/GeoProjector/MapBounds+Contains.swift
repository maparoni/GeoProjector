//
//  MapBounds+Contains.swift
//
//
//  Created by Adrian Schönig on 8/5/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2022 Corporoni Pty Ltd. See LICENSE.

import Foundation

extension MapBounds {
  /// Returns `true` if the projected `point` lies inside the projection's image.
  ///
  /// The projection's image is centred at `(0, 0)` with half-extents
  /// `(projectionSize.width / 2, projectionSize.height / 2)`.
  func contains(_ point: Point, projectionSize: Size) -> Bool {
    let halfW = projectionSize.width  / 2
    let halfH = projectionSize.height / 2
    let eps = 1e-12

    switch self {
    case .rectangle:
      return point.x >= -halfW - eps && point.x <= halfW + eps
          && point.y >= -halfH - eps && point.y <= halfH + eps

    case .ellipse:
      let nx = point.x / halfW
      let ny = point.y / halfH
      return (nx * nx + ny * ny) <= 1.0 + eps

    case .bezier(let pts):
      return MapBounds.pointInPolygon(point, polygon: pts)
    }
  }

  /// Standard ray-casting point-in-polygon test. Vertices are accepted as inside.
  static func pointInPolygon(_ p: Point, polygon: [Point]) -> Bool {
    guard polygon.count >= 3 else { return false }
    var inside = false
    var j = polygon.count - 1
    for i in 0..<polygon.count {
      let pi = polygon[i], pj = polygon[j]
      if pi.x == p.x && pi.y == p.y { return true }
      let intersects = ((pi.y > p.y) != (pj.y > p.y))
        && (p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y) + pi.x)
      if intersects { inside.toggle() }
      j = i
    }
    return inside
  }
}
