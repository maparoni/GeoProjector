//
//  Projection+Azimuthal.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2022 Corporoni Pty Ltd. See LICENSE.

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

    public func inverse(_ point: Point) -> Point? {
      // For the Azimuthal Equidistant projection, the planar radius equals the
      // angular distance c, so c = rho directly (no asin like in Orthographic).
      let X = point.x, Y = point.y
      let rho = sqrt(X*X + Y*Y)
      guard rho <= .pi + 1e-12 else { return nil }
      if rho < 1e-15 { return reference }
      let c = rho
      let sinC = sin(c), cosC = cos(c)
      let phi = asin(cosC * sin(reference.y) + (Y * sinC * cos(reference.y)) / rho)
      let lam = reference.x + atan2(
        X * sinC,
        rho * cos(reference.y) * cosC - Y * sin(reference.y) * sinC
      )
      return .init(x: Projections.wrapLongitude(lam), y: phi)
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
