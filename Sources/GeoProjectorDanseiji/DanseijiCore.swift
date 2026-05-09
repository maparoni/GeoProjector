//
//  DanseijiCore.swift
//  GeoProjectorDanseiji
//
//  Forward-projection algorithm for the Danseiji mesh-based projections.
//  Port of `DanseijiProjection.project` from
//  https://github.com/jkunimune/Map-Projections/blob/master/src/maps/Danseiji.java
//

import Foundation
import GeoProjector

enum DanseijiCore {
  /// Wraps `point.x` (longitude) into `[-pi, pi]` relative to `reference`.
  /// Latitude reference is intentionally ignored: the mesh data is computed
  /// for a fixed orientation and remeshing is out of scope.
  static func adjusted(_ point: Point, reference: Point) -> Point {
    var x = point.x - reference.x
    if x < -.pi {
      x += 2 * .pi
    } else if x > .pi {
      x -= 2 * .pi
    }
    return Point(x: x, y: point.y)
  }

  /// Wraps an unbounded longitude (radians) back into `[-pi, pi]`.
  static func wrapLongitude(_ x: Double) -> Double {
    var v = x
    while v >  .pi { v -= 2 * .pi }
    while v < -.pi { v += 2 * .pi }
    return v
  }

  /// Forward projection for a point already adjusted relative to the reference.
  /// Returns nil only if the input falls in a cell whose triangulation rejects
  /// it (shouldn't happen for points in `[-pi, pi] x [-pi/2, pi/2]`).
  static func project(_ point: Point, data: DanseijiData) -> Point? {
    let nRows = data.cells.count
    let nCols = data.cells[0].count

    let lat = point.y
    let lon = point.x

    var i = Int(((.pi / 2) - lat) / .pi * Double(nRows))
    i = max(0, min(nRows - 1, i))
    var j = Int((lon + .pi) / (2 * .pi) * Double(nCols))
    j = max(0, min(nCols - 1, j))

    let pN = .pi / 2 - Double(i) * .pi / Double(nRows)
    let pS = .pi / 2 - Double(i + 1) * .pi / Double(nRows)

    let yS = Double(i + 1) - ((.pi / 2) - lat) / .pi * Double(nRows)
    var xS = (lon + .pi) / (2 * .pi) * Double(nCols) - (Double(j) + 0.5)
    xS *= yS * cos(pN) + (1 - yS) * cos(pS)

    let vSnw = Point(x: -0.5 * cos(pN), y: 1)
    let vSne = Point(x:  0.5 * cos(pN), y: 1)
    let vSsw = Point(x: -0.5 * cos(pS), y: 0)
    let vSse = Point(x:  0.5 * cos(pS), y: 0)

    let cell = data.cells[i][j]
    let vP = cell.vertices

    let triPairs: [(triS: [Point], triP: [Point])]
    if cell.shape < 0 {
      triPairs = [
        (triS: [vSne, vSnw, vSse], triP: [vP[0], vP[1], vP[5]]),
        (triS: [vSsw, vSse, vSnw], triP: [vP[3], vP[4], vP[2]]),
      ]
    } else if cell.shape > 0 {
      triPairs = [
        (triS: [vSse, vSne, vSsw], triP: [vP[5], vP[0], vP[4]]),
        (triS: [vSnw, vSsw, vSne], triP: [vP[2], vP[3], vP[1]]),
      ]
    } else if i < nRows / 2 {
      triPairs = [
        (triS: [vSnw, vSsw, vSse], triP: [vP[1], vP[2], vP[3]]),
      ]
    } else {
      triPairs = [
        (triS: [vSsw, vSne, vSnw], triP: [vP[2], vP[0], vP[1]]),
      ]
    }

    for (triS, triP) in triPairs {
      let detT =
        (triS[1].y - triS[2].y) * (triS[2].x - triS[0].x)
        + (triS[2].x - triS[1].x) * (triS[2].y - triS[0].y)
      let c0 =
        ((triS[1].y - triS[2].y) * (triS[2].x - xS)
         + (triS[2].x - triS[1].x) * (triS[2].y - yS)) / detT
      if c0 < 0 { continue }
      let c1 =
        ((triS[2].y - triS[0].y) * (triS[2].x - xS)
         + (triS[0].x - triS[2].x) * (triS[2].y - yS)) / detT
      let c2 = 1 - c0 - c1
      return Point(
        x: c0 * triP[0].x + c1 * triP[1].x + c2 * triP[2].x,
        y: c0 * triP[0].y + c1 * triP[1].y + c2 * triP[2].y
      )
    }

    return nil
  }

  /// Inverse projection. Maps a projected point (radians, in the projection's
  /// internal coordinate system) back to a geographic coordinate `(lon, lat)`
  /// in radians, or returns `nil` if the input lies outside the projection's
  /// edge polygon.
  ///
  /// Port of `DanseijiProjection.inverse` from upstream `Danseiji.java`: a
  /// point-in-polygon test followed by bilinear interpolation in the pre-baked
  /// `pixels` lookup grid, in 3-D Cartesian space so meridians at the poles
  /// don't blow up.
  static func inverse(_ point: Point, data: DanseijiData, reference: Point) -> Point? {
    if !pointInPolygon(point, polygon: data.edge) {
      return nil
    }

    let pixels = data.pixels
    guard let firstRow = pixels.first, !firstRow.isEmpty else { return nil }
    let nRows = pixels.count
    let nCols = firstRow.count

    let bounds = data.edgeBounds
    let xMin = bounds.origin.x
    let xMax = xMin + bounds.size.width
    let yMin = bounds.origin.y
    let yMax = yMin + bounds.size.height

    let iF = (yMax - point.y) / (yMax - yMin) * Double(nRows - 1)
    let jF = (point.x - xMin) / (xMax - xMin) * Double(nCols - 1)
    let i0 = max(0, min(nRows - 2, Int(iF)))
    let j0 = max(0, min(nCols - 2, Int(jF)))
    let cy = max(0.0, min(1.0, iF - Double(i0)))
    let cx = max(0.0, min(1.0, jF - Double(j0)))

    var X = 0.0, Y = 0.0, Z = 0.0
    for di in 0...1 {
      for dj in 0...1 {
        let weight = (di == 0 ? 1 - cy : cy) * (dj == 0 ? 1 - cx : cx)
        let sample = pixels[i0 + di][j0 + dj]
        X += weight * cos(sample.phi) * cos(sample.lam)
        Y += weight * cos(sample.phi) * sin(sample.lam)
        Z += weight * sin(sample.phi)
      }
    }

    let phi = atan2(Z, (X * X + Y * Y).squareRoot())
    let lam = atan2(Y, X)
    return Point(x: wrapLongitude(lam + reference.x), y: phi)
  }

  /// Standard ray-casting point-in-polygon test (inclusive of vertices).
  private static func pointInPolygon(_ p: Point, polygon: [Point]) -> Bool {
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
