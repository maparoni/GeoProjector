//
//  GeoDrawer.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif

import GeoJSONKit

@_exported import GeoProjector

public struct GeoDrawer {
  
  public init(/*boundingBox: GeoJSON.BoundingBox, */ size: Size, projection: Projection) {
    self.projection = projection
    self.size = size
    
    self.converter = { position -> (Point, Bool)? in
      return projection.point(for: position, size: size)
    }
  }
  
  let projection: Projection
  
  let size: Size
    
  var invertCheck: ((GeoJSON.Polygon) -> Bool)? { projection.invertCheck }
  
  let converter: (GeoJSON.Position) -> (Point, Bool)?
}

//extension GeoDrawer {
//
//  public static func suggestedBoundingBox(for positions: [GeoJSON.Position], allowSpanningAntimeridian: Bool = true) -> GeoJSON.BoundingBox {
//    let smallestBoundingBox = GeoJSON.BoundingBox(positions: positions, allowSpanningAntimeridian: allowSpanningAntimeridian)
//    let fittedBoundingBox: GeoJSON.BoundingBox
//    if smallestBoundingBox.spansAntimeridian, smallestBoundingBox.longitudeSpan > 180 {
//      fittedBoundingBox = GeoJSON.BoundingBox(positions: positions, allowSpanningAntimeridian: false)
//    } else {
//      fittedBoundingBox = smallestBoundingBox
//    }
//    let paddedBoundingBox = fittedBoundingBox.scale(x: 1.1, y: 1.1)
//    return paddedBoundingBox
//  }
//
//}

// MARK: - Content

extension GeoDrawer {
  
#if canImport(CoreGraphics)
  public typealias Color = CGColor
#else
  public struct Color {
    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
      self.red = red
      self.green = green
      self.blue = blue
      self.alpha = alpha
    }
    
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double
  }
#endif

  public enum Content {
    case line(GeoJSON.LineString, stroke: Color)
    case polygon(GeoJSON.Polygon, fill: Color, stroke: Color? = nil)
    case circle(GeoJSON.Position, radius: Double, fill: Color, stroke: Color? = nil)
  }
  
}

// MARK: - Line helper

extension GeoDrawer {
  
  /// - Returns: Typically returns a single element, but can return multiple, if the line wraps around
  func convertLine(_ positions: [GeoJSON.Position]) -> [[Point]] {
    
    // 1. Turn degrees into radians
    let unprojected = positions.map { Point(x: $0.longitude.toRadians(), y: $0.latitude.toRadians()) }
    
    // 2. Project pairs and interpolate between them, which is necessary if
    //    we can't just draw a line between the two projected points as the
    //    projection itself should be curved or it might not cover both
    //    endpoints.
    let projected = zip(unprojected.dropLast(), unprojected.dropFirst())
      .reduce(into: [(Point, Point)]()) { acc, next in
        if let start = projection.project(next.0) {
          acc.append((next.0, start))
        }
        acc.append(contentsOf: Interpolator.interpolate(from: next.0, to: next.1, maxDiff: 0.0025, projector: projection.project(_:)))
        if let end = projection.project(next.1) {
          acc.append((next.1, end))
        }
      }
    
    // 3. Now translate the projected points into point coordinates to draw
    let converted = projected
      .map { unproj, projected in
        return (projection.translate(projected, to: size), projection.willWrap(unproj))
      }

    // 4. Lastly split them up according to whether they were wrapped around
    //    the edge of the projection to the other side (or hidden).
    var result: [[Point]] = []
    var wip: ([Point], Bool) = ([], false)
    for (point, wrap) in converted {
      if wrap == wip.1 {
        wip.0.append(point)
      } else {
        if !wip.0.isEmpty {
          result.append(wip.0)
        }
        wip = ([point], wrap)
      }
    }
    if !wip.0.isEmpty {
      result.append(wip.0)
    }
    return result
  }
}
