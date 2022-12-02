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
  
  /// See https://en.wikipedia.org/wiki/Equirectangular_projection
  struct Equirectangular {
    /// "The standard parallels (north and south of the equator) where the scale of the projection is true"
    var phiOne: Double = 0
        
  }
  
}
