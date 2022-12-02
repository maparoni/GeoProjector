//
//  Projection+Orthographic.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

import Foundation

extension Projection {
  
  struct Orthographic {
    
    var refLat: Double = 0
    var refLng: Double = 0
    
    func project(_ point: Point) -> Point {
      return .init(
        x: cos(point.y) * sin(point.x - refLng),
        y: cos(refLat) * sin(point.y) - sin(refLat) * cos(point.y) * cos(point.x - refLng)
      )
    }

  }
  
}
