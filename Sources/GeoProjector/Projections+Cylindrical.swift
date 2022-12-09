//
//  Projection+Cylindrical.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

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
  
  /// Web standard
  /// https://en.wikipedia.org/wiki/Mercator_projection
  public struct Mercator: Projection {
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
      let adjusted = Projections.adjust(point, reference: reference)

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
