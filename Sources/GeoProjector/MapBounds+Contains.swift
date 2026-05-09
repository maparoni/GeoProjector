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
  public func contains(_ point: Point, projectionSize: Size) -> Bool {
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

  /// Returns the first crossing point of the segment from `a` to `b` with this
  /// boundary, walking from `a` toward `b`. Returns `nil` if the segment doesn't
  /// cross the boundary.
  ///
  /// All inputs are in the projection's internal radian coordinate system,
  /// centred at `(0, 0)` with half-extents `(projectionSize.width / 2,
  /// projectionSize.height / 2)`.
  public func firstIntersection(from a: Point, to b: Point, projectionSize: Size) -> Point? {
    allIntersections(from: a, to: b, projectionSize: projectionSize).first
  }

  /// Returns every crossing point of the segment from `a` to `b` with this
  /// boundary, ordered by distance from `a`. May be empty (no crossings) or
  /// contain two or more entries when a segment exits and re-enters via a
  /// concave region of a `bezier` boundary.
  public func allIntersections(from a: Point, to b: Point, projectionSize: Size) -> [Point] {
    let halfW = projectionSize.width  / 2
    let halfH = projectionSize.height / 2

    switch self {
    case .rectangle:
      let edges: [(Point, Point)] = [
        (.init(x: -halfW, y: -halfH), .init(x:  halfW, y: -halfH)),
        (.init(x:  halfW, y: -halfH), .init(x:  halfW, y:  halfH)),
        (.init(x:  halfW, y:  halfH), .init(x: -halfW, y:  halfH)),
        (.init(x: -halfW, y:  halfH), .init(x: -halfW, y: -halfH)),
      ]
      return MapBounds.allSegmentHits(from: a, to: b, against: edges)

    case .ellipse:
      return MapBounds.allEllipseHits(from: a, to: b, halfW: halfW, halfH: halfH)

    case .bezier(let pts):
      guard pts.count >= 2 else { return [] }
      var edges: [(Point, Point)] = []
      edges.reserveCapacity(pts.count)
      for i in 0..<pts.count {
        edges.append((pts[i], pts[(i + 1) % pts.count]))
      }
      return MapBounds.allSegmentHits(from: a, to: b, against: edges)
    }
  }

  /// Returns the polyline along this boundary from `a` to `b`, walking the
  /// shorter perimeter direction. Both endpoints are assumed to lie on the
  /// boundary (e.g. as produced by ``firstIntersection(from:to:projectionSize:)``);
  /// they are *not* included in the returned array — only the intermediate
  /// points needed to follow the boundary.
  public func boundaryArc(from a: Point, to b: Point, projectionSize: Size) -> [Point] {
    let halfW = projectionSize.width  / 2
    let halfH = projectionSize.height / 2

    switch self {
    case .rectangle:
      let corners: [Point] = [
        .init(x:  halfW, y: -halfH),
        .init(x:  halfW, y:  halfH),
        .init(x: -halfW, y:  halfH),
        .init(x: -halfW, y: -halfH),
      ]
      let tA = MapBounds.rectPerimeterParam(a, halfW: halfW, halfH: halfH)
      let tB = MapBounds.rectPerimeterParam(b, halfW: halfW, halfH: halfH)
      return MapBounds.walkClosedPath(from: tA, to: tB, period: 4) { idx in
        corners[idx % 4]
      }

    case .ellipse:
      let thetaA = atan2(a.y / halfH, a.x / halfW)
      let thetaB = atan2(b.y / halfH, b.x / halfW)
      var diff = thetaB - thetaA
      while diff >  .pi { diff -= 2 * .pi }
      while diff < -.pi { diff += 2 * .pi }
      let steps = max(1, Int(abs(diff) / (.pi / 24))) // ~7.5° per step
      var out: [Point] = []
      out.reserveCapacity(steps - 1)
      for i in 1..<steps {
        let t = thetaA + diff * Double(i) / Double(steps)
        out.append(.init(x: halfW * cos(t), y: halfH * sin(t)))
      }
      return out

    case .bezier(let pts):
      guard pts.count >= 3 else { return [] }
      let iA = MapBounds.nearestEdgeIndex(of: a, in: pts)
      let iB = MapBounds.nearestEdgeIndex(of: b, in: pts)
      // We're between vertex iA and iA+1 for `a`, between iB and iB+1 for `b`.
      // Walking forward emits vertices iA+1, iA+2, ..., iB.
      // Walking backward emits vertices iA, iA-1, ..., iB+1.
      let n = pts.count
      let forwardLen = (iB - iA + n) % n
      let backwardLen = (iA - iB + n) % n
      var out: [Point] = []
      if forwardLen <= backwardLen {
        var k = (iA + 1) % n
        var emitted = 0
        while emitted < forwardLen {
          out.append(pts[k])
          k = (k + 1) % n
          emitted += 1
        }
      } else {
        var k = iA
        var emitted = 0
        while emitted < backwardLen {
          out.append(pts[k])
          k = (k - 1 + n) % n
          emitted += 1
        }
      }
      return out
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

  // MARK: - Geometry helpers

  /// Returns the segment-segment intersection of (a, b) and (c, d) if any,
  /// strictly between the endpoints. Endpoints touching count as intersections.
  private static func segmentIntersection(_ a: Point, _ b: Point, _ c: Point, _ d: Point) -> Point? {
    let r = Point(x: b.x - a.x, y: b.y - a.y)
    let s = Point(x: d.x - c.x, y: d.y - c.y)
    let denom = r.x * s.y - r.y * s.x
    if abs(denom) < 1e-15 { return nil }
    let qp = Point(x: c.x - a.x, y: c.y - a.y)
    let t = (qp.x * s.y - qp.y * s.x) / denom
    let u = (qp.x * r.y - qp.y * r.x) / denom
    let eps = 1e-12
    guard t >= -eps && t <= 1 + eps && u >= -eps && u <= 1 + eps else { return nil }
    return Point(x: a.x + t * r.x, y: a.y + t * r.y)
  }

  /// Returns every intersection of (a, b) with the listed edges, ordered by
  /// distance from `a`. Near-duplicate hits (e.g. a segment passing exactly
  /// through a vertex registers twice) are collapsed.
  private static func allSegmentHits(from a: Point, to b: Point, against edges: [(Point, Point)]) -> [Point] {
    var hits: [(Point, Double)] = []
    for (c, d) in edges {
      guard let hit = segmentIntersection(a, b, c, d) else { continue }
      let dx = hit.x - a.x, dy = hit.y - a.y
      hits.append((hit, dx * dx + dy * dy))
    }
    hits.sort { $0.1 < $1.1 }
    var unique: [Point] = []
    for (p, _) in hits {
      if let prev = unique.last, abs(prev.x - p.x) < 1e-9, abs(prev.y - p.y) < 1e-9 {
        continue
      }
      unique.append(p)
    }
    return unique
  }

  /// Returns every intersection of (a, b) with the unit ellipse, ordered by
  /// distance from `a`.
  private static func allEllipseHits(from a: Point, to b: Point, halfW: Double, halfH: Double) -> [Point] {
    // Normalise to unit circle: x' = x/halfW, y' = y/halfH.
    let ax = a.x / halfW, ay = a.y / halfH
    let bx = b.x / halfW, by = b.y / halfH
    let dx = bx - ax, dy = by - ay
    // |a + t*(b-a)|^2 = 1  =>  (dx²+dy²) t² + 2(ax·dx + ay·dy) t + (ax²+ay²-1) = 0
    let A = dx * dx + dy * dy
    let B = 2 * (ax * dx + ay * dy)
    let C = ax * ax + ay * ay - 1
    let disc = B * B - 4 * A * C
    guard disc >= 0, A > 1e-15 else { return [] }
    let sq = disc.squareRoot()
    let t1 = (-B - sq) / (2 * A)
    let t2 = (-B + sq) / (2 * A)
    let eps = 1e-12
    let ts = [t1, t2].filter { $0 >= -eps && $0 <= 1 + eps }.sorted()
    return ts.map { t in
      let nx = ax + t * dx
      let ny = ay + t * dy
      return Point(x: nx * halfW, y: ny * halfH)
    }
  }

  /// Maps a point on the rectangle perimeter to a parameter in `[0, 4)`,
  /// counting one unit per edge starting at `(halfW, -halfH)` going CCW.
  private static func rectPerimeterParam(_ p: Point, halfW: Double, halfH: Double) -> Double {
    let eps = 1e-9
    if abs(p.x - halfW) < eps { // right edge: y goes -halfH → halfH
      return (p.y + halfH) / (2 * halfH)
    }
    if abs(p.y - halfH) < eps { // top edge: x goes halfW → -halfW
      return 1 + (halfW - p.x) / (2 * halfW)
    }
    if abs(p.x + halfW) < eps { // left edge: y goes halfH → -halfH
      return 2 + (halfH - p.y) / (2 * halfH)
    }
    if abs(p.y + halfH) < eps { // bottom edge: x goes -halfW → halfW
      return 3 + (p.x + halfW) / (2 * halfW)
    }
    // Off-edge: snap to nearest edge by clamping. Shouldn't hit if caller is
    // honest about p being on the boundary.
    return 0
  }

  /// Walks a closed-path parameter from `tA` to `tB` along the shorter
  /// direction (period = total perimeter / corners), emitting each integer
  /// boundary crossing. Endpoints not included.
  private static func walkClosedPath(from tA: Double, to tB: Double, period: Int, vertex: (Int) -> Point) -> [Point] {
    let p = Double(period)
    var diff = tB - tA
    while diff >  p / 2 { diff -= p }
    while diff < -p / 2 { diff += p }
    var out: [Point] = []
    if diff >= 0 {
      var k = Int(floor(tA)) + 1
      while Double(k) < tA + diff {
        out.append(vertex(k % period))
        k += 1
      }
    } else {
      var k = Int(ceil(tA)) - 1
      while Double(k) > tA + diff {
        out.append(vertex((k % period + period) % period))
        k -= 1
      }
    }
    return out
  }

  /// Returns the index `i` such that `p` lies (or is closest to lying) on the
  /// edge from `polygon[i]` to `polygon[(i+1) % count]`.
  private static func nearestEdgeIndex(of p: Point, in polygon: [Point]) -> Int {
    var bestIdx = 0
    var bestDist = Double.infinity
    let n = polygon.count
    for i in 0..<n {
      let a = polygon[i], b = polygon[(i + 1) % n]
      let dx = b.x - a.x, dy = b.y - a.y
      let len2 = dx * dx + dy * dy
      let t: Double
      if len2 < 1e-15 {
        t = 0
      } else {
        t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2))
      }
      let cx = a.x + t * dx
      let cy = a.y + t * dy
      let ex = p.x - cx, ey = p.y - cy
      let d = ex * ex + ey * ey
      if d < bestDist {
        bestDist = d
        bestIdx = i
      }
    }
    return bestIdx
  }
}
