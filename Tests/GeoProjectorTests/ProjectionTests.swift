import XCTest

import GeoJSONKit
@testable import GeoProjector
@testable import GeoDrawer

final class ProjectionTests: XCTestCase {
#if os(macOS)
  let macOS: Bool = true
#else
  let macOS: Bool = false
#endif
  
  func testFlatSquare() throws {
    let topLeft = GeoJSON.Position(latitude: 90, longitude: -180)
    XCTAssertEqual(Projections.Equirectangular().point(for: topLeft, size: .init(width: 200, height: 100))?.0, .init(x: 0, y: macOS ? 100 : 0))

    let topRight = GeoJSON.Position(latitude: 90, longitude: 180)
    XCTAssertEqual(Projections.Equirectangular().point(for: topRight, size: .init(width: 200, height: 100))?.0, .init(x: 200, y: macOS ? 100 : 0))

    let bottomLeft = GeoJSON.Position(latitude: -90, longitude: -180)
    XCTAssertEqual(Projections.Equirectangular().point(for: bottomLeft, size: .init(width: 200, height: 100))?.0, .init(x: 0, y: macOS ? 0 : 100))

    let bottomRight = GeoJSON.Position(latitude: -90, longitude: 180)
    XCTAssertEqual(Projections.Equirectangular().point(for: bottomRight, size: .init(width: 200, height: 100))?.0, .init(x: 200, y: macOS ? 0 : 100))

    let zeroZero = GeoJSON.Position(latitude: 0, longitude: 0)
    XCTAssertEqual(Projections.Equirectangular().point(for: zeroZero, size: .init(width: 200, height: 100))?.0, .init(x: 100, y: 50))
  }
  
  func testOrthographic() throws {
    let zeroZero = GeoJSON.Position(latitude: 0, longitude: 0)
    XCTAssertEqual(Projections.Orthographic().point(for: zeroZero, size: .init(width: 100, height: 100))?.0, .init(x: 50, y: 50))

    let easternOrthographic = Projections.Orthographic(reference: .init(latitude: 0, longitude: 100))
    let sydney = GeoJSON.Position(latitude: -33.8, longitude: 151.3)
    let projected = easternOrthographic.point(for: sydney, size: .init(width: 100, height: 100))?.0
    XCTAssertEqual(projected?.x ?? 0, 82.4, accuracy: 0.1)
    XCTAssertEqual(projected?.y ?? 0, macOS ? 22.2 : 77.8, accuracy: 0.1)
  }
}

extension Projection {
  func point(for position: GeoJSON.Position, zoomTo: Rect? = nil, size: Size, insets: EdgeInsets = .zero) -> (Point, Bool)? {
    let point = Point(x: position.longitude.toRadians(), y: position.latitude.toRadians())
    return self.point(for: point, size: size, zoomTo: zoomTo, insets: insets)
  }
}
