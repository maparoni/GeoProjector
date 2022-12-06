import XCTest

import GeoJSONKit
@testable import GeoProjector

final class ProjectionTests: XCTestCase {
  func testFlatSquare() throws {
    let topLeft = GeoJSON.Position(latitude: 90, longitude: -180)
    XCTAssertEqual(Projections.Equirectangular().point(for: topLeft, size: .init(width: 200, height: 100)).0, .init(x: 0, y: 0))

    let topRight = GeoJSON.Position(latitude: 90, longitude: 180)
    XCTAssertEqual(Projections.Equirectangular().point(for: topRight, size: .init(width: 200, height: 100)).0, .init(x: 200, y: 0))

    let bottomLeft = GeoJSON.Position(latitude: -90, longitude: -180)
    XCTAssertEqual(Projections.Equirectangular().point(for: bottomLeft, size: .init(width: 200, height: 100)).0, .init(x: 0, y: 100))

    let bottomRight = GeoJSON.Position(latitude: -90, longitude: 180)
    XCTAssertEqual(Projections.Equirectangular().point(for: bottomRight, size: .init(width: 200, height: 100)).0, .init(x: 200, y: 100))

    let zeroZero = GeoJSON.Position(latitude: 0, longitude: 0)
    XCTAssertEqual(Projections.Equirectangular().point(for: zeroZero, size: .init(width: 200, height: 100)).0, .init(x: 100, y: 50))
  }
  
  func testOrthographic() throws {
    let zeroZero = GeoJSON.Position(latitude: 0, longitude: 0)
    XCTAssertEqual(Projections.Orthographic().point(for: zeroZero, size: .init(width: 100, height: 100)).0, .init(x: 50, y: 50))
  }
}
