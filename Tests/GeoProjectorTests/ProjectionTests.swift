#if canImport(Testing)
import Testing

import GeoJSONKit
@testable import GeoProjector

struct ProjectionTests {

  @Test func flatSquare() throws {
    let topLeft = GeoJSON.Position(latitude: 90, longitude: -180)
    #expect(Projections.Equirectangular().point(for: topLeft, size: .init(width: 200, height: 100), coordinateSystem: .topLeft) == .init(x: 0, y: 0))

    let topRight = GeoJSON.Position(latitude: 90, longitude: 180)
    #expect(Projections.Equirectangular().point(for: topRight, size: .init(width: 200, height: 100), coordinateSystem: .topLeft) == .init(x: 200, y: 0))

    let bottomLeft = GeoJSON.Position(latitude: -90, longitude: -180)
    #expect(Projections.Equirectangular().point(for: bottomLeft, size: .init(width: 200, height: 100), coordinateSystem: .topLeft) == .init(x: 0, y: 100))

    let bottomRight = GeoJSON.Position(latitude: -90, longitude: 180)
    #expect(Projections.Equirectangular().point(for: bottomRight, size: .init(width: 200, height: 100), coordinateSystem: .topLeft) == .init(x: 200, y: 100))

    let zeroZero = GeoJSON.Position(latitude: 0, longitude: 0)
    #expect(Projections.Equirectangular().point(for: zeroZero, size: .init(width: 200, height: 100), coordinateSystem: .topLeft) == .init(x: 100, y: 50))
  }

  @Test func orthographic() throws {
    let zeroZero = GeoJSON.Position(latitude: 0, longitude: 0)
    #expect(Projections.Orthographic().point(for: zeroZero, size: .init(width: 100, height: 100), coordinateSystem: .topLeft) == .init(x: 50, y: 50))

    let easternOrthographic = Projections.Orthographic(reference: .init(latitude: 0, longitude: 100))
    let sydney = GeoJSON.Position(latitude: -33.8, longitude: 151.3)
    let projected = easternOrthographic.point(for: sydney, size: .init(width: 100, height: 100), coordinateSystem: .topLeft)
    #expect(abs((projected?.x ?? 0) - 82.4) < 0.1)
    #expect(abs((projected?.y ?? 0) - 77.8) < 0.1)
  }

  /// Azimuthal Equidistant has a singularity at the antipode (`c = π`,
  /// `sin(c) = 0`). Floating-point arithmetic also produces `cosArg` values
  /// that fall just below −1 for points within ~1e-5° of the antipode, which
  /// then project to wildly wrong locations (radius nowhere near π) instead
  /// of nice points on the rim. The renderer then strokes long lines through
  /// those bad points, producing the visual stripes seen with reference
  /// (-21.9°, -80.5°). The projection should return nil at the antipode and
  /// keep all other projected coordinates within the projection's bounds.
  @Test func azimuthalAntipodeIsRejected() throws {
    let projection = Projections.AzimuthalEquidistant(
      reference: .init(latitude: -21.9, longitude: -80.5)
    )
    let halfW = projection.projectionSize.width / 2
    let halfH = projection.projectionSize.height / 2

    // Exact antipode: should be rejected as outside (the rim is the antipode).
    let antipode = Point(
      x: 99.5 * .pi / 180,
      y: 21.9 * .pi / 180
    )
    #expect(projection.project(antipode) == nil)

    // Reference itself projects to the origin.
    let origin = Point(x: -80.5 * .pi / 180, y: -21.9 * .pi / 180)
    let projOrigin = projection.project(origin)
    #expect(projOrigin != nil)
    #expect(abs(projOrigin?.x ?? .nan) < 1e-9)
    #expect(abs(projOrigin?.y ?? .nan) < 1e-9)

    // A coarse grid of points anywhere on the globe must produce projected
    // coordinates safely within the projection bounds (no NaN, no blow-ups).
    var lat = -85.0
    while lat <= 85 {
      var lon = -180.0
      while lon <= 180 {
        let p = Point(x: lon * .pi / 180, y: lat * .pi / 180)
        if let proj = projection.project(p) {
          #expect(!proj.x.isNaN && !proj.x.isInfinite,
                  "x non-finite at lat=\(lat), lon=\(lon): \(proj.x)")
          #expect(!proj.y.isNaN && !proj.y.isInfinite,
                  "y non-finite at lat=\(lat), lon=\(lon): \(proj.y)")
          #expect(abs(proj.x) <= halfW + 1e-6,
                  "x=\(proj.x) outside halfW=\(halfW) at lat=\(lat), lon=\(lon)")
          #expect(abs(proj.y) <= halfH + 1e-6,
                  "y=\(proj.y) outside halfH=\(halfH) at lat=\(lat), lon=\(lon)")
        }
        lon += 7
      }
      lat += 7
    }
  }

}

extension Projection {
  func point(for position: GeoJSON.Position, zoomTo: Rect? = nil, size: Size, insets: EdgeInsets = .zero, coordinateSystem: CoordinateSystem) -> Point? {
    let point = Point(x: position.longitude.toRadians(), y: position.latitude.toRadians())
    return self.point(for: point, size: size, zoomTo: zoomTo, insets: insets, coordinateSystem: coordinateSystem)
  }
}

#endif
