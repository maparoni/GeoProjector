//
//  GeoDrawer.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
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
  
#if canImport(AppKit)
  public typealias Color = NSColor
#elseif canImport(UIKit)
  public typealias Color = UIColor
#endif
  
  public enum Content {
    case line(GeoJSON.LineString, stroke: Color)
    case polygon(GeoJSON.Polygon, fill: Color, stroke: Color? = nil)
    case circle(GeoJSON.Position, radius: Double, fill: Color, stroke: Color? = nil)
  }
  
}
