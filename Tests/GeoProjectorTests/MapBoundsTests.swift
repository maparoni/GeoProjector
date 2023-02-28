//
//  MapBoundsTests.swift
//  
//
//  Created by Adrian Schönig on 9/12/2022.
//

import XCTest

@testable import GeoProjector

final class MapBoundsTests: XCTestCase {
  func testEqualEarthBounds() {
    guard case let .bezier(bounds) = Projections.EqualEarth().mapBounds else { return XCTFail() }
    XCTAssertEqual(bounds.count, 82)
  }
  
}
