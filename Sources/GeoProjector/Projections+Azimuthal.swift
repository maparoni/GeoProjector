//
//  Projection+Azimuthal.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2022 Corporoni Pty Ltd
//
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Lesser General Public
// License as published by the Free Software Foundation; either
// version 2.1 of the License, or (at your option) any later version.
//
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public
// License along with this library; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301
// USA

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

    public var projectionSize: Size =
      .init(width: 2 * .pi, height: 2 * .pi)
    
    public var mapBounds: MapBounds = .ellipse
    
    public func project(_ point: Point) -> Point? {
      let k = self.k(point)
      return .init(
        x: k * cos(point.y) * sin(point.x - reference.x),
        y: k * (cos(reference.y) * sin(point.y) - sin(reference.y) * cos(point.y) * cos(point.x - reference.x))
      )
    }
    
    private func k(_ point: Point) -> Double {
      let c = self.c(point)
      guard c != 0 else { return 0 }
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
