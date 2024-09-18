//
//  GeoDrawer+ProjectionMode.swift
//  GeoProjector
//
//  Created by Adrian Schönig on 18/9/2024.
//

import GeoJSONKit

extension GeoDrawer {
  public enum ProjectionMode: String {
    case automatic

    case mercator
    case equirectangular
    case equalEarth
    case gallPeters
    case azimuthal
    case orthographic
    
    public func resolve(for boundingBox: GeoJSON.BoundingBox) -> Projection {
      
      switch self {
      case .automatic where max(boundingBox.longitudeSpan, boundingBox.latitudeSpan) < 180, .orthographic:
        return Projections.Orthographic(reference: boundingBox.center)
      case .equalEarth, .automatic:
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
  }
}
