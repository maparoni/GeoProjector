//
//  Projection+Equirectangular.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

import Foundation

import GeoJSONKit

extension Projection {
  
  struct PlateCarree {
    func project(_ point: Point) -> Point {
      return point
    }
  }
  
  struct Meractor {
    func project(_ point: Point) -> Point {
      return .init(
        x: point.x,
        y: log(tan(.pi / 4 + point.y / 2))
      )
    }
  }
  
  /// See https://en.wikipedia.org/wiki/Equirectangular_projection
  struct Equirectangular {
    /// "The standard parallels (north and south of the equator) where the scale of the projection is true"
    var phiOne: Double = 0
        
  }
  
}
