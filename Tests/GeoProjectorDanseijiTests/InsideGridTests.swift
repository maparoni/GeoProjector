//
//  InsideGridTests.swift
//
//
//  Created by Adrian Schönig on 28/10/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

#if canImport(Testing)
import Testing

import GeoProjector
@testable import GeoProjectorDanseiji

struct InsideGridTests {

  /// The grid is a shortcut: it must agree with walking the edge, everywhere
  /// including just outside the bounds and along the edge itself.
  @Test(arguments: DanseijiVariant.allCases)
  func gridAgreesWithWalkingTheEdge(variant: DanseijiVariant) throws {
    let data = DanseijiLoader.data(for: variant)
    let grid = try #require(data.edgeGrid)
    let b = data.edgeBounds
    var generator = SystemRandomNumberGenerator()
    var disagreements = 0
    for _ in 0..<50_000 {
      let p = Point(
        x: Double.random(in: (b.origin.x - 0.1)...(b.origin.x + b.size.width + 0.1), using: &generator),
        y: Double.random(in: (b.origin.y - 0.1)...(b.origin.y + b.size.height + 0.1), using: &generator))
      if grid.contains(p) != InsideGrid.walk(p, data.edge) { disagreements += 1 }
    }
    // Points near the edge itself: halfway along each segment, nudged.
    for i in data.edge.indices {
      let a = data.edge[i], c = data.edge[(i + 1) % data.edge.count]
      for nudge in [-1e-6, 1e-6] {
        let p = Point(x: (a.x + c.x) / 2 + nudge, y: (a.y + c.y) / 2 - nudge)
        if grid.contains(p) != InsideGrid.walk(p, data.edge) { disagreements += 1 }
      }
    }
    #expect(disagreements == 0)
  }

  /// Row crossings stand in for `MapBounds.contains` in the raster samplers.
  @Test(arguments: [DanseijiVariant.iv, .vi])
  func rowCrossingsAgreeWithContains(variant: DanseijiVariant) throws {
    let projection = variant.resolve()
    let size = projection.projectionSize
    var generator = SystemRandomNumberGenerator()
    var disagreements = 0
    for _ in 0..<200 {
      let y = Double.random(in: (-size.height / 2)...(size.height / 2), using: &generator)
      let row = try #require(projection.mapBounds.crossings(atY: y))
      for _ in 0..<200 {
        let p = Point(x: Double.random(in: (-size.width / 2)...(size.width / 2), using: &generator), y: y)
        if row.contains(p.x) != projection.mapBounds.contains(p, projectionSize: size) { disagreements += 1 }
      }
    }
    #expect(disagreements == 0)
    #expect(MapBounds.rectangle.crossings(atY: 0) == nil)
  }
}
#endif
