//
//  Interpolator.swift
//  
//
//  Created by Adrian Schönig on 9/12/2022.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2022 Corporoni Pty Ltd. See LICENSE.

import Foundation


public enum Interpolator {
  
  /// Interpolates from a to b using the provided projector method, adding new points whenever the
  /// projected point differs more than `maxDiff` from the straight-line from a to b
  ///
  /// - Parameters:
  ///   - a: Unprojected start point, typically with x as longitude in radians, y as latitude in radians
  ///   - b: Unprojected end point, typically with x as longitude in radians, y as latitude in radians
  ///   - maxDiff: Maximum distance
  ///   - projector: Projector handler that should return a projected point for an unprojected point
  /// - Returns: List of (unprojected, projected) pairs to add in between a and b
  public static func interpolate(from a: Point, to b: Point, maxDiff: Double, projector: (Point) -> Point?) -> [(Point, Point)] {
    var output: [(Point, Point)] = []
    legacyInterpolate(
      from: a, aProj: projector(a),
      to: b, bProj: projector(b),
      diffSquared: maxDiff * maxDiff,
      projector: projector,
      output: &output
    )
    return output
  }

  /// Internal recursion that reuses already-computed endpoint projections so
  /// each unprojected point gets projected once, not three times per
  /// recursion level. The output array carries `(unprojected, projected)`
  /// pairs and is appended to in left-to-right order.
  ///
  /// Public so that `projectLine`-style callers can pre-project the polygon's
  /// vertices once (in a flat sweep) and feed the projections in here. The
  /// public `interpolate(from:to:maxDiff:projector:)` wrapper is convenient
  /// for callers without that bookkeeping.
  public static func interpolateInto(
    from a: Point, aProj: Point?,
    to b: Point, bProj: Point?,
    diffSquared: Double,
    projector: (Point) -> Point?,
    output: inout [(Point, Point?)]
  ) {
    if a.distanceSquared(to: b) <= diffSquared { return }

    let c = a.halfway(to: b)
    let cProj = projector(c)

    if let aProj, let bProj, let cProj {
      let cTriv = aProj.halfway(to: bProj)
      if cProj.distanceSquared(to: cTriv) <= diffSquared { return }
    }

    interpolateInto(from: a, aProj: aProj, to: c, bProj: cProj,
                    diffSquared: diffSquared, projector: projector, output: &output)
    output.append((c, cProj))
    interpolateInto(from: c, aProj: cProj, to: b, bProj: bProj,
                    diffSquared: diffSquared, projector: projector, output: &output)
  }

  // Legacy 4-arg wrapper kept for compatibility (used by projection setup
  // for bezier outline generation, etc.).
  private static func legacyInterpolate(
    from a: Point, aProj: Point?,
    to b: Point, bProj: Point?,
    diffSquared: Double,
    projector: (Point) -> Point?,
    output: inout [(Point, Point)]
  ) {
    if a.distanceSquared(to: b) <= diffSquared { return }

    let c = a.halfway(to: b)
    let cProj = projector(c)

    if let aProj, let bProj, let cProj {
      let cTriv = aProj.halfway(to: bProj)
      if cProj.distanceSquared(to: cTriv) <= diffSquared { return }
    }

    legacyInterpolate(from: a, aProj: aProj, to: c, bProj: cProj,
                      diffSquared: diffSquared, projector: projector, output: &output)
    if let cProj { output.append((c, cProj)) }
    legacyInterpolate(from: c, aProj: cProj, to: b, bProj: bProj,
                      diffSquared: diffSquared, projector: projector, output: &output)
  }

}

extension Point {

  @inline(__always)
  func halfway(to b: Point) -> Point {
    Point(x: (x + b.x) * 0.5, y: (y + b.y) * 0.5)
  }

  @inline(__always)
  func distanceSquared(to b: Point) -> Double {
    let dx = b.x - x
    let dy = b.y - y
    return dx * dx + dy * dy
  }

}
