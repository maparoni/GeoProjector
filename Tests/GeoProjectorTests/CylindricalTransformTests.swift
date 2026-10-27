//
//  CylindricalTransformTests.swift
//
//
//  Created by Adrian Schönig on 28/10/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

#if canImport(Testing)
import Testing

import GeoJSONKit
@testable import GeoProjector

struct CylindricalTransformTests {

  private static let places: [Point] = [
    .init(x: 0, y: 0), .init(x: 2.6, y: -0.6), .init(x: -3.0, y: 0.9), .init(x: 1.2, y: 1.3),
  ]

  /// Projects with `from`, transforms, and checks against projecting with
  /// `to`, up to whole turns of longitude.
  private static func expectAgrees(_ from: Projection, _ to: Projection) throws {
    let transform = try #require(from.cylindricalTransform(to: to))
    let turn = 2 * .pi * (to.longitudeScale ?? 1)
    for place in places {
      let viaTransform = transform.apply(try #require(from.project(place)))
      let direct = try #require(to.project(place))
      var dx = (viaTransform.x - direct.x).truncatingRemainder(dividingBy: turn)
      if dx > turn / 2 { dx -= turn } else if dx < -turn / 2 { dx += turn }
      #expect(abs(dx) < 1e-9, "\(type(of: from)) x at \(place)")
      #expect(abs(viaTransform.y - direct.y) < 1e-9, "\(type(of: from)) y at \(place)")
    }
  }

  @Test func sameCylindricalProjectionsScaleAndShift() throws {
    try Self.expectAgrees(Projections.Mercator(reference: .init(x: 0.5, y: -0.6)), Projections.Mercator())
    try Self.expectAgrees(Projections.GallPeters(reference: .init(x: -2, y: 0.3)), Projections.GallPeters(reference: .init(x: 1, y: 0)))
    try Self.expectAgrees(Projections.Equirectangular(reference: .init(x: 2.8, y: 0.2)), Projections.Equirectangular())
    try Self.expectAgrees(
      Projections.Equirectangular(reference: GeoJSON.Position(latitude: 0, longitude: 40), phiOne: 30),
      Projections.Equirectangular(reference: GeoJSON.Position(latitude: 0, longitude: -20), phiOne: 0)
    )
  }

  @Test func anythingElseTakesTheRoundTrip() {
    let mercator = Projections.Mercator()
    #expect(mercator.cylindricalTransform(to: Projections.Equirectangular()) == nil)
    #expect(Projections.Orthographic().cylindricalTransform(to: mercator) == nil)
    #expect(Projections.NaturalEarth().cylindricalTransform(to: Projections.NaturalEarth()) == nil)
    #expect(Projections.Cassini().cylindricalTransform(to: Projections.Cassini()) == nil)
  }

  /// The width is the projected x range, so it must use the same
  /// (radian) standard parallel as `project`.
  @Test func equirectangularWidthMatchesItsStandardParallel() throws {
    let projection = Projections.Equirectangular(reference: GeoJSON.Position(latitude: 0, longitude: 0), phiOne: 60)
    #expect(abs(projection.projectionSize.width - .pi) < 1e-9)
    let east = try #require(projection.project(.init(x: .pi, y: 0)))
    #expect(abs(east.x - projection.projectionSize.width / 2) < 1e-9)
  }

  @Test func onlyEquatorAlignedCylindricalsHaveALongitudeScale() {
    #expect(Projections.Mercator().longitudeScale == 1)
    #expect(Projections.GallPeters().longitudeScale == 1)
    #expect(Projections.Equirectangular().longitudeScale == 1)
    #expect(Projections.Cassini().longitudeScale == nil)
    #expect(Projections.EqualEarth().longitudeScale == nil)
    #expect(Projections.Orthographic().longitudeScale == nil)
  }
}

#endif
