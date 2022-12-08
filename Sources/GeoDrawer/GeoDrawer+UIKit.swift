//
//  GeoDrawer+UIKit.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

#if canImport(UIKit)
import UIKit

import GeoJSONKit
import GeoJSONKitTurf
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
    guard fillColor != .clear || (strokeColor != nil && strokeColor != .clear) else { return }
    
    let converted = polygon.exterior.positions.map(converter)
    
    // In some projections such as Azimuthal, we might need to colour a cut-out
    // rather than the projected polygon.
    let invert: Bool = invertCheck?(polygon) ?? false
    
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
      if !polygon.interiors.isEmpty {
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
      
      if invert {
        // TODO: This doesn't actually invert. Would be nice to do that later.
        fillColor.setStroke()
        path.lineWidth = 2
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
        
      } else if fillColor != .clear {
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
  
  func draw(_ bounds: MapBounds, fillColor: UIColor? = nil, strokeColor: UIColor? = nil) {
    let path: UIBezierPath
    
    switch bounds {
    case .ellipse:
      let min = projection.translate(.init(x: -1 * projection.projectionSize.width / 2, y: projection.projectionSize.height / 2), to: size)
      let max = projection.translate(.init(x: projection.projectionSize.width / 2, y: -1 * projection.projectionSize.height / 2), to: size)

      path = UIBezierPath(ovalIn: .init(
        origin: min.cgPoint,
        size: .init(width: max.x - min.x, height: max.y - min.y)
      ))
      
    case .rectangle:
      let min = projection.translate(.init(x: -1 * projection.projectionSize.width / 2, y: projection.projectionSize.height / 2), to: size)
      let max = projection.translate(.init(x: projection.projectionSize.width / 2, y: -1 * projection.projectionSize.height / 2), to: size)
      
      let points: [Point] = [
        .init(x: min.x, y: min.y),
        .init(x: max.x, y: min.y),
        .init(x: max.x, y: max.y),
        .init(x: min.x, y: max.y),
        .init(x: min.x, y: min.y),
      ]
      path = UIBezierPath(points: points, size: self.size)
    
    case .bezier(let array):
      path = UIBezierPath(points: array, size: self.size)
    }
    
    if let fillColor {
      fillColor.setFill()
      path.fill()
    }
    
    if let strokeColor {
      path.lineWidth = 2
      strokeColor.setStroke()
      path.stroke()
    }

  }
  
}

extension UIBezierPath {
  fileprivate convenience init(points: [Point], size: Size) {
    self.init()
    
    guard !points.isEmpty else { return }
    move(to: points[0].cgPoint)
    for point in points[1...] {
      addLine(to: point.cgPoint)
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
      #warning("TODO: In step one, we could turn this into shapes; and then get the bounding box of the shapes, and then only draw that, placing it into the desired `size` by setting an appropriate offset. That way we don't need to 'hack' the projection formulas to align to 0. And it would make the inverse easier, though it'd need to consider those offsets.")
      
//      if let background {
//        background.setFill()
//        rendererContext.fill(bounds)
//      }
      UIColor.white.setFill()
      rendererContext.fill(bounds)

      // Draw the background
      draw(projection.mapBounds, fillColor: background ?? .systemBlue)
      
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
      
      // Draw a border background *on top*
      draw(projection.mapBounds, strokeColor: .black)

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
