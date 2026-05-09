#if canImport(Testing)
import Testing
import Foundation

import GeoJSONKit
@testable import GeoProjector

struct InverseTests {

  // Sample lat/lon grid (degrees), kept inside every projection's domain
  // so that even Mercator (clipped at ±85.05°) is happy.
  private static let grid: [(lat: Double, lon: Double)] = stride(from: -80.0, through: 80.0, by: 20).flatMap { lat in
    stride(from: -170.0, through: 170.0, by: 30).map { lon in (lat, lon) }
  }

  private func roundTrip<P: Projection>(_ proj: P, tolerance: Double, label: String) {
    for (lat, lon) in Self.grid {
      let geo = Point(x: lon * .pi / 180, y: lat * .pi / 180)
      guard let projected = proj.project(geo) else { continue }
      guard let recovered = proj.inverse(projected) else {
        Issue.record("\(label): inverse returned nil for valid projected point at (\(lat),\(lon))")
        continue
      }
      var dx = recovered.x - geo.x
      while dx >  .pi { dx -= 2 * .pi }
      while dx < -.pi { dx += 2 * .pi }
      let dy = recovered.y - geo.y
      // At |lat| → 90° longitude becomes degenerate; relax that one.
      let lonTolerance = abs(lat) >= 89.9 ? 1e-3 : tolerance
      #expect(abs(dx) < lonTolerance, "\(label): lon mismatch at (\(lat),\(lon)): dx=\(dx)")
      #expect(abs(dy) < tolerance,    "\(label): lat mismatch at (\(lat),\(lon)): dy=\(dy)")
    }
  }

  @Test func equirectangularRoundTrip() {
    roundTrip(Projections.Equirectangular(), tolerance: 1e-9, label: "Equirectangular")
  }

  @Test func cassiniRoundTrip() {
    roundTrip(Projections.Cassini(), tolerance: 1e-9, label: "Cassini")
  }

  @Test func mercatorRoundTrip() {
    roundTrip(Projections.Mercator(), tolerance: 1e-9, label: "Mercator")
  }

  @Test func gallPetersRoundTrip() {
    roundTrip(Projections.GallPeters(), tolerance: 1e-9, label: "GallPeters")
  }

  @Test func azimuthalRoundTrip() {
    roundTrip(Projections.AzimuthalEquidistant(), tolerance: 1e-9, label: "AzimuthalEquidistant")
  }

  @Test func orthographicRoundTrip() {
    roundTrip(Projections.Orthographic(), tolerance: 1e-9, label: "Orthographic")
  }

  @Test func equalEarthRoundTrip() {
    roundTrip(Projections.EqualEarth(), tolerance: 1e-6, label: "EqualEarth")
  }

  @Test func naturalEarthRoundTrip() {
    roundTrip(Projections.NaturalEarth(), tolerance: 1e-6, label: "NaturalEarth")
  }

  @Test func roundTripWithReference() {
    let ortho = Projections.Orthographic(reference: .init(latitude: -33.8, longitude: 151.3))
    let geo = Point(x: 145.0 * .pi / 180, y: -37.8 * .pi / 180) // Melbourne
    let projected = ortho.project(geo)!
    let recovered = ortho.inverse(projected)!
    #expect(abs(recovered.x - geo.x) < 1e-9)
    #expect(abs(recovered.y - geo.y) < 1e-9)
  }

  @Test func orthographicRejectsOutsideDisk() {
    let ortho = Projections.Orthographic()
    #expect(ortho.inverse(.init(x: 2.0, y: 0.0)) == nil)
    #expect(ortho.inverse(.init(x: 0.0, y: 0.0)) != nil)
  }

  @Test func equalEarthRejectsOutsideBezier() {
    let ee = Projections.EqualEarth()
    let halfW = ee.projectionSize.width / 2
    let halfH = ee.projectionSize.height / 2
    // Top-right corner of the bounding rect is well outside the bezier outline.
    #expect(ee.inverse(.init(x: halfW * 0.99, y: halfH * 0.99)) == nil)
    // Centre of the projection is always inside.
    #expect(ee.inverse(.init(x: 0, y: 0)) != nil)
  }

  @Test func clickAtCentreReturnsZero() {
    let proj = Projections.Equirectangular()
    let size = Size(width: 200, height: 100)
    let geo = proj.coordinate(at: .init(x: 100, y: 50), size: size, coordinateSystem: .topLeft)
    #expect(geo != nil)
    #expect(abs((geo?.latitude  ?? 1) - 0) < 1e-9)
    #expect(abs((geo?.longitude ?? 1) - 0) < 1e-9)
  }

  @Test func clickAtTopLeftReturnsExtremes() {
    let proj = Projections.Equirectangular()
    let size = Size(width: 200, height: 100)
    let tl = proj.coordinate(at: .init(x: 0, y: 0), size: size, coordinateSystem: .topLeft)
    #expect(tl != nil)
    #expect(abs((tl?.latitude  ?? 0) -  90) < 1e-9)
    #expect(abs((tl?.longitude ?? 0) + 180) < 1e-9)
  }

  @Test func clickOutsideOrthoGlobeReturnsNil() {
    let proj = Projections.Orthographic()
    let size = Size(width: 100, height: 100)
    // Corners of a square render are outside the inscribed disk.
    #expect(proj.coordinate(at: .init(x: 1, y: 1),   size: size, coordinateSystem: .topLeft) == nil)
    #expect(proj.coordinate(at: .init(x: 99, y: 99), size: size, coordinateSystem: .topLeft) == nil)
    // Centre is the reference point: (0,0).
    let centre = proj.coordinate(at: .init(x: 50, y: 50), size: size, coordinateSystem: .topLeft)
    #expect(centre != nil)
    #expect(abs(centre?.latitude  ?? 1) < 1e-9)
    #expect(abs(centre?.longitude ?? 1) < 1e-9)
  }

  @Test func clickRoundTripsThroughForward() {
    // A click at a known pixel should match what `point(for:)` produces for the same coord.
    let proj = Projections.NaturalEarth()
    let size = Size(width: 400, height: 200)
    let geo = GeoJSON.Position(latitude: 35.0, longitude: -120.0)

    let pixel = proj.point(for: .init(x: geo.longitude.toRadians(), y: geo.latitude.toRadians()),
                           size: size, coordinateSystem: .topLeft)
    #expect(pixel != nil)

    let recovered = proj.coordinate(at: pixel!, size: size, coordinateSystem: .topLeft)
    #expect(recovered != nil)
    #expect(abs((recovered?.latitude  ?? 0) - geo.latitude)  < 1e-4)
    #expect(abs((recovered?.longitude ?? 0) - geo.longitude) < 1e-4)
  }

  @Test func clickWithBottomLeftCoordinateSystem() {
    let proj = Projections.Equirectangular()
    let size = Size(width: 200, height: 100)
    // In bottomLeft, (0, 0) is the bottom-left pixel: (lat -90, lon -180).
    let bl = proj.coordinate(at: .init(x: 0, y: 0), size: size, coordinateSystem: .bottomLeft)
    #expect(bl != nil)
    #expect(abs((bl?.latitude  ?? 0) + 90)  < 1e-9)
    #expect(abs((bl?.longitude ?? 0) + 180) < 1e-9)
  }
}
#endif
