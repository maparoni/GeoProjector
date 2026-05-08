//
//  Projection+Orthographic.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2022 Corporoni Pty Ltd. See LICENSE.

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

    public func inverse(_ point: Point) -> Point? {
      let X = point.x, Y = point.y
      let rho = sqrt(X*X + Y*Y)
      guard rho <= 1.0 + 1e-12 else { return nil }
      if rho < 1e-15 { return reference }
      let c = asin(min(1.0, rho))
      let sinC = sin(c), cosC = cos(c)
      let phi = asin(cosC * sin(reference.y) + (Y * sinC * cos(reference.y)) / rho)
      let lam = reference.x + atan2(
        X * sinC,
        rho * cos(reference.y) * cosC - Y * sin(reference.y) * sinC
      )
      return .init(x: Projections.wrapLongitude(lam), y: phi)
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
