//
//  Interpolator.swift
//  
//
//  Created by Adrian Schönig on 9/12/2022.
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

public enum Interpolator {
  
  /// Interpolates from a to b using the provided projector method, adding new points whenever the
  /// projected point differs more than `maxDiff` from the straight-line from a to b
  ///
  /// - Parameters:
  ///   - a: Start point
  ///   - b: End point
  ///   - maxDiff: Maximum distance
  ///   - projector: Projector handler that should return a projected point for a raw point
  /// - Returns: List of (unprojected, projected) pairs to add in between a and b
  public static func interpolate(from a: Point, to b: Point, maxDiff: Double, projector: (Point) -> Point?) -> [(Point, Point)] {
    let pointDistance = a.distanceSquared(to: b)
    let diffSquared = maxDiff * maxDiff
    guard pointDistance > diffSquared else { return [] }
    
    let c = a.halfway(to: b)
    
    let a_proj = projector(a)
    let b_proj = projector(b)
    let c_proj = projector(c)
    if let a_proj, let b_proj, let c_proj {
      let c_triv = a_proj.halfway(to: b_proj)
      let distanceSquared = c_proj.distanceSquared(to: c_triv)
      guard distanceSquared > diffSquared else { return [] }
    }
    
    let lefty = interpolate(from: a, to: c, maxDiff: maxDiff, projector: projector)
    let righty = interpolate(from: c, to: b, maxDiff: maxDiff, projector: projector)
    let middy = [c_proj].compactMap { $0 }.map { (c, $0) }
    return lefty + middy + righty
  }
  
}

extension Point {
  
  func halfway(to b: Point) -> Point {
    Point(x: (x + b.x) / 2, y: (y + b.y) / 2)
  }
  
  func distanceSquared(to b: Point) -> Double {
    pow(b.x - x, 2) + pow(b.y - y, 2)
  }
  
}
