//
//  BoundingBox+Helpers.swift
//  GeoProjector
//
//  Created by Adrian Schönig on 18/9/2024.
//

import GeoJSONKit

extension GeoJSON.BoundingBox {
  
  public static func suggestedBox(for positions: [GeoJSON.Position], allowSpanningAntimeridian: Bool = true) -> GeoJSON.BoundingBox {
    if positions.count == 1, let only = positions.first {
      let extended1 = only.coordinate(at: 10_000, facing: 45)
      let extended2 = only.coordinate(at: 10_000, facing: 225)
      return GeoJSON.BoundingBox(positions: [extended1, extended2])
      
    } else {
      let smallestBoundingBox = GeoJSON.BoundingBox(positions: positions, allowSpanningAntimeridian: allowSpanningAntimeridian)
      let fittedBoundingBox: GeoJSON.BoundingBox
      if smallestBoundingBox.spansAntimeridian, smallestBoundingBox.longitudeSpan > 180 {
        fittedBoundingBox = GeoJSON.BoundingBox(positions: positions, allowSpanningAntimeridian: false)
      } else {
        fittedBoundingBox = smallestBoundingBox
      }
      let paddedBoundingBox = fittedBoundingBox.scaled(x: 1.1, y: 1.1)
      return paddedBoundingBox
    }
  }
  
  public var latitudeSpan: Double {
    northEasterlyLatitude - southWesterlyLatitude
  }
  
  public var longitudeSpan: Double {
    if spansAntimeridian {
      return northEasterlyLongitude + 360 - southWesterlyLongitude
    } else {
      return northEasterlyLongitude - southWesterlyLongitude
    }
  }
  
  public var aspectRatio: Double {
    if longitudeSpan > 0, latitudeSpan > 0 {
      return longitudeSpan / latitudeSpan
    } else {
      return 0
    }
  }
  
  public func scaled(x: Double, y: Double) -> GeoJSON.BoundingBox {
    let latitudeDelta = (latitudeSpan * y - latitudeSpan) / 2
    let longitudeDelta = (longitudeSpan * x - longitudeSpan) / 2
    let candidate = GeoJSON.BoundingBox(
      positions: [
        .init(latitude: northEasterlyLatitude + latitudeDelta, longitude: northEasterlyLongitude + longitudeDelta),
        .init(latitude: northEasterlyLatitude - latitudeDelta, longitude: northEasterlyLongitude - longitudeDelta),
        .init(latitude: southWesterlyLatitude + latitudeDelta, longitude: southWesterlyLongitude + longitudeDelta),
        .init(latitude: southWesterlyLatitude - latitudeDelta, longitude: southWesterlyLongitude - longitudeDelta),
      ],
      allowSpanningAntimeridian: spansAntimeridian // don't change that
    )
    
    // Scaling shouldn't allow going outside the valid latitude bounds. If it
    // does, just abort and return un-scaled bounding box.
    let validLatitudes = (-90.0)...(90.0)
    if validLatitudes.contains(candidate.northEasterlyLatitude), validLatitudes.contains(candidate.southWesterlyLatitude) {
      return candidate
    } else {
      return self
    }
  }
  
}
