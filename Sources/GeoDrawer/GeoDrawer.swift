//
//  GeoDrawer.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

import GeoJSONKit

import GeoProjector

public struct GeoDrawer {
  
  public init(/*boundingBox: GeoJSON.BoundingBox, */ size: Size, projection: Projection) {
    self.projection = projection
    self.size = size
    
    self.converter = { position -> (Point, Bool)? in
      return projection.point(for: position, size: size)
    }

//    let mapRatio = CGFloat(boundingBox.aspectRatio)  // e.g., 100w,200h: 0.5
//    let boundsRatio = size.aspectRatio               // e.g., 100w,50h:  2
//
//    let targetSize: CGSize
//    let offset: CGPoint
//    if mapRatio < boundsRatio {
//      // constrained by height
//      targetSize = CGSize(width: size.height * mapRatio, height: size.height)     // e.g., 25w,50h
//      offset = CGPoint(x: (size.width - targetSize.width) / 2, y: 0)
//
//    } else {
//      // constrained by width
//      targetSize = CGSize(width: size.width, height: size.width / mapRatio)
//      offset = CGPoint(x: 0, y: (size.height - targetSize.height) / 2)
//    }
//
//    let scale = targetSize.length / CGFloat(boundingBox.length)
//    let boxOrigin = GeoJSON.Position(latitude: boundingBox.northEasterlyLatitude, longitude: boundingBox.southWesterlyLongitude)
//    let boxEndLongitude = boundingBox.northEasterlyLongitude
//
//    self.converter = { position -> (CGPoint, Bool) in
//      var candidate = position
//      var crossed: Bool = false
//      if boundingBox.spansAntimeridian, position.longitude < boxOrigin.longitude, abs(position.longitude - boxOrigin.longitude) > abs(position.longitude - boxEndLongitude) {
//        candidate.longitude += 360
//        crossed = true
//      }
//      let mapOffset: GeoJSON.Position = candidate - boxOrigin
//      let mapUnitVector = mapOffset.unitVector
//      let length = CGFloat(mapOffset.length) * scale
//      let point = offset + length * CGPoint(x: mapUnitVector.x, y: mapUnitVector.y * -1) // -1 as y origin is +90
//      return (point, crossed)
//    }

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
