//
//  Projection.swift
//
//
//  Created by Adrian Schönig on 2/12/2022.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2022 Corporoni Pty Ltd. See LICENSE.

import Foundation

import GeoJSONKit
import GeoJSONKitTurf

public enum MapBounds {
  case ellipse // Ellipse fitting inside the projection's size
  case rectangle // Rectangle fitting inside the projection's size
  case bezier([Point])
}

public enum CoordinateSystem {
  case topLeft    // Standard for SVG, UIImage, most computer graphics
  case bottomLeft // Standard for NSImage (non-flipped), mathematical coordinates
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
  /// ``projectionSize``.
  func project(_ point: Point) -> Point?

  /// Inverse of ``project(_:)``. Maps a projected point (the output of ``project(_:)``,
  /// in the projection's internal radian coordinate system) back to a geographic
  /// coordinate in radians: x (longitude) in `-pi...pi`, y (latitude) in `(-pi/2)...(pi/2)`.
  ///
  /// Returns `nil` if the input lies outside the projection's image (e.g. outside the
  /// unit ellipse for Orthographic, outside the bezier outline for EqualEarth/NaturalEarth,
  /// or beyond the rectangle for the cylindricals).
  func inverse(_ point: Point) -> Point?

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

}

extension Projection {
  public init(reference: GeoJSON.Position = .init(latitude: 0, longitude: 0)) {
    self.init(reference: .init(x: reference.longitude.toRadians(), y: reference.latitude.toRadians()))
  }
}

extension Projection {

  /// Projects an input point into a projected  point within `size` where it should be drawn, optionally
  /// accounting for zooming into
  /// a particular area of the map and adding insets around the map.
  public func point(for point: Point, size: Size, zoomTo: Rect? = nil, insets: EdgeInsets = .zero, coordinateSystem: CoordinateSystem) -> Point? {
    guard let projected = project(point) else { return nil }

    return translate(projected, to: size, zoomTo: zoomTo, insets: insets, coordinateSystem: coordinateSystem)
  }

  /// Translates the projected `point` into a point within `size` where it should be drawn.
  ///
  /// - Parameters:
  ///   - point: Projected point, i.e., in radians
  ///   - size: Drawing size, i.e., in screen points or pixels
  ///   - zoomTo: Optional projected area to zoom to, i.e., in radians
  ///   - insets: Optional insets within `size` to reserve which the zoom shouldn't use
  /// - Returns: Drawing position of the point, in screen point. The point `(x:0, y:0)` is in bottom left on macOS, otherwise in top left.
  public func translate(_ point: Point, to size: Size, zoomTo: Rect? = nil, insets: EdgeInsets = .zero, coordinateSystem: CoordinateSystem) -> Point {
    let availableSize = Size(
      width: size.width - insets.left - insets.right,
      height: size.height - insets.top - insets.bottom
    )
    let pointInAvailable: Point
    if let zoomTo, zoomTo.size != .zero {
      pointInAvailable = zoomedTranslate(point, zoomTo: zoomTo, to: availableSize)
    } else {
      pointInAvailable = simpleTranslate(point, to: availableSize)
    }
    assert(pointInAvailable.isGood)

    let x: Double = pointInAvailable.x + insets.left
    let y: Double
    switch coordinateSystem {
    case .bottomLeft:
      y = pointInAvailable.y + insets.bottom
    case .topLeft:
      y = (availableSize.height - pointInAvailable.y) + insets.top
    }
    let result = Point(x: x, y: y)
    assert(result.isGood)
    return result
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

    let normalized = Point(
      x: (point.x + projectionSize.width  / 2) / projectionSize.width,
      y: (point.y + projectionSize.height / 2) / projectionSize.height
    )

    return .init(
      x: canvasOffset.x + normalized.x * canvasSize.width,
      y: canvasOffset.y + normalized.y * canvasSize.height
    )
  }

  /// Inverse of ``translate(_:to:zoomTo:insets:coordinateSystem:)``: turns a screen-space
  /// point (e.g. the location of a click) back into projected radians.
  public func untranslate(_ point: Point, from size: Size, zoomTo: Rect? = nil, insets: EdgeInsets = .zero, coordinateSystem: CoordinateSystem) -> Point {
    let availableSize = Size(
      width: size.width - insets.left - insets.right,
      height: size.height - insets.top - insets.bottom
    )

    let xInAvailable = point.x - insets.left
    let yInAvailable: Double
    switch coordinateSystem {
    case .bottomLeft:
      yInAvailable = point.y - insets.bottom
    case .topLeft:
      yInAvailable = availableSize.height - (point.y - insets.top)
    }
    let pointInAvailable = Point(x: xInAvailable, y: yInAvailable)

    if let zoomTo, zoomTo.size != .zero {
      return zoomedUntranslate(pointInAvailable, zoomTo: zoomTo, from: availableSize)
    } else {
      return simpleUntranslate(pointInAvailable, from: availableSize)
    }
  }

  /// Inverse of ``point(for:size:zoomTo:insets:coordinateSystem:)``.
  ///
  /// Given a screen-space point (e.g. a click), returns the geographic position in
  /// **degrees**, or `nil` if the click is outside the projection's image (e.g. clicking
  /// off the globe of an Orthographic map, or off the bezier outline of EqualEarth).
  public func coordinate(at point: Point, size: Size, zoomTo: Rect? = nil, insets: EdgeInsets = .zero, coordinateSystem: CoordinateSystem) -> GeoJSON.Position? {
    let projected = untranslate(point, from: size, zoomTo: zoomTo, insets: insets, coordinateSystem: coordinateSystem)
    guard let geoRad = inverse(projected) else { return nil }
    return .init(latitude: geoRad.y.toDegrees(), longitude: geoRad.x.toDegrees())
  }

  private func simpleUntranslate(_ point: Point, from size: Size) -> Point {
    let myRatio = projectionSize.aspectRatio
    let targetRatio = size.aspectRatio

    let canvasSize: Size
    if myRatio > targetRatio {
      canvasSize = .init(width: size.width, height: size.width / myRatio)
    } else {
      canvasSize = .init(width: size.height * myRatio, height: size.height)
    }

    let canvasOffset = Point(
      x: (size.width - canvasSize.width) / 2,
      y: (size.height - canvasSize.height) / 2
    )

    let normalized = Point(
      x: (point.x - canvasOffset.x) / canvasSize.width,
      y: (point.y - canvasOffset.y) / canvasSize.height
    )

    return .init(
      x: normalized.x * projectionSize.width  - projectionSize.width  / 2,
      y: normalized.y * projectionSize.height - projectionSize.height / 2
    )
  }

  private func zoomedUntranslate(_ point: Point, zoomTo: Rect, from size: Size) -> Point {
    assert(zoomTo.size != .zero)
    let myRatio = zoomTo.size.aspectRatio
    let targetRatio = size.aspectRatio

    let canvasSize: Size
    if myRatio > targetRatio {
      canvasSize = .init(width: size.width, height: size.width / myRatio)
    } else {
      canvasSize = .init(width: size.height * myRatio, height: size.height)
    }

    let canvasOffset = Point(
      x: (size.width - canvasSize.width) / 2,
      y: (size.height - canvasSize.height) / 2
    )

    let normalized = Point(
      x: (point.x - canvasOffset.x) / canvasSize.width,
      y: (point.y - canvasOffset.y) / canvasSize.height
    )

    return .init(
      x: normalized.x * zoomTo.size.width  + zoomTo.origin.x,
      y: normalized.y * zoomTo.size.height + zoomTo.origin.y
    )
  }

  private func zoomedTranslate(_ point: Point, zoomTo: Rect, to size: Size) -> Point {
    assert(zoomTo.size != .zero)
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

    let zoomedPoint = Point(
      x: point.x - zoomTo.origin.x,
      y: point.y - zoomTo.origin.y
    )

    let normalized = Point(
      x: (zoomedPoint.x / zoomTo.size.width),
      y: (zoomedPoint.y / zoomTo.size.height)
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

fileprivate extension Point {
  var isGood: Bool {
    !x.isNaN && !y.isNaN && !x.isInfinite && !y.isInfinite
  }
}
