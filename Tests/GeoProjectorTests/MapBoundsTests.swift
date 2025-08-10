//
//  MapBoundsTests.swift
//  
//
//  Created by Adrian Schönig on 9/12/2022.
//

#if canImport(Testing)
import Testing

@testable import GeoProjector

struct MapBoundsTests {
  @Test func equalEarthBounds() {
    guard case let .bezier(bounds) = Projections.EqualEarth().mapBounds else { 
      Issue.record("Expected bezier map bounds")
      return
    }
    #expect(bounds.count == 82)
  }
}

#endif