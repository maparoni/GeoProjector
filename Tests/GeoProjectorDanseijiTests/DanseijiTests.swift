//
//  DanseijiTests.swift
//  GeoProjectorDanseiji
//

#if canImport(Testing)
import Testing
import Foundation

import GeoProjector
@testable import GeoProjectorDanseiji

struct DanseijiTests {

  @Test(arguments: DanseijiVariant.allCases)
  func loadsAndExposesValidBounds(variant: DanseijiVariant) async throws {
    let projection = variant.resolve()

    #expect(projection.projectionSize.width > 0)
    #expect(projection.projectionSize.height > 0)

    guard case let .bezier(points) = projection.mapBounds else {
      Issue.record("Expected .bezier mapBounds for \(variant.rawValue)")
      return
    }
    #expect(points.count > 100, "Edge polygon for \(variant.rawValue) seems too sparse: \(points.count)")

    // Every edge point should sit inside the declared projection size.
    for p in points {
      #expect(abs(p.x) <= projection.projectionSize.width / 2 + 1e-9)
      #expect(abs(p.y) <= projection.projectionSize.height / 2 + 1e-9)
    }
  }

  @Test(arguments: DanseijiVariant.allCases)
  func projectsOriginNearOrigin(variant: DanseijiVariant) async throws {
    let projection = variant.resolve()
    let projected = try #require(projection.project(.init(x: 0, y: 0)))
    // The mesh centre is close to (0,0) but not exactly there because the
    // origin lies on a cell boundary; a couple of mesh-cell widths is fine.
    #expect(abs(projected.x) < 0.1, "x off for \(variant.rawValue): \(projected.x)")
    #expect(abs(projected.y) < 0.1, "y off for \(variant.rawValue): \(projected.y)")
  }

  @Test(arguments: DanseijiVariant.allCases)
  func projectsRangeOfPoints(variant: DanseijiVariant) async throws {
    let projection = variant.resolve()

    // Sample a coarse grid over the sphere and confirm the projection succeeds
    // and stays within the projection size for every point.
    var lat = -.pi / 2 + 0.01
    while lat <= .pi / 2 - 0.01 {
      var lon = -.pi + 0.01
      while lon <= .pi - 0.01 {
        let projected = try #require(projection.project(.init(x: lon, y: lat)),
                                     "nil projection for lat=\(lat) lon=\(lon) in \(variant.rawValue)")
        #expect(abs(projected.x) <= projection.projectionSize.width / 2 + 1e-6)
        #expect(abs(projected.y) <= projection.projectionSize.height / 2 + 1e-6)
        lon += .pi / 8
      }
      lat += .pi / 8
    }
  }

  @Test func variantsLoadDistinctData() async throws {
    // Sanity: at least two variants should produce different outputs for the
    // same input — guards against the cache returning the wrong file.
    let pIII = try #require(Projections.DanseijiIII().project(.init(x: 1.0, y: 0.5)))
    let pIV  = try #require(Projections.DanseijiIV().project(.init(x: 1.0, y: 0.5)))
    #expect(pIII != pIV)
  }

  @Test func longitudeReferenceShiftsMap() async throws {
    let centred = try #require(Projections.DanseijiIII().project(.init(x: 0, y: 0)))
    let shifted = try #require(
      Projections.DanseijiIII(reference: .init(x: .pi / 4, y: 0))
        .project(.init(x: .pi / 4, y: 0))
    )
    // Re-centring on a point should map that point to roughly the projection's
    // origin — well within the cell-boundary tolerance.
    #expect(abs(shifted.x - centred.x) < 0.1)
    #expect(abs(shifted.y - centred.y) < 0.1)
  }
}

#endif
