//
//  Projection+Azimuthal.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

import Foundation

extension Projections {
  
  /// Special case of ``AzimuthalEquidistant`` focussed on North Pole
  public struct PolarAzimuthalEquidistant: Projection {
    public init(reference: Point) {
      self.reference = reference
    }
    
    public let reference: Point
    
    public let mightInvert = true
    
    public func project(_ point: Point) -> Point {
      // TODO: The initial .pi / -2 on y, isn't part of the official formula, but to add missing padding.
      
      let r = .pi/2 - point.y
      return .init(
        x: r * sin(point.x),
        y: .pi / -2 + -r * cos(point.x)
      )
    }

  }
  
  /// https://en.wikipedia.org/wiki/Azimuthal_equidistant_projection
  public struct AzimuthalEquidistant: Projection {
    public init(reference: Point) {
      self.reference = reference
    }
    
    public let reference: Point
    
    public let mightInvert = true
    
    public func project(_ point: Point) -> Point {
      // TODO: The initial .pi / -2 on y, isn't part of the official formula, but to add missing padding.
      
      let k = self.k(point)
      return .init(
        x: k * cos(point.y) * sin(point.x - reference.x),
        y: .pi / -2 + k * (cos(reference.y) * sin(point.y) - sin(reference.y) * cos(point.y) * cos(point.x - reference.x))
      )
    }
    
    private func k(_ point: Point) -> Double {
      let c = self.c(point)
      return c / sin(c)
    }

    private func c(_ point: Point) -> Double {
      return acos(
        sin(reference.y) * sin(point.y)
          + cos(reference.y) * cos(point.y)
          * cos(point.x - reference.x)
      )
    }

  }
  
}
