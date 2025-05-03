//
//  ProjectionMode.swift
//  GeoProjector
//
//  Created by Adrian Schönig on 1/10/2024.
//

import GeoJSONKit

public enum ProjectionMode: String, Codable, Sendable {
  case automatic

  case mercator
  case equirectangular
  case equalEarth
  case naturalEarth
  case gallPeters
  case azimuthal
  case orthographic
  
  public func resolve(for boundingBox: GeoJSON.BoundingBox) -> Projection {
    
    switch self {
    case .automatic where max(boundingBox.longitudeSpan, boundingBox.latitudeSpan) < 180, .orthographic:
      return Projections.Orthographic(reference: boundingBox.center)
    case .naturalEarth, .automatic:
      return Projections.NaturalEarth(reference: boundingBox.center)
    case .equalEarth:
      return Projections.EqualEarth(reference: boundingBox.center)

    case .mercator:
      return Projections.Mercator(reference: boundingBox.center)
    case .equirectangular:
      return Projections.Equirectangular(reference: boundingBox.center)
    case .gallPeters:
      return Projections.GallPeters(reference: boundingBox.center)
    case .azimuthal:
      return Projections.AzimuthalEquidistant(reference: boundingBox.center)
    }
    
  }
  
  public func resolve(for center: GeoJSON.Position = .init(latitude: 0, longitude: 0)) -> Projection {
    switch self {
    case .automatic, .naturalEarth:
      return Projections.NaturalEarth(reference: center)
    case .equalEarth:
      return Projections.EqualEarth(reference: center)
    case .orthographic:
      return Projections.Orthographic(reference: center)
    case .mercator:
      return Projections.Mercator(reference: center)
    case .equirectangular:
      return Projections.Equirectangular(reference: center)
    case .gallPeters:
      return Projections.GallPeters(reference: center)
    case .azimuthal:
      return Projections.AzimuthalEquidistant(reference: center)
    }
  }
}

extension GeoJSON.BoundingBox {
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
}
