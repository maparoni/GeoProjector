//
//  InsideGrid.swift
//  GeoProjectorDanseiji
//
//  Created by Adrian Schönig on 28/10/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

import Foundation
import GeoProjector

/// A point-in-polygon test for a fixed polygon, answered from a grid for
/// most points: each cell is known to be inside, outside, or crossed by the
/// boundary, and only the crossed cells fall back to walking the polygon.
/// Danseiji's `inverse` runs once per pixel of a raster base map, and its
/// edge has hundreds of vertices.
struct InsideGrid {
  private enum State: UInt8 { case outside, inside, boundary }

  let polygon: [Point]
  private let origin: Point
  private let cellWidth: Double
  private let cellHeight: Double
  private let columns: Int
  private let rows: Int
  private let states: [State]

  init(polygon: [Point], bounds: Rect, resolution: Int = 128) {
    self.polygon = polygon
    origin = bounds.origin
    columns = resolution
    rows = resolution
    cellWidth = max(bounds.size.width, .ulpOfOne) / Double(resolution)
    cellHeight = max(bounds.size.height, .ulpOfOne) / Double(resolution)

    var states = [State?](repeating: nil, count: resolution * resolution)
    // Every cell a boundary segment's bounding box touches might be crossed
    // by it: mark them all, conservatively.
    var j = polygon.count - 1
    for i in 0..<polygon.count {
      let a = polygon[i], b = polygon[j]
      let c0 = Self.index(min(a.x, b.x), origin.x, cellWidth, resolution)
      let c1 = Self.index(max(a.x, b.x), origin.x, cellWidth, resolution)
      let r0 = Self.index(min(a.y, b.y), origin.y, cellHeight, resolution)
      let r1 = Self.index(max(a.y, b.y), origin.y, cellHeight, resolution)
      for r in r0...r1 {
        for c in c0...c1 {
          states[r * resolution + c] = .boundary
        }
      }
      j = i
    }
    // The rest lie wholly on one side: their centre says which.
    for r in 0..<resolution {
      for c in 0..<resolution where states[r * resolution + c] == nil {
        let centre = Point(
          x: origin.x + (Double(c) + 0.5) * cellWidth,
          y: origin.y + (Double(r) + 0.5) * cellHeight)
        states[r * resolution + c] = Self.walk(centre, polygon) ? .inside : .outside
      }
    }
    self.states = states.map { $0 ?? .boundary }
  }

  func contains(_ p: Point) -> Bool {
    let cx = (p.x - origin.x) / cellWidth
    let cy = (p.y - origin.y) / cellHeight
    guard cx >= 0, cy >= 0, cx < Double(columns), cy < Double(rows) else {
      return Self.walk(p, polygon)
    }
    switch states[Int(cy) * columns + Int(cx)] {
    case .inside: return true
    case .outside: return false
    case .boundary: return Self.walk(p, polygon)
    }
  }

  private static func index(_ value: Double, _ origin: Double, _ size: Double, _ count: Int) -> Int {
    min(max(Int(((value - origin) / size).rounded(.down)), 0), count - 1)
  }

  /// Standard ray-casting point-in-polygon test (inclusive of vertices).
  static func walk(_ p: Point, _ polygon: [Point]) -> Bool {
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
