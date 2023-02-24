//
//  Projection+Orthographic.swift
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

extension Projections {
  
  /// "World from space"
  /// https://en.wikipedia.org/wiki/Orthographic_map_projection
  public struct Orthographic: Projection {
    public init(reference: Point) {
      self.reference = reference
    }
    
    public var clip: Bool = true
    
    public let reference: Point
    
    public let showsFullEarth = false
    
    public let projectionSize: Size =
      .init(width: 2, height: 2)
    
    public let mapBounds: MapBounds = .ellipse

    public func project(_ point: Point) -> Point? {
      if clip, isOnBackside(point) {
        return nil
      }
      
      return .init(
        x: cos(point.y) * sin(point.x - reference.x),
        y: cos(reference.y) * sin(point.y) - sin(reference.y) * cos(point.y) * cos(point.x - reference.x)
      )
    }
    
    public func willWrap(_ point: Point) -> Bool {
      let adjusted = point.x - reference.x
      return adjusted < .pi * -1 || adjusted > .pi
    }
    
    /// Kudos to https://en.wikipedia.org/wiki/Orthographic_map_projection
    ///
    /// > Latitudes beyond the range of the map should be clipped by calculating the angular distance c
    /// > from the center of the orthographic projection. This ensures that points on the opposite hemisphere
    /// > are not plotted: ... The point should be clipped from the map if cos(c) is negative.
    private func isOnBackside(_ point: Point) -> Bool {
      let cos_c = sin(reference.y) * sin(point.y) + cos(reference.y) * cos(point.y) * cos(point.x - reference.x)
      return cos_c < 0
    }

  }
  
}
