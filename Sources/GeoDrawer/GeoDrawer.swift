//
//  GeoDrawer.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2022 Corporoni Pty Ltd
//
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Lesser General Public
// License as published by the Free Software Foundation; either
// version 2.1 of the License, or (at your option) any later version.
//
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public
// License along with this library; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301
// USA

#if canImport(CoreGraphics)
import CoreGraphics
#endif

import GeoJSONKit

@_exported import GeoProjector

public struct GeoDrawer {
  
  public init(size: Size, converter: @escaping (GeoJSON.Position) -> Point) {
    self.projection = nil
    self.size = size
    self.zoomTo = nil
    self.insets = .zero
    self.converter = { (converter($0), false) }
  }
  
  public init(size: Size, projection: Projection, zoomTo: GeoJSON.BoundingBox? = nil, insets: EdgeInsets = .zero) {
    self.projection = projection
    self.size = size
    self.insets = insets
    
    let zoomToRect: Rect? = zoomTo.flatMap { box in
      let positions = [
        GeoJSON.Position(latitude: box.northEasterlyLatitude, longitude: box.southWesterlyLongitude),
        GeoJSON.Position(latitude: box.northEasterlyLatitude, longitude: box.northEasterlyLongitude),
        GeoJSON.Position(latitude: box.southWesterlyLatitude, longitude: box.northEasterlyLongitude),
        GeoJSON.Position(latitude: box.southWesterlyLatitude, longitude: box.southWesterlyLongitude),
      ]
      
      let lines = [
        GeoJSON.LineString(positions: [positions[0], positions[1]]),
        GeoJSON.LineString(positions: [positions[1], positions[2]]),
        GeoJSON.LineString(positions: [positions[2], positions[3]]),
        GeoJSON.LineString(positions: [positions[3], positions[0]]),
      ]
      
      let bounds: Rect? = lines.reduce(nil) { acc, next in
        let points = Self.projectLine(next.positions, projection: projection).compactMap(\.1)
        if var acc {
          for point in points {
            acc.absorb(point)
          }
          return acc
        } else if let first = points.first {
          var rect = Rect(origin: first, size: .zero)
          for point in points.dropFirst() {
            rect.absorb(point)
          }
          return rect
        } else {
          return nil
        }
      }
      guard let bounds else { return nil }
      
      // Zoom out a whole bit to give some global context
      let scaled = bounds.scaled(x: 5, y: 5)
      
      // But don't zoom out further than the projection size
      if scaled.size.width < projection.projectionSize.width, scaled.size.height < projection.projectionSize.height {
        return scaled
      } else {
        return nil
      }
    }
    
    self.zoomTo = zoomToRect
    
    self.converter = { position -> (Point, Bool)? in
      return projection.point(for: position, zoomTo: zoomToRect, size: size, insets: insets)
    }
  }
  
  public let projection: Projection?
  
  public let size: Size
  
  public let zoomTo: Rect?
  
  public let insets: EdgeInsets
      
  var invertCheck: ((GeoJSON.Polygon) -> Bool)? { projection?.invertCheck }
  
  let converter: (GeoJSON.Position) -> (Point, Bool)?
}

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
  
  private static func projectLine(_ positions: [GeoJSON.Position], projection: Projection) -> [(Point, Point?)] {
    
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
    
    return projected
  }
  
  /// - Returns: Typically returns a single element, but can return multiple, if the line wraps around
  func convertLine(_ positions: [GeoJSON.Position]) -> [[Point]] {
    guard let projection else {
      return [positions.compactMap {
        self.converter($0)?.0
      }]
    }
    
    let projected = Self.projectLine(positions, projection: projection)
    
    // 3. Now translate the projected points into point coordinates to draw
    let converted = projected
      .map { (unproj, projected) -> (Point, Point?, Grouping) in
        if let projected {
          return (unproj, projection.translate(projected, zoomTo: zoomTo, to: size, insets: insets), projection.willWrap(unproj) ? .wrapped : .notWrapped)
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
          let translated = interpolated.map { ($0.0, projection.translate($0.1, zoomTo: zoomTo, to: size, insets: insets)) }
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
