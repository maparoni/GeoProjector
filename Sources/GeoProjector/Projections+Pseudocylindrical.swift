//
//  Projection+Pseudocylindrical.swift
//  
//
//  Created by Adrian Schönig on 3/12/2022.
//

import Foundation

extension Projections {
  
  private static func willWrap(_ point: Point, reference: Point) -> Bool {
    let adjusted = point.x - reference.x
    return adjusted < .pi * -1 || adjusted > .pi
  }

  private static func adjust(_ point: Point, reference: Point) -> Point {
    var adjusted = point.x - reference.x
    if adjusted < .pi * -1 {
      adjusted += .pi * 2
    } else if adjusted > .pi {
      adjusted -= .pi * 2
    }
    precondition(adjusted >= .pi * -1 && adjusted <= .pi)
    return .init(x: adjusted, y: point.y)
  }
  
  /// Good compromise
  /// https://en.wikipedia.org/wiki/Equal_Earth_projection
  public struct EqualEarth: Projection {
    public init(reference: Point) {
      self.reference = reference
    }
    
    public let reference: Point
    
    private static let A = [1.340264, -0.081106, 0.000893, 0.003796]
    private static let B = sqrt(3) / 2
    
    public func willWrap(_ point: Point) -> Bool {
      Projections.willWrap(point, reference: reference)
    }

    public func project(_ point: Point) -> Point {
      let adjusted = Projections.adjust(point, reference: reference)

      let th = asin(Self.B * sin(adjusted.y))
      return .init(
        x: cos(th) / Self.B / Self.poly8(th) * (adjusted.x),
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
