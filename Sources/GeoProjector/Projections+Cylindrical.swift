//
//  Projection+Cylindrical.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

import Foundation

import GeoJSONKit

extension Projections {
  
  /// Projection applying plain lat/long, use `phiOne = 0` for Plate Carée
  /// https://en.wikipedia.org/wiki/Equirectangular_projection
  public struct Equirectangular: Projection {
    public init(reference: Point, phiOne: Double) {
      self.reference = reference
      self.phiOne = phiOne.toRadians()
    }

    public init(reference: Point) {
      self.init(reference: reference, phiOne: 0)
    }
    
    public init(reference: GeoJSON.Position, phiOne: Double) {
      self.init(reference: .init(x: reference.longitude.toRadians(), y: reference.latitude.toRadians()), phiOne: phiOne)
    }

    public let reference: Point

    /// "The standard parallels (north and south of the equator) where the scale of the projection is true"
    var phiOne: Double = 0
        
    public func project(_ point: Point) -> Point {
      return .init(
        x: (point.x - reference.x) * cos(phiOne),
        y: (point.y - reference.y)
      )
    }
  }
  
  /// Web standard
  /// https://en.wikipedia.org/wiki/Mercator_projection
  public struct Mercator: Projection {
    public init(reference: Point) {
      self.reference = reference
    }
    
    public let reference: Point
    
    public func project(_ point: Point) -> Point {
      // TODO: The initial .pi / -2 on y, isn't part of the official formula, but to add missing padding.
      
      return .init(
        x: point.x,
        y: .pi / -2 + log(tan(.pi / 4 + point.y / 2))
      )
    }
  }

  /// Ugly, but good equal-area representation
  /// https://en.wikipedia.org/wiki/Gall–Peters_projection
  public struct GallPeters: Projection {
    public init(reference: Point) {
      self.reference = reference
    }
    
    public let reference: Point
    
    public func project(_ point: Point) -> Point {
      // TODO: The initial .pi / -4 on y, isn't part of the official formula, but to add missing padding.
      
      return .init(
        x: point.x,
        y: .pi / -4 + 2 * sin(point.y)
      )
    }
  }

}
