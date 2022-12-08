//
//  Projection+Orthographic.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

import Foundation

extension Projections {
  
  /// "World from space"
  /// https://en.wikipedia.org/wiki/Orthographic_map_projection
  public struct Orthographic: Projection {
    public init(reference: Point) {
      self.reference = reference
    }
    
    public let reference: Point
    
    public let showsFullEarth = false
    
    public let projectionSize: Size =
      .init(width: 2, height: 2)
    
    public let mapBounds: MapBounds = .ellipse

    public func project(_ point: Point) -> Point {
      return .init(
        x: cos(point.y) * sin(point.x - reference.x),
        y: cos(reference.y) * sin(point.y) - sin(reference.y) * cos(point.y) * cos(point.x - reference.x)
      )
    }

  }
  
}
