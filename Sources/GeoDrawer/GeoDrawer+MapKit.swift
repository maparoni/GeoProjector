//
//  GeoDrawer+MapKit.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

#if canImport(UIKit) && canImport(MapKit)

import MapKit
import UIKit

import GeoJSONKit

extension GeoDrawer {
  
  public func draw(_ overlay: MKMultiPoint, fillColor: UIColor?, strokeColor: UIColor? = nil, frame: CGRect) {
    if let polygon = overlay as? MKPolygon {
      draw(
        GeoJSON.Polygon(
          exterior: .init(positions: polygon.positions),
          interiors: (polygon.interiorPolygons ?? []).map {
            .init(positions: $0.positions)
          }
        ),
        fillColor: fillColor ?? .clear,
        strokeColor: strokeColor,
        frame: frame
      )
    } else if let strokeColor {
      draw(GeoJSON.LineString(positions: overlay.positions), strokeColor: strokeColor)
    }
  }
  
  public func drawCircle(_ annotation: MKAnnotation, radius: CGFloat, fillColor: UIColor, strokeColor: UIColor? = nil) {
    let radius: CGFloat = 3
    drawCircle(
      .init(latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude),
      radius: radius,
      fillColor: fillColor,
      strokeColor: strokeColor
    )
  }
  
}

extension MKMultiPoint {
  public var positions: [GeoJSON.Position] {
    UnsafeBufferPointer(start: points(), count: pointCount)
      .map { GeoJSON.Position(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
  }
}

#endif
