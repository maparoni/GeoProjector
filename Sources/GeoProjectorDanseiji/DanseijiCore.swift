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

  static func willWrap(_ point: Point, reference: Point) -> Bool {
    let dx = point.x - reference.x
    return dx < -.pi || dx > .pi
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
}
