//
//  Projection+Pseudocylindrical.swift
//  
//
//  Created by Adrian Schönig on 3/12/2022.
//

import Foundation

extension Projections {
  
  /// Good compromise
  /// https://en.wikipedia.org/wiki/Equal_Earth_projection
  public struct EqualEarth: Projection {
    public init(reference: Point) {
      self.reference = reference
    }
    
    public let reference: Point
    
    private static let A = [1.340264, -0.081106, 0.000893, 0.003796]
    private static let B = sqrt(3) / 2
    
    public func project(_ point: Point) -> Point {
      let th = asin(Self.B * sin(point.y))
      return .init(
        x: cos(th) / Self.B / Self.poly8(th) * point.x,
        y: Self.poly9(th)
      )
    }
    
    private static func poly9(_ x: Double) -> Double {
          A[3] * pow(x, 9) +     A[2] * pow(x, 7) +     A[1] * pow(x, 3) + A[0] * x
    }

    private static func poly8(_ x: Double) -> Double {
      9 * A[3] * pow(x, 8) + 7 * A[2] * pow(x, 6) + 3 * A[1] * pow(x, 2) + A[0]
    }

  }
  
}
