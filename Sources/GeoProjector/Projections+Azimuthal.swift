//
//  Projection+Azimuthal.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

import Foundation

import GeoJSONKit

extension Projections {
  
  /// https://en.wikipedia.org/wiki/Azimuthal_equidistant_projection
  ///
  /// For a North-Pole special case set the reference to lat: 90, longitude: any.
  public struct AzimuthalEquidistant: Projection {
    public init(reference: Point) {
      self.reference = reference
      
      // Heuristic: Get the antipode to the reference, if a polygon contains
      // that, the projection will "wrap" around.
      var antipode = GeoJSON.Position(
        latitude: reference.y.toDegrees() * -1,
        longitude: reference.x.toDegrees() + 180
      )
      if antipode.longitude > 180 {
        antipode.longitude -= 360
      }
      if antipode.longitude <= -179.9 {
        antipode.longitude = -179.9
      }
      if antipode.latitude < -89.9 {
        antipode.latitude = -89.9
      }
      self.invertCheck = { $0.contains(antipode) }
    }
    
    public let reference: Point
    
    public let invertCheck: ((GeoJSON.Polygon) -> Bool)?

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
