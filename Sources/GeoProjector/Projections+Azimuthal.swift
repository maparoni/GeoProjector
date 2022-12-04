//
//  Projection+Azimuthal.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

import Foundation

extension Projections {
  
  /// https://en.wikipedia.org/wiki/Azimuthal_equidistant_projection
  public struct AzimuthalEquidistant: Projection {
    public init(reference: Point) {
      self.reference = reference
    }
    
    public let reference: Point
    
    public func project(_ point: Point) -> Point {
      let r = .pi/2 - point.y
      return .init(
        x: r * sin(point.x),
        y: .pi / -2 + -r * cos(point.x)
      )
    }

  }
  
}
