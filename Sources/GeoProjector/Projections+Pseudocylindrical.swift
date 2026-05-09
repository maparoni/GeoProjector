//
//  Projection+Pseudocylindrical.swift
//  
//
//  Created by Adrian Schönig on 3/12/2022.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2022 Corporoni Pty Ltd. See LICENSE.

import Foundation

extension Projections {

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

    public func project(_ point: Point) -> Point? {
      let adjusted = Projections.adjust(point, reference: reference)
      return Self.project(adjusted)
    }

    public func inverse(_ point: Point) -> Point? {
      guard mapBounds.contains(point, projectionSize: projectionSize) else { return nil }
      // Newton-Raphson on theta:  f(θ) = poly9(θ) - Y,  f'(θ) = poly8(θ).
      // Matches d3-geo's equalEarthInvert.
      var theta = point.y
      for _ in 0..<12 {
        let f  = Self.poly9(theta) - point.y
        let fp = Self.poly8(theta)
        let delta = f / fp
        theta -= delta
        if abs(delta) < 1e-12 { break }
      }
      let sinTheta = sin(theta)
      let phi = asin(min(1.0, max(-1.0, sinTheta / Self.B)))
      let lambda = point.x * Self.B * Self.poly8(theta) / cos(theta)
      return .init(x: Projections.wrapLongitude(lambda + reference.x), y: phi)
    }

    private static func project(_ point: Point) -> Point {
      let th = asin(Self.B * sin(point.y))
      return .init(
        x: cos(th) / Self.B / Self.poly8(th) * (point.x),
        y: Self.poly9(th)
      )
    }
    
    @inline(__always)
    private static func poly9(_ x: Double) -> Double {
      // Horner-form: x · (A0 + x²·(A1 + x²·(0 + x²·(A2 + x²·A3))))
      // Original: A3·x⁹ + A2·x⁷ + A1·x³ + A0·x
      let x2 = x * x
      let x3 = x2 * x
      let x4 = x2 * x2
      let x7 = x4 * x3
      let x9 = x7 * x2
      return A[3] * x9 + A[2] * x7 + A[1] * x3 + A[0] * x
    }

    @inline(__always)
    private static func poly8(_ x: Double) -> Double {
      // 9·A3·x⁸ + 7·A2·x⁶ + 3·A1·x² + A0
      let x2 = x * x
      let x4 = x2 * x2
      let x6 = x4 * x2
      let x8 = x4 * x4
      return 9 * A[3] * x8 + 7 * A[2] * x6 + 3 * A[1] * x2 + A[0]
    }

  }
  
  /// Compromise projection that's optimised to look nice as a small map
  ///
  /// See https://www.shadedrelief.com/NE_proj/index.html
  public struct NaturalEarth: Projection {
    private static let A0 = 0.8707
    private static let A1 = -0.131979
    private static let A2 = -0.013791
    private static let A3 = 0.003971
    private static let A4 = -0.001529
    private static let B0 = 1.007226
    private static let B1 = 0.015085
    private static let B2 = -0.044475
    private static let B3 = 0.028874
    private static let B4 = -0.005916
    private static let MAX_Y = 0.8707 * 0.52 * .pi
    
    public let reference: Point
    
    public let projectionSize: Size
    
    public let mapBounds: MapBounds
    
    public init(reference: Point) {
      self.reference = reference
      
      // Calculate projection size based on equations
      self.projectionSize = .init(
        width: 2 * .pi * Self.A0,
        height: 2 * Self.MAX_Y
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

    public func project(_ point: Point) -> Point? {
      let adjusted = Projections.adjust(point, reference: reference)
      return Self.project(adjusted)
    }

    public func inverse(_ point: Point) -> Point? {
      guard mapBounds.contains(point, projectionSize: projectionSize) else { return nil }
      // Newton-Raphson on phi from y(phi). Matches d3-geo-projection's naturalEarth1Invert.
      var phi = point.y
      for _ in 0..<25 {
        let f  = Self.yOfPhi(phi) - point.y
        let fp = Self.dyOfPhi(phi)
        let delta = f / fp
        phi -= delta
        if abs(delta) < 1e-9 { break }
      }
      phi = min(.pi/2, max(-.pi/2, phi))
      let lam = point.x / Self.fxOfPhi(phi)
      return .init(x: Projections.wrapLongitude(lam + reference.x), y: phi)
    }

    private static func project(_ point: Point) -> Point {
      let phi = point.y
      let lam = point.x

      let phi2 = phi * phi
      let phi4 = phi2 * phi2

      let x = lam * (A0 + phi2 * (A1 + phi2 * (A2 + phi4 * phi2 * (A3 + phi2 * A4))))
      let y = phi * (B0 + phi2 * (B1 + phi4 * (B2 + B3 * phi2 + B4 * phi4)))

      return .init(x: x, y: y)
    }

    // y(phi) = B0·φ + B1·φ³ + B2·φ⁷ + B3·φ⁹ + B4·φ¹¹
    private static func yOfPhi(_ phi: Double) -> Double {
      let p2 = phi * phi, p4 = p2 * p2
      return phi * (B0 + p2 * (B1 + p4 * (B2 + B3 * p2 + B4 * p4)))
    }

    // dy/dphi = B0 + 3·B1·φ² + 7·B2·φ⁶ + 9·B3·φ⁸ + 11·B4·φ¹⁰
    private static func dyOfPhi(_ phi: Double) -> Double {
      let p2 = phi * phi, p4 = p2 * p2, p6 = p4 * p2, p8 = p4 * p4, p10 = p8 * p2
      return B0 + 3 * B1 * p2 + 7 * B2 * p6 + 9 * B3 * p8 + 11 * B4 * p10
    }

    // Coefficient of lambda in the forward x(lambda, phi) expression.
    private static func fxOfPhi(_ phi: Double) -> Double {
      let p2 = phi * phi, p4 = p2 * p2
      return A0 + p2 * (A1 + p2 * (A2 + p4 * p2 * (A3 + p2 * A4)))
    }
  }
  
}
