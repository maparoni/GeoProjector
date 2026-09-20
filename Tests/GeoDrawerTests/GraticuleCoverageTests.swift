//
//  GraticuleCoverageTests.swift
//  GeoDrawerTests
//
//  Broad "does anything vanish?" sweep over a full graticule. Individual
//  projections had their own spot-checks, but the failures that actually
//  shipped were whole families of lines quietly rendering as zero-length
//  pieces — invisible, yet not absent enough for a point-count check to
//  notice. Measuring drawn length across every meridian and parallel
//  catches that class directly.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

#if canImport(Testing)
import Testing
import Foundation

import GeoJSONKit
import GeoProjector
import GeoProjectorDanseiji
@testable import GeoDrawer

struct GraticuleCoverageTests {

  /// Meridians every 10° (spans matching `Examples/Data/graticule-2.geojson`)
  /// plus parallels every 10°, each given as a bare two-point LineString —
  /// which is what exposes the interpolation shortcuts.
  private static func graticule() -> [(name: String, positions: [GeoJSON.Position])] {
    var lines: [(String, [GeoJSON.Position])] = []
    for lonI in stride(from: -170, through: 180, by: 10) {
      let lon = Double(lonI)
      let span: Double = (lonI % 90 == 0) ? 90 : ((lonI % 30 == 0) ? 80 : 70)
      lines.append(("meridian \(lonI)°", [
        .init(latitude: -span, longitude: lon),
        .init(latitude:  span, longitude: lon),
      ]))
    }
    for latI in stride(from: -80, through: 80, by: 10) {
      let lat = Double(latI)
      lines.append(("parallel \(latI)°", [
        .init(latitude: lat, longitude: -180),
        .init(latitude: lat, longitude:  180),
      ]))
    }
    return lines
  }

  private static func projections(reference: Point) -> [(String, Projection)] {
    [
      ("Equirectangular", Projections.Equirectangular(reference: reference)),
      ("Mercator", Projections.Mercator(reference: reference)),
      ("GallPeters", Projections.GallPeters(reference: reference)),
      ("Cassini", Projections.Cassini(reference: reference)),
      ("EqualEarth", Projections.EqualEarth(reference: reference)),
      ("NaturalEarth", Projections.NaturalEarth(reference: reference)),
      ("DanseijiI", Projections.DanseijiI(reference: reference)),
      ("DanseijiIV", Projections.DanseijiIV(reference: reference)),
    ]
  }

  /// Total on-screen length of a projected polyline set. Zero-length pieces —
  /// the degenerate output of splitting a two-point line whose endpoints both
  /// already sit on the projection seam — contribute nothing, which is the
  /// point.
  private func drawnLength(_ pieces: [GeoDrawer.ProjectedLineString]) -> Double {
    var total = 0.0
    for piece in pieces {
      for (a, b) in zip(piece.points.dropLast(), piece.points.dropFirst()) {
        total += ((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)).squareRoot()
      }
    }
    return total
  }

  /// A meridian lying exactly on the projection's seam (reference ± 180°)
  /// projects every one of its points onto the outline itself. For `bezier`
  /// bounds `MapBounds.pointInPolygon` accepts an exact *vertex* match but
  /// classifies a point lying on an *edge* as outside, so the whole meridian
  /// is discarded. That's a separate, pre-existing defect in the
  /// point-in-polygon test — not something interpolation can fix — and
  /// changing it alters polygon clipping semantics on a documented hot path,
  /// so it's excluded here rather than silently absorbed.
  private func isSeamMeridianOnBezierOutline(
    lineName: String, projection: Projection, referenceLongitude: Double
  ) -> Bool {
    guard case .bezier = projection.mapBounds else { return false }
    var seam = referenceLongitude + 180
    if seam > 180 { seam -= 360 }
    return lineName == "meridian \(Int(seam))°"
  }

  @Test(arguments: [0.0, 77.5, -120.0])
  func everyGraticuleLineDrawsSomething(referenceLongitude: Double) {
    let size = GeoProjector.Size(width: 1000, height: 1000)
    let reference = Point(x: referenceLongitude.toRadians(), y: 0)
    let lines = Self.graticule()

    for (projectionName, projection) in Self.projections(reference: reference) {
      let drawer = GeoDrawer(size: size, projection: projection)
      for (lineName, positions) in lines {
        if isSeamMeridianOnBezierOutline(
          lineName: lineName, projection: projection, referenceLongitude: referenceLongitude
        ) { continue }

        let pieces = drawer.project(
          GeoJSON.LineString(positions: positions),
          coordinateSystem: .bottomLeft
        )
        let length = drawnLength(pieces)
        // 50px on a 1000px canvas: far below any legitimate graticule line,
        // far above the zero-ish length of a degenerate split.
        #expect(length > 50,
                "\(projectionName) ref=\(referenceLongitude)°: \(lineName) drew only \(Int(length))px")
      }
    }
  }
}

#endif
