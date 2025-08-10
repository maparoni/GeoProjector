//
//  TranslationTests.swift
//  
//
//  Created by Adrian Schönig on 9/12/2022.
//

import XCTest

@testable import GeoProjector

final class TranslationTests: XCTestCase {
  func testEquirectangularInSquare() throws {
    XCTAssertEqual(Projections.Equirectangular().translate(Point(x: 0, y: 0), to: .init(width: 100, height: 100), coordinateSystem: .topLeft), .init(x: 50, y: 50))

    XCTAssertEqual(Projections.Equirectangular().translate(Point(x: -1 * .pi, y: 0.5 * .pi), to: .init(width: 100, height: 100), coordinateSystem: .topLeft), .init(x: 0, y: 25))

    XCTAssertEqual(Projections.Equirectangular().translate(Point(x: .pi, y: 0.5 * .pi), to: .init(width: 100, height: 100), coordinateSystem: .topLeft), .init(x: 100, y: 25))

    XCTAssertEqual(Projections.Equirectangular().translate(Point(x: .pi, y: -0.5 * .pi), to: .init(width: 100, height: 100), coordinateSystem: .topLeft), .init(x: 100, y: 75))

    XCTAssertEqual(Projections.Equirectangular().translate(Point(x: -1 * .pi, y: -0.5 * .pi), to: .init(width: 100, height: 100), coordinateSystem: .topLeft), .init(x: 0, y: 75))
  }
  
  func testEquirectangularInWideStripe() throws {
    XCTAssertEqual(Projections.Equirectangular().translate(Point(x: 0, y: 0), to: .init(width: 400, height: 100), coordinateSystem: .topLeft), .init(x: 200, y: 50))

    XCTAssertEqual(Projections.Equirectangular().translate(Point(x: -1 * .pi, y: 0.5 * .pi), to: .init(width: 400, height: 100), coordinateSystem: .topLeft), .init(x: 100, y: 0))

    XCTAssertEqual(Projections.Equirectangular().translate(Point(x: .pi, y: 0.5 * .pi), to: .init(width: 400, height: 100), coordinateSystem: .topLeft), .init(x: 300, y: 0))

    XCTAssertEqual(Projections.Equirectangular().translate(Point(x: .pi, y: -0.5 * .pi), to: .init(width: 400, height: 100), coordinateSystem: .topLeft), .init(x: 300, y: 100))

    XCTAssertEqual(Projections.Equirectangular().translate(Point(x: -1 * .pi, y: -0.5 * .pi), to: .init(width: 400, height: 100), coordinateSystem: .topLeft), .init(x: 100, y: 100))
  }
}
