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
  
  private enum Grouping: Equatable {
    case wrapped
    case notWrapped
    case notProjected
  }
  
  /// - Returns: Typically returns a single element, but can return multiple, if the line wraps around
  func convertLine(_ positions: [GeoJSON.Position]) -> [[Point]] {
    
    // 1. Turn degrees into radians
    let unprojected = positions.map { Point(x: $0.longitude.toRadians(), y: $0.latitude.toRadians()) }
    
    // 2. Project pairs and interpolate between them, which is necessary if
    //    we can't just draw a line between the two projected points as the
    //    projection itself should be curved or it might not cover both
    //    endpoints.
    let projected = zip(unprojected.dropLast(), unprojected.dropFirst())
      .reduce(into: [(Point, Point?)]()) { acc, next in
        acc.append((next.0, projection.project(next.0)))
        acc.append(contentsOf: Interpolator.interpolate(from: next.0, to: next.1, maxDiff: 0.0025, projector: projection.project(_:)))
        acc.append((next.1, projection.project(next.1)))
      }
    
    // 3. Now translate the projected points into point coordinates to draw
    let converted = projected
      .map { (unproj, projected) -> (Point, Point?, Grouping) in
        if let projected {
          return (unproj, projection.translate(projected, to: size), projection.willWrap(unproj) ? .wrapped : .notWrapped)
        } else {
          return (unproj, nil, .notProjected)
        }
      }

    // 4. Lastly split them up according to whether they were wrapped around
    //    the edge of the projection to the other side (or hidden).
    var wraps: [(Point, Point)] = []
    var unwraps: [(Point, Point)] = []
    var wip: ([(Point, Point)], Grouping) = ([], .notProjected)
    for (unproj, proj, group) in converted {
      if group == wip.1 {
        if let proj {
          wip.0.append((unproj, proj))
        }
        
      } else {
        // We got to a new group
        if !wip.0.isEmpty {
          switch wip.1 {
          case .notWrapped:
            unwraps = wip.0
          case .wrapped:
            wraps = wip.0
          case .notProjected:
            break
          }
        }
          
        var new: [(Point, Point)]
        switch group {
        case .notWrapped:
          new = unwraps
        case .wrapped:
          new = wraps
        case .notProjected:
          new = []
        }

        if let last = new.last?.0 {
          // When "resuming" the same group, connect with the previous points
          // in the group, but interpolate again.
          let interpolated = Interpolator.interpolate(from: last, to: unproj, maxDiff: 0.0025, projector: projection.project(_:))
          let translated = interpolated.map { ($0.0, projection.translate($0.1, to: size)) }
          new.append(contentsOf: translated)
        }
        if let proj {
          new.append((unproj, proj))
        }
        wip = (new, group)
      }
    }
    if !wip.0.isEmpty {
      switch wip.1 {
      case .notWrapped:
        unwraps = wip.0
      case .wrapped:
        wraps = wip.0
      case .notProjected:
        break
      }
    }
    return [wraps.map(\.1), unwraps.map(\.1)].filter { !$0.isEmpty }
  }
}
