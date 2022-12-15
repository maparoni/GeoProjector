//
//  Interpolator.swift
//  
//
//  Created by Adrian Schönig on 9/12/2022.
//

import Foundation

public enum Interpolator {
  
  public static func interpolate(from a: Point, to b: Point, maxDiff: Double, projector: (Point) -> Point?) -> [(Point, Point)] {
    let diffSquared = maxDiff * maxDiff
    let c = a.halfway(to: b)
    guard
      let a_proj = projector(a),
      let b_proj = projector(b),
      let c_proj = projector(c)
    else { return [] }
    
    let c_triv = a_proj.halfway(to: b_proj)
    let distanceSquared = c_proj.distanceSquared(to: c_triv)
    guard distanceSquared > diffSquared else { return [] }
    
    let lefty = interpolate(from: a, to: c, maxDiff: maxDiff, projector: projector)
    let righty = interpolate(from: c, to: b, maxDiff: maxDiff, projector: projector)
    return lefty + [(c, c_proj)] + righty
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
