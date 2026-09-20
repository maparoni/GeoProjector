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

  /// Restores the invariant that consecutive points are close in *projected*
  /// space, which ``interpolateInto(from:aProj:to:bProj:diffSquared:projector:output:)``
  /// deliberately breaks.
  ///
  /// That shortcut stops subdividing the moment the projected midpoint agrees
  /// with the straight-line midpoint. For drawing that's right and cheap — the
  /// segment really is straight — but it can leave two adjacent output points
  /// arbitrarily far apart whenever the projection happens to be linear over a
  /// long span. Downstream code that reads the gap between consecutive points
  /// as a signal (antimeridian wrap detection) then can't tell "linear over a
  /// long span" from "jumped across a seam".
  ///
  /// This pass bisects any pair further apart than `maxProjectedStep` on either
  /// axis. A smooth span closes up after a couple of levels; a genuine
  /// discontinuity never does, so recursion stops at `minUnprojectedStep` and
  /// leaves a tight jump straddling the seam — exactly what wrap detection
  /// wants to see.
  ///
  /// - Parameters:
  ///   - points: `(unprojected, projected)` pairs, in order.
  ///   - maxProjectedStep: Per-axis gap to subdivide below, in projected units.
  ///   - minUnprojectedStep: Recursion floor, in unprojected radians.
  public static func densify(
    _ points: [(Point, Point?)],
    maxProjectedStep: Point,
    minUnprojectedStep: Double,
    projector: (Point) -> Point?
  ) -> [(Point, Point?)] {
    guard points.count >= 2 else { return points }
    let minStepSquared = minUnprojectedStep * minUnprojectedStep

    var output: [(Point, Point?)] = []
    output.reserveCapacity(points.count)
    output.append(points[0])
    for i in 1..<points.count {
      densifyInto(
        from: points[i - 1], to: points[i],
        maxProjectedStep: maxProjectedStep, minStepSquared: minStepSquared,
        projector: projector, output: &output
      )
      output.append(points[i])
    }
    return output
  }

  private static func densifyInto(
    from a: (Point, Point?), to b: (Point, Point?),
    maxProjectedStep: Point, minStepSquared: Double,
    projector: (Point) -> Point?,
    output: inout [(Point, Point?)]
  ) {
    // An unprojectable endpoint is already handled downstream as "outside";
    // there's nothing to measure a gap against.
    guard let aProj = a.1, let bProj = b.1 else { return }
    if abs(aProj.x - bProj.x) <= maxProjectedStep.x,
       abs(aProj.y - bProj.y) <= maxProjectedStep.y { return }
    // Can't resolve further: this is a genuine discontinuity, and the tight
    // jump left behind is the signal wrap detection needs.
    if pathDistanceSquared(a.0, b.0) <= minStepSquared { return }

    let c = pathHalfway(a.0, b.0)
    let cPair = (c, projector(c))
    densifyInto(from: a, to: cPair, maxProjectedStep: maxProjectedStep,
                minStepSquared: minStepSquared, projector: projector, output: &output)
    output.append(cPair)
    densifyInto(from: cPair, to: b, maxProjectedStep: maxProjectedStep,
                minStepSquared: minStepSquared, projector: projector, output: &output)
  }

  /// Longitude delta along the path the geometry is meant to follow: the
  /// shorter way round, since an edge from 170° to -170° means the 20° hop
  /// across the antimeridian, not the 340° trip back through 0°.
  ///
  /// An edge spanning a full 360° is the exception — it means "all the way
  /// round" (a graticule parallel given as -180°→180°), so it keeps its long
  /// path instead of collapsing to zero.
  private static func pathDeltaX(_ a: Point, _ b: Point) -> Double {
    let fullSweep = 2 * Double.pi
    var dx = b.x - a.x
    guard abs(abs(dx) - fullSweep) > 1e-6 else { return dx }
    if dx > .pi {
      dx -= fullSweep
    } else if dx < -.pi {
      dx += fullSweep
    }
    return dx
  }

  private static func pathHalfway(_ a: Point, _ b: Point) -> Point {
    var x = a.x + pathDeltaX(a, b) / 2
    if x > .pi {
      x -= 2 * .pi
    } else if x < -.pi {
      x += 2 * .pi
    }
    return Point(x: x, y: (a.y + b.y) * 0.5)
  }

  private static func pathDistanceSquared(_ a: Point, _ b: Point) -> Double {
    let dx = pathDeltaX(a, b)
    let dy = b.y - a.y
    return dx * dx + dy * dy
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
