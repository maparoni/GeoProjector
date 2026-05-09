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
  /// Inputs are `(unprojected radians, projected radians)` pairs as produced by
  /// `Self.projectLine(...)`. The synthesised boundary points carry `nil` for
  /// the unprojected coordinate — callers don't read it after this stage.
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
        switch (prev.inside, inside) {
        case (true, true):
          break
        case (true, false):
          // Leaving the visible region: anchor the current arc on the boundary.
          if let prevP = prev.proj, let p = proj,
             let exit = mapBounds.firstIntersection(from: prevP, to: p, projectionSize: projectionSize) {
            current.append(exit)
          }
          if !current.isEmpty {
            pieces.append(current)
            current = []
          }
        case (false, true):
          // Re-entering: start the next arc at the boundary entry point.
          if let prevP = prev.proj, let p = proj,
             let entry = mapBounds.firstIntersection(from: p, to: prevP, projectionSize: projectionSize) {
            current.append(entry)
          }
        case (false, false):
          // Both outside. v1: drop. (Could check whether the segment passes
          // through the visible region, but that's rare for short post-
          // interpolation segments.)
          break
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
  /// If the input never crosses the boundary the result is the single
  /// already-closed ring it started as.
  static func boundarySplitClosed(
    _ projected: [(Point, Point?)],
    mapBounds: MapBounds,
    projectionSize: Size
  ) -> [[Point]] {
    let pieces = boundarySplit(projected, mapBounds: mapBounds, projectionSize: projectionSize)

    return pieces.map { piece -> [Point] in
      guard let first = piece.first, let last = piece.last, piece.count >= 2 else { return piece }
      // If the piece already closes on itself (e.g. unsplit polygon), don't
      // re-walk the boundary.
      if approxEqual(first, last) { return piece }
      var closed = piece
      closed.append(contentsOf: mapBounds.boundaryArc(from: last, to: first, projectionSize: projectionSize))
      return closed
    }
  }

  private static func approxEqual(_ a: Point, _ b: Point, eps: Double = 1e-9) -> Bool {
    abs(a.x - b.x) < eps && abs(a.y - b.y) < eps
  }
}
