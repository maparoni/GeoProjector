//
//  GeoDrawer+BoundarySplit.swift
//
//
//  Created by Adrian Schönig on 9/5/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2022 Corporoni Pty Ltd. See LICENSE.

import Foundation

import GeoProjector

extension GeoDrawer {

  /// Splits a polyline into sub-paths that each stay inside the projection's
  /// `mapBounds`. Each entry/exit gets a synthesised boundary point so the
  /// resulting sub-paths start and end on the projection edge.
  ///
  /// Two kinds of split are recognised:
  /// 1. A segment that leaves the bounds (one endpoint inside, the other
  ///    outside or unprojectable) ends/starts on the boundary.
  /// 2. A segment whose endpoints are both inside but whose projected length
  ///    exceeds half the projection size in either axis. That means the
  ///    projection wrapped (e.g. across the antimeridian) and the straight
  ///    line between the projected points doesn't reflect the surface path —
  ///    we end the current piece on the near-side boundary and start a new
  ///    one on the far-side boundary.
  static func boundarySplit(
    _ projected: [(Point, Point?)],
    mapBounds: MapBounds,
    projectionSize: Size
  ) -> [[Point]] {
    guard !projected.isEmpty else { return [] }

    var pieces: [[Point]] = []
    var current: [Point] = []

    var prev: (proj: Point?, inside: Bool)? = nil

    for (_, proj) in projected {
      let inside: Bool
      if let p = proj {
        inside = mapBounds.contains(p, projectionSize: projectionSize)
      } else {
        inside = false
      }

      if let prev {
        if prev.inside, inside,
           let prevP = prev.proj, let p = proj,
           let shift = wrapShift(from: prevP, to: p, projectionSize: projectionSize) {
          // Wrap detected: split between prevP and p, anchored on opposite
          // sides of the boundary.
          let exit = mapBounds.firstIntersection(
            from: prevP,
            to: Point(x: p.x + shift.x, y: p.y + shift.y),
            projectionSize: projectionSize
          ) ?? prevP
          current.append(exit)
          if !current.isEmpty {
            pieces.append(current)
            current = []
          }
          let entry = mapBounds.firstIntersection(
            from: p,
            to: Point(x: prevP.x - shift.x, y: prevP.y - shift.y),
            projectionSize: projectionSize
          ) ?? p
          current.append(entry)
        } else {
          switch (prev.inside, inside) {
          case (true, true):
            // Both endpoints inside, but the straight line between them might
            // still cross a concave region of the boundary (notches in the
            // bezier outline). Look for paired exit/entry crossings and split.
            if let prevP = prev.proj, let p = proj {
              let crossings = mapBounds.allIntersections(from: prevP, to: p, projectionSize: projectionSize)
              if crossings.count >= 2 {
                var i = 0
                while i + 1 < crossings.count {
                  current.append(crossings[i])
                  if !current.isEmpty {
                    pieces.append(current)
                    current = []
                  }
                  current.append(crossings[i + 1])
                  i += 2
                }
              }
            }
          case (true, false):
            // Leaving the visible region: anchor the current arc on the boundary.
            // If the segment to `curr` is so long it implies a wrap (e.g.
            // crossing the antimeridian), shift `curr` onto `prev`'s side so
            // the intersection is found on the correct edge.
            if let prevP = prev.proj, let p = proj {
              let target: Point
              if let shift = wrapShift(from: prevP, to: p, projectionSize: projectionSize) {
                target = Point(x: p.x + shift.x, y: p.y + shift.y)
              } else {
                target = p
              }
              if let exit = mapBounds.firstIntersection(from: prevP, to: target, projectionSize: projectionSize) {
                current.append(exit)
              }
            }
            if !current.isEmpty {
              pieces.append(current)
              current = []
            }
          case (false, true):
            // Re-entering: start the next arc at the boundary entry point.
            // Same wrap consideration as the (true, false) case: shift `prev`
            // to `curr`'s side when a wrap-length segment separates them, so
            // the intersection lands on the correct edge.
            if let prevP = prev.proj, let p = proj {
              let source: Point
              if let shift = wrapShift(from: p, to: prevP, projectionSize: projectionSize) {
                source = Point(x: prevP.x + shift.x, y: prevP.y + shift.y)
              } else {
                source = prevP
              }
              if let entry = mapBounds.firstIntersection(from: p, to: source, projectionSize: projectionSize) {
                current.append(entry)
              }
            }
          case (false, false):
            break
          }
        }
      }

      if inside, let proj {
        current.append(proj)
      }

      prev = (proj, inside)
    }

    if !current.isEmpty {
      pieces.append(current)
    }

    return pieces
  }

  /// Same as ``boundarySplit(_:mapBounds:projectionSize:)`` but each split
  /// piece is closed back to its first point along the projection boundary
  /// using ``MapBounds/boundaryArc(from:to:projectionSize:)``. Returns
  /// closed rings suitable for polygon fill.
  ///
  /// If the input is itself a closed ring (first projected point equals last)
  /// AND both endpoints are inside the bounds, the first and last raw pieces
  /// are merged before closing, since a closed ring's "join point" is an
  /// arbitrary cut and shouldn't itself become a piece boundary.
  static func boundarySplitClosed(
    _ projected: [(Point, Point?)],
    mapBounds: MapBounds,
    projectionSize: Size
  ) -> [[Point]] {
    let raw = boundarySplit(projected, mapBounds: mapBounds, projectionSize: projectionSize)

    let pieces: [[Point]]
    if raw.count >= 2,
       let firstU = projected.first?.0, let lastU = projected.last?.0,
       firstU.x == lastU.x, firstU.y == lastU.y,
       let firstP = projected.first?.1, let lastP = projected.last?.1,
       mapBounds.contains(firstP, projectionSize: projectionSize),
       mapBounds.contains(lastP, projectionSize: projectionSize) {
      var merged = raw.last!
      // The last piece's last point is the projection of the closing vertex,
      // which equals the first piece's first point — drop the duplicate.
      merged.append(contentsOf: raw.first!.dropFirst())
      var combined = Array(raw.dropFirst().dropLast())
      combined.append(merged)
      pieces = combined
    } else {
      pieces = raw
    }

    return pieces.map { piece -> [Point] in
      guard let first = piece.first, let last = piece.last, piece.count >= 2 else { return piece }
      if approxEqual(first, last) { return piece }
      var closed = piece
      closed.append(contentsOf: mapBounds.boundaryArc(from: last, to: first, projectionSize: projectionSize))
      return closed
    }
  }

  /// If the projected segment from `a` to `b` is so long it must have wrapped
  /// across the projection's seam (antimeridian or top/bottom), returns the
  /// shift needed to put `b` on the same side as `a` (i.e. on a virtual
  /// extended canvas). Returns `nil` for ordinary short segments.
  ///
  /// The threshold of half the projection size relies on the post-interpolation
  /// invariant that consecutive points are within `Interpolator.maxDiff` in
  /// projected space — a jump of `halfWidth` (or `halfHeight`) is far above
  /// any noise from interpolation.
  private static func wrapShift(from a: Point, to b: Point, projectionSize: Size) -> Point? {
    let halfW = projectionSize.width / 2
    let halfH = projectionSize.height / 2
    var dx: Double = 0, dy: Double = 0
    if a.x - b.x > halfW {
      dx = projectionSize.width
    } else if b.x - a.x > halfW {
      dx = -projectionSize.width
    }
    if a.y - b.y > halfH {
      dy = projectionSize.height
    } else if b.y - a.y > halfH {
      dy = -projectionSize.height
    }
    return (dx == 0 && dy == 0) ? nil : Point(x: dx, y: dy)
  }

  private static func approxEqual(_ a: Point, _ b: Point, eps: Double = 1e-9) -> Bool {
    abs(a.x - b.x) < eps && abs(a.y - b.y) < eps
  }
}
