//
//  Projection.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

import Foundation

import GeoJSONKit
import GeoJSONKitTurf

public struct Point: Equatable {
  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }
  
  public let x: Double
  public let y: Double
  
  var lambda: Double { x }
  var phi: Double { y }
  var lng: Double { x }
  var lat: Double { y }
}

public struct Size: Equatable {
  public init(width: Double, height: Double) {
    self.width = width
    self.height = height
  }
  
  public let width: Double
  public let height: Double
}

public protocol Projection {
  init(reference: Point)
  
  func project(_ point: Point) -> Point
  
  func willWrap(_ point: Point) -> Bool
  
  var reference: Point { get }
  
  /// The bounds of the visible map considering projection and reference
  var mapBounds: GeoJSON.Polygon { get }
  
  var invertCheck: ((GeoJSON.Polygon) -> Bool)? { get }
}

extension Projection {
  
  public var invertCheck: ((GeoJSON.Polygon) -> Bool)? { nil }
  
  public func willWrap(_ point: Point) -> Bool { false }
  
  public var mapBounds: GeoJSON.Polygon {
    // By default, only the longitude delta is considered to allow scrolling
    // beyond the antimeridian.
    let longDelta = reference.x.toDegrees()
    
    // You deal with weird rounding errors when going directly to 90/180...
    let world: [GeoJSON.Position] = [
      .init(latitude:  89.9, longitude: -179.9 + longDelta),
      .init(latitude:  89.9, longitude:  179.9 + longDelta),
      .init(latitude: -89.9, longitude:  179.9 + longDelta),
      .init(latitude: -89.9, longitude: -179.9 + longDelta),
      .init(latitude:  89.9, longitude: -179.9 + longDelta),
    ]
    return GeoJSON.Polygon(exterior: .init(positions: world).chunked(length: 100_000))
  }
  
}

extension Projection {
  public init(reference: GeoJSON.Position = .init(latitude: 0, longitude: 0)) {
    self.init(reference: .init(x: reference.longitude.toRadians(), y: reference.latitude.toRadians()))
  }
}

extension Projection {
  
  public func point(for position: GeoJSON.Position, size: Size) -> (Point, Bool) {
    let input = Point(x: position.longitude.toRadians(), y: position.latitude.toRadians())
    let wrap = self.willWrap(input)
    
    let projected = project(input)
    
    let reversed = Point(x: projected.x.toDegrees(), y: projected.y.toDegrees())
    let normalized = Point(x: (reversed.x + 180) / 360, y: (reversed.y * -1 + 90) / 180)
    return (.init(x: normalized.x * size.width, y: normalized.y * size.height), wrap)
  }
  
}
