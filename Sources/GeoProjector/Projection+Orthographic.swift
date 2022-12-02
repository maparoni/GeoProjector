//
//  Projection+Orthographic.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

import Foundation

extension Projection {
  
  enum Orthographic {
    
    static func x(lat: Double, lng: Double, refLat: Double = 0, refLng: Double = 0) -> Double {
      return cos(lat) * sin(lng - refLng)
    }

    static func y(lat: Double, lng: Double, refLat: Double = 0, refLng: Double = 0) -> Double {
      return cos(refLat) * sin(lat) - sin(refLat) * cos(lat) * cos(lng - refLng)
    }

  }
  
}
