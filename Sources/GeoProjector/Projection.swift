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

public enum MapBounds {
  case ellipse // Ellipse fitting inside the projection's size
  case rectangle // Rectangle fitting inside the projection's size
  case bezier([Point])
}

public protocol Projection {
  init(reference: Point)

  /// The reference point, which is projected to `(x: 0, y: 0)`. Can typically customised through
  /// the initialiser, but this value can return a different point if a custom reference point is not supported.
  var reference: Point { get }
  
  /// Applies to projection to the provided point, returning the projected point.
  ///
  /// The provided point is a geo-coordinate in radians, i.e., x as longitude and y as the latitude with an
  /// x range of `-pi...pi` and a y range of `(-pi/2)...(pi/2)`. The projection should use
  /// the same coordinate system, with ``reference`` projected to `(x: 0, y: 0)`. The projection
  /// can use a different range, which can use a smaller or larger range as indicated by
  /// ``projectionRange``.
  func project(_ point: Point) -> Point?
  
  func willWrap(_ point: Point) -> Bool
  
  /// The maximum width/height that the projection uses. All projected points should be in the range of
  /// x in `(-projectionSize.width / 2)...((+projectionSize.width / 2)` and y in
  /// x in `(-projectionSize.height / 2)...((+projectionSize.height / 2)`
  var projectionSize: Size { get }
  
  /// The bounds of the visible map
  var mapBounds: MapBounds { get }
  
  var invertCheck: ((GeoJSON.Polygon) -> Bool)? { get }
}

extension Projection {
  
  public var invertCheck: ((GeoJSON.Polygon) -> Bool)? { nil }
  
  public func willWrap(_ point: Point) -> Bool { false }
  
}

extension Projection {
  public init(reference: GeoJSON.Position = .init(latitude: 0, longitude: 0)) {
    self.init(reference: .init(x: reference.longitude.toRadians(), y: reference.latitude.toRadians()))
  }
}

extension Projection {
  
  public func point(for position: GeoJSON.Position, size: Size) -> (Point, Bool)? {
    let input = Point(x: position.longitude.toRadians(), y: position.latitude.toRadians())
    let wrap = self.willWrap(input)
    
    guard let projected = project(input) else { return nil }
    
    return (translate(projected, to: size), wrap)
  }
  
  public func translate(_ point: Point, to size: Size) -> Point {
    let myRatio = projectionSize.aspectRatio
    let targetRatio = size.aspectRatio
    
    let canvasSize: Size
    if myRatio > targetRatio {
      // target is heigher than me
      canvasSize = .init(width: size.width, height: size.width / myRatio)
    } else {
      // target is wider than me
      canvasSize = .init(width: size.height * myRatio, height: size.height)
    }
    
    let canvasOffset: Point = .init(
      x: (size.width - canvasSize.width) / 2,
      y: (size.height - canvasSize.height) / 2
    )
    
    let normalized = Point(
      x: ((point.x      + projectionSize.width / 2) / projectionSize.width),
      y: ((point.y * -1 + projectionSize.height / 2) / projectionSize.height)
    )
        
    return .init(
      x: canvasOffset.x + normalized.x * canvasSize.width,
      y: canvasOffset.y + normalized.y * canvasSize.height
    )
  }
  
}

extension Point {
  public func stretch(to size: Size) -> Point {
    .init(x: x * size.width, y: y * size.height)
  }
}

extension Size {
  var aspectRatio: Double {
    width / height
  }
}
