//
//  GeoDrawer+UIKit.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

#if canImport(UIKit)
import UIKit

import GeoJSONKit
import GeoProjector

// MARK: - Context drawing

extension GeoDrawer {
  
  /// Draws the line into the current context
  public func draw(_ line: GeoJSON.LineString, strokeColor: UIColor) {
    guard strokeColor != .clear else { return }

    let converted = line.positions.map(converter)
    let grouped = Dictionary(grouping: converted, by: \.1).mapValues { $0.map(\.0) }
    for points in grouped.values {
      
      let path = UIBezierPath()
      path.move(to: points[0].cgPoint)
      for point in points[1...] {
        path.addLine(to: point.cgPoint)
      }
      
      strokeColor.setStroke()
      path.lineWidth = 2
      path.lineCapStyle = .round
      path.lineJoinStyle = .round
      path.stroke()
    }
  }
  
  public func draw(_ polygon: GeoJSON.Polygon, fillColor: UIColor, strokeColor: UIColor? = nil, frame: CGRect) {
    //guard fillColor != .clear || (strokeColor != nil && strokeColor != .clear) else { return }
    
    let converted = polygon.exterior.positions.map(converter)
    let grouped = Dictionary(grouping: converted, by: \.1).mapValues { $0.map(\.0) }
    for points in grouped.values {
      
      let path = UIBezierPath()
      path.move(to: points[0].cgPoint)
      for point in points[1...] {
        path.addLine(to: point.cgPoint)
      }
      
      // First we need to create a clip path, i.e., the area where we allowed to fill in the actual polygon.
      // This is the whole frame *minus* the interior polygons.
      // Useful example: https://samplecodebank.blogspot.com/2013/06/UIBezierPath-addClip-example.html
      if !polygon.interiors.isEmpty{
        let rect = UIBezierPath()
        rect.usesEvenOddFillRule = true
        rect.move(to: frame.origin)
        rect.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
        rect.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
        rect.addLine(to: CGPoint(x: frame.maxX, y: frame.minY))

        for interior in polygon.interiors {
          let interiorPoints = interior.positions.map(converter).map(\.0)
          guard !interiorPoints.isEmpty else { continue }
          
          rect.move(to: interiorPoints[0].cgPoint)
          for point in interiorPoints[1...] {
            rect.addLine(to: point.cgPoint)
          }
        }
        
        rect.addClip()
      }

      // Then we can draw the polygon
      if fillColor != .clear {
        fillColor.setFill()
        path.lineWidth = 0
        path.fill()
        
      } else if let strokeColor, strokeColor != .clear {
        strokeColor.setStroke()
        path.lineWidth = 2
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
      }
    }
  }
  
  func drawCircle(_ position: GeoJSON.Position, radius: CGFloat, fillColor: UIColor, strokeColor: UIColor? = nil) {
    
    let path = UIBezierPath(ovalIn: .init(
      origin: converter(position).0.cgPoint,
      size: .init(width: radius, height: radius)
    ))
    
    fillColor.setFill()
    path.fill()
    
    if let strokeColor {
      path.lineWidth = 2
      strokeColor.setStroke()
      path.stroke()
    }
  }
  
}

// MARK: - Image drawing

extension GeoDrawer {
  
  enum Content {
    case line(GeoJSON.LineString, stroke: UIColor)
    case polygon(GeoJSON.Polygon, fill: UIColor, stroke: UIColor? = nil)
    case circle(GeoJSON.Position, radius: Double, fill: UIColor, stroke: UIColor? = nil)
  }
  
  func drawImage(_ contents: [Content], background: UIColor? = nil, size: CGSize) -> UIImage {
    
    let format = UIGraphicsImageRendererFormat()
    format.opaque = true
    let bounds = CGRect(origin: .zero, size: size)
    let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
    let image = renderer.image { rendererContext in
      if let background {
        background.setFill()
        rendererContext.fill(bounds)
      }
      
      // Then draw contents on top
      for content in contents {
        switch content {
        case let .circle(position, radius, fill, stroke):
          drawCircle(position, radius: radius, fillColor: fill, strokeColor: stroke)
        case let .line(line, stroke):
          draw(line, strokeColor: stroke)
        case let .polygon(polygon, fill, stroke):
          draw(polygon, fillColor: fill, strokeColor: stroke, frame: bounds)
        }
      }
    }
    return image
    
  }
  
}

extension Point {
  var cgPoint: CGPoint {
    .init(x: x, y: y)
  }
}

#endif
