//
//  Projection+Cylindrical.swift
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

import GeoJSONKit

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

  /// Projection applying plain lat/long, use `phiOne = 0` for Plate Carée
  /// https://en.wikipedia.org/wiki/Equirectangular_projection
  public struct Equirectangular: Projection {
    public init(reference: Point, phiOne: Double) {
      self.reference = reference
      self.phiOne = phiOne.toRadians()
      
      self.projectionSize = .init(
        width: 2 * .pi * cos(phiOne),
        height: .pi
      )
    }

    public init(reference: Point) {
      self.init(reference: reference, phiOne: 0)
    }
    
    public init(reference: GeoJSON.Position, phiOne: Double) {
      self.init(reference: .init(x: reference.longitude.toRadians(), y: reference.latitude.toRadians()), phiOne: phiOne)
    }

    public let reference: Point

    /// "The standard parallels (north and south of the equator) where the scale of the projection is true"
    var phiOne: Double = 0
    
    public let projectionSize: Size
    
    public let mapBounds: MapBounds = .rectangle

    public func willWrap(_ point: Point) -> Bool {
      Projections.willWrap(point, reference: reference)
    }

    public func project(_ point: Point) -> Point? {
      let adjusted = Projections.adjust(point, reference: reference)
      return .init(
        x: adjusted.x * cos(phiOne),
        y: adjusted.y
      )
    }
    
  }
  
  /// https://en.wikipedia.org/wiki/Cassini_projection
  public struct Cassini: Projection {
    public init(reference: Point) {
      // custom reference not supported
    }
    
    public let reference: Point = .init(x: 0, y: 0)
    
    public let projectionSize: Size =
      .init(width: .pi, height: 2 * .pi)
    
    public let mapBounds: MapBounds = .rectangle
    
    public func willWrap(_ point: Point) -> Bool {
      return (point.x > .pi / 2  && point.y < 0)
          || (point.x < -.pi / 2 && point.y < 0)
          
    }

    public func project(_ point: Point) -> Point? {
      return .init(
        x: asin(cos(point.phi) * sin(point.lambda)),
        y: atan2(sin(point.phi), cos(point.phi) * cos(point.lambda))
      )
    }
  }
  
  /// Web standard
  /// https://en.wikipedia.org/wiki/Mercator_projection
  public struct Mercator: Projection {
    private static let maxLat = 85.051129.toRadians()
    
    public init(reference: Point) {
      self.reference = reference
    }
    
    public let reference: Point
    
    public let projectionSize: Size =
      .init(width: 2 * .pi, height: 2 * .pi)
    
    public let mapBounds: MapBounds = .rectangle
    
    public func willWrap(_ point: Point) -> Bool {
      Projections.willWrap(point, reference: reference)
    }

    public func project(_ point: Point) -> Point? {
      var adjusted = Projections.adjust(point, reference: reference)
      adjusted.y = min(Self.maxLat, max(Self.maxLat * -1, adjusted.y))
      
      return .init(
        x: adjusted.x,
        y: log(tan(.pi / 4 + adjusted.y / 2))
      )
    }
  }

  /// Ugly, but good equal-area representation
  /// https://en.wikipedia.org/wiki/Gall–Peters_projection
  public struct GallPeters: Projection {
    public init(reference: Point) {
      self.reference = reference
    }
    
    public let reference: Point
    
    public let projectionSize: Size =
      .init(width: 2 * .pi, height: 4)
    
    public let mapBounds: MapBounds = .rectangle
    
    public func willWrap(_ point: Point) -> Bool {
      Projections.willWrap(point, reference: reference)
    }

    public func project(_ point: Point) -> Point? {
      let adjusted = Projections.adjust(point, reference: reference)

      return .init(
        x: adjusted.x,
        y: 2 * sin(adjusted.y)
      )
    }
  }

}
