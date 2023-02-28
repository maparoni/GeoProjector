//
//  Projection+Pseudocylindrical.swift
//  
//
//  Created by Adrian Schönig on 3/12/2022.
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
  
  /// Good compromise projection
  ///
  /// See https://en.wikipedia.org/wiki/Equal_Earth_projection
  public struct EqualEarth: Projection {
    private static let A = [1.340264, -0.081106, 0.000893, 0.003796]
    private static let B = sqrt(3) / 2

    public init(reference: Point) {
      self.reference = reference
      
      self.projectionSize = .init(
        width: 2 / Self.B / Self.poly8(0) * .pi,
        height: 2 * Self.poly9(.pi / 3)
      )
      
      let inputCorners: [Point] = [
        .init(x: -1 * .pi, y: .pi / 2),
        .init(x: .pi, y: .pi / 2),
        .init(x: .pi, y: -1 * .pi / 2),
        .init(x: -1 * .pi, y: -1 * .pi / 2),
        .init(x: -1 * .pi, y: .pi / 2),
      ]
      
      let boundPoints = zip(inputCorners.dropLast(), inputCorners.dropFirst())
        .reduce(into: [Point]()) { acc, next in
          acc.append(Self.project(next.0))
          acc.append(contentsOf: Interpolator.interpolate(from: next.0, to: next.1, maxDiff: 0.0025, projector: Self.project(_:)).map(\.1))
          acc.append(Self.project(next.1))
        }
      self.mapBounds = .bezier(boundPoints)
    }
    
    public let reference: Point
    
    public let projectionSize: Size
    
    public let mapBounds: MapBounds
    
    public func willWrap(_ point: Point) -> Bool {
      Projections.willWrap(point, reference: reference)
    }

    public func project(_ point: Point) -> Point? {
      let adjusted = Projections.adjust(point, reference: reference)
      return Self.project(adjusted)
    }
    
    private static func project(_ point: Point) -> Point {
      let th = asin(Self.B * sin(point.y))
      return .init(
        x: cos(th) / Self.B / Self.poly8(th) * (point.x),
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
