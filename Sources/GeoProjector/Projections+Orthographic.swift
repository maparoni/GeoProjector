//
//  Projection+Orthographic.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2022 Corporoni Pty Ltd
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
