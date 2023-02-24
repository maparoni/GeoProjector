//
//  Projection.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

import Foundation

import GeoJSONKit
import GeoJSONKitTurf

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
  
  /// The maximum width/height that the projection uses, in radians.
  ///
  /// All projected points should be in the range of:
  /// - x in `(-projectionSize.width / 2)...((+projectionSize.width / 2)`, and
  /// - y in `(-projectionSize.height / 2)...((+projectionSize.height / 2)`.
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
  
  public func point(for position: GeoJSON.Position, zoomTo: Rect? = nil, size: Size, insets: EdgeInsets = .zero) -> (Point, Bool)? {
    let input = Point(x: position.longitude.toRadians(), y: position.latitude.toRadians())
    let wrap = self.willWrap(input)
    
    guard let projected = project(input) else { return nil }
    
    return (translate(projected, zoomTo: zoomTo, to: size, insets: insets), wrap)
  }
  
  
  /// Translates the projected `point` into a point within `size` where it should be drawn.
  ///
  /// - Parameters:
  ///   - point: Projected point, i.e., in radians
  ///   - zoomTo: Optional projected area to zoom to, i.e., in radians
  ///   - size: Drawing size, i.e., in screen points or pixels
  ///   - insets: Optional insets within `size` to reserve which the zoom shouldn't use
  /// - Returns: Drawing position of the point, in screen point. The point `(x:0, y:0)` is in bottom left on macOS, otherwise in top left.
  public func translate(_ point: Point, zoomTo: Rect? = nil, to size: Size, insets: EdgeInsets = .zero) -> Point {
    let availableSize = Size(width: size.width - insets.left - insets.right, height: size.height - insets.top - insets.bottom)
    let pointInAvailable: Point
    if let zoomTo {
      pointInAvailable = zoomedTranslate(point, zoomTo: zoomTo, to: availableSize)
    } else {
      pointInAvailable = simpleTranslate(point, to: availableSize)
    }
#if os(macOS)
    return Point(x: pointInAvailable.x + insets.left, y: pointInAvailable.y + insets.bottom)
#else
    return Point(x: pointInAvailable.x + insets.left, y: pointInAvailable.y + insets.top)
#endif
  }
  
  private func simpleTranslate(_ point: Point, to size: Size) -> Point {
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
    
    let flip: Double
    #if os(macOS)
    flip = 1
    #else
    flip = -1
    #endif
    
    let normalized = Point(
      x: ((point.x        + projectionSize.width / 2) / projectionSize.width),
      y: ((point.y * flip + projectionSize.height / 2) / projectionSize.height)
    )
        
    return .init(
      x: canvasOffset.x + normalized.x * canvasSize.width,
      y: canvasOffset.y + normalized.y * canvasSize.height
    )
  }
  
  private func zoomedTranslate(_ point: Point, zoomTo: Rect, to size: Size) -> Point {
    let myRatio = zoomTo.size.aspectRatio
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
    
    let flip: Double
    #if os(macOS)
    flip = 1
    #else
    flip = -1
    #endif
    
    let zoomedPoint = Point(
      x: point.x - zoomTo.origin.x,
      y: point.y - zoomTo.origin.y
    )
    
    let normalized = Point(
      x: (zoomedPoint.x        / zoomTo.size.width),
      y: (zoomedPoint.y * flip / zoomTo.size.height)
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
