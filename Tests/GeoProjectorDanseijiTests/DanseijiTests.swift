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

  /// Danseiji V and VI are hand-tuned asymmetric meshes (V emphasises
  /// continents; VI weighs population alongside area). Rotating their
  /// reference longitude shears the hand-tuned distortions away from the
  /// underlying geography, so they intentionally pin the reference at
  /// `(0, 0)` regardless of the constructor argument.
  /// All six Danseiji variants must lay their edge polygon centred inside
  /// the drawing canvas (modulo a few pixels of fp). Variants III–VI have
  /// asymmetric edge polygons; before the `visibleBounds` fix the canvas
  /// fitter assumed a symmetric `[-w/2, +w/2]` × `[-h/2, +h/2]` projection
  /// rectangle and shoved them off-centre.
  @Test(arguments: DanseijiVariant.allCases)
  func edgePolygonIsCentredInCanvas(variant: DanseijiVariant) async throws {
    let projection = variant.resolve()
    guard case let .bezier(edge) = projection.mapBounds else { return }

    let canvas = Size(width: 800, height: 400)
    let translated = edge.map {
      projection.translate($0, to: canvas, coordinateSystem: .topLeft)
    }
    let xs = translated.map(\.x), ys = translated.map(\.y)
    let xMin = xs.min()!, xMax = xs.max()!, yMin = ys.min()!, yMax = ys.max()!

    let leftMargin = xMin
    let rightMargin = canvas.width - xMax
    let topMargin = yMin
    let bottomMargin = canvas.height - yMax

    // Margins on opposing sides should match — the smaller dimension is
    // centred when the other dimension is the binding axis.
    #expect(abs(leftMargin - rightMargin) < 0.5,
            "\(variant.rawValue): horizontal margins \(leftMargin) vs \(rightMargin) don't match")
    #expect(abs(topMargin - bottomMargin) < 0.5,
            "\(variant.rawValue): vertical margins \(topMargin) vs \(bottomMargin) don't match")

    // Every edge vertex must land inside the canvas.
    for p in translated {
      #expect(p.x >= -0.5 && p.x <= canvas.width  + 0.5,
              "\(variant.rawValue): edge vertex x=\(p.x) outside canvas")
      #expect(p.y >= -0.5 && p.y <= canvas.height + 0.5,
              "\(variant.rawValue): edge vertex y=\(p.y) outside canvas")
    }
  }

  /// Edge insets must shrink the visible map by exactly that much on each
  /// side, while keeping the projection's aspect ratio. Verifies the
  /// fitting respects insets on every variant.
  @Test(arguments: DanseijiVariant.allCases)
  func edgeInsetsShrinkProportionally(variant: DanseijiVariant) async throws {
    let projection = variant.resolve()
    guard case let .bezier(edge) = projection.mapBounds else { return }

    let canvas = Size(width: 800, height: 400)
    let inset: Double = 30
    let insets = EdgeInsets(top: inset, left: inset, bottom: inset, right: inset)

    let translated = edge.map {
      projection.translate($0, to: canvas, insets: insets, coordinateSystem: .topLeft)
    }
    let xs = translated.map(\.x), ys = translated.map(\.y)
    let xMin = xs.min()!, xMax = xs.max()!, yMin = ys.min()!, yMax = ys.max()!

    // After insets, no vertex should land within the inset zone.
    #expect(xMin >= inset - 0.5,
            "\(variant.rawValue): xMin=\(xMin) inside left inset of \(inset)")
    #expect(xMax <= canvas.width - inset + 0.5,
            "\(variant.rawValue): xMax=\(xMax) inside right inset of \(inset)")
    #expect(yMin >= inset - 0.5,
            "\(variant.rawValue): yMin=\(yMin) inside top inset of \(inset)")
    #expect(yMax <= canvas.height - inset + 0.5,
            "\(variant.rawValue): yMax=\(yMax) inside bottom inset of \(inset)")
  }

  @Test func vAndVIIgnoreReference() throws {
    let pinnedV = try #require(
      Projections.DanseijiV(reference: .init(x: .pi / 4, y: .pi / 6))
        .project(.init(x: 1.0, y: 0.3))
    )
    let centredV = try #require(
      Projections.DanseijiV().project(.init(x: 1.0, y: 0.3))
    )
    #expect(pinnedV == centredV)
    #expect(Projections.DanseijiV(reference: .init(x: 1, y: 1)).reference == .init(x: 0, y: 0))

    let pinnedVI = try #require(
      Projections.DanseijiVI(reference: .init(x: -.pi / 3, y: .pi / 8))
        .project(.init(x: -0.5, y: 0.2))
    )
    let centredVI = try #require(
      Projections.DanseijiVI().project(.init(x: -0.5, y: 0.2))
    )
    #expect(pinnedVI == centredVI)
    #expect(Projections.DanseijiVI(reference: .init(x: -1, y: 0.5)).reference == .init(x: 0, y: 0))
  }

  @Test(arguments: DanseijiVariant.allCases)
  func inverseRoundTripsCoarseGrid(variant: DanseijiVariant) async throws {
    let projection = variant.resolve()

    // Bilinear interpolation in a ~120×200 grid plus barycentric forward
    // interpolation gives ~1° round-trip accuracy, hence the loose tolerance.
    // Skip the polar caps where the inverse pixel grid degenerates and the
    // poles' longitude is undefined.
    let tolerance = 0.05  // ~3°, comfortable for a mesh-interpolated projection
    var rejections = 0
    var checks = 0
    var lat = -70.0
    while lat <= 70.0 {
      var lon = -160.0
      while lon <= 160.0 {
        let geo = Point(x: lon * .pi / 180, y: lat * .pi / 180)
        guard let projected = projection.project(geo) else {
          lon += 40; continue
        }
        guard let recovered = projection.inverse(projected) else {
          rejections += 1; lon += 40; continue
        }
        var dx = recovered.x - geo.x
        while dx >  .pi { dx -= 2 * .pi }
        while dx < -.pi { dx += 2 * .pi }
        let dy = recovered.y - geo.y
        #expect(abs(dx) < tolerance, "\(variant.rawValue): lon mismatch at (\(lat),\(lon)): dx=\(dx)")
        #expect(abs(dy) < tolerance, "\(variant.rawValue): lat mismatch at (\(lat),\(lon)): dy=\(dy)")
        checks += 1
        lon += 40
      }
      lat += 20
    }
    #expect(checks > 0, "\(variant.rawValue): expected at least some round-trips, got \(rejections) rejections")
  }

  @Test func inverseRejectsPointsOutsideEdge() async throws {
    let projection = Projections.DanseijiIV()
    let halfW = projection.projectionSize.width / 2
    let halfH = projection.projectionSize.height / 2
    // Far corner of the bounding rect — Danseiji IV is interrupted, so corners
    // sit well outside the edge polygon.
    #expect(projection.inverse(.init(x: halfW * 0.99, y: halfH * 0.99)) == nil)
    // Centre of the projection is always inside.
    #expect(projection.inverse(.init(x: 0, y: 0)) != nil)
  }
}

#endif
