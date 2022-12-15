//
//  GeoDrawer+UIKit.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

#if canImport(CoreGraphics)
import CoreGraphics

import GeoJSONKit
import GeoJSONKitTurf
import GeoProjector

// MARK: - Context drawing

extension GeoDrawer {
  
  /// Draws the line into the current context
  public func draw(_ line: GeoJSON.LineString, strokeColor: CGColor, in context: CGContext) {
    let converted = line.positions.compactMap(converter)
    let grouped = Dictionary(grouping: converted, by: \.1).mapValues { $0.map(\.0) }
    for points in grouped.values {
      
      let path = CGMutablePath()
      path.move(to: points[0].cgPoint)
      for point in points[1...] {
        path.addLine(to: point.cgPoint)
      }
      
      context.setStrokeColor(strokeColor)

      context.setLineWidth(2)
      context.setLineCap(.round)
      context.setLineJoin(.round)
      
      context.addPath(path)
      context.strokePath()
    }
  }
  
  public func draw(_ polygon: GeoJSON.Polygon, fillColor: CGColor? = nil, strokeColor: CGColor? = nil, frame: CGRect, in context: CGContext) {
    let converted = polygon.exterior.positions.compactMap(converter)
    
    // In some projections such as Azimuthal, we might need to colour a cut-out
    // rather than the projected polygon.
    let invert: Bool = invertCheck?(polygon) ?? false
    
    let grouped = Dictionary(grouping: converted, by: \.1).mapValues { $0.map(\.0) }
    for points in grouped.values {
      
      let path = CGMutablePath()
      path.move(to: points[0].cgPoint)
      for point in points[1...] {
        path.addLine(to: point.cgPoint)
      }
      
      // First we need to create a clip path, i.e., the area where we allowed to fill in the actual polygon.
      // This is the whole frame *minus* the interior polygons.
      // Useful example: https://samplecodebank.blogspot.com/2013/06/UIBezierPath-addClip-example.html
      if !polygon.interiors.isEmpty {
        let rect = CGMutablePath()
        rect.move(to: frame.origin)
        rect.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
        rect.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
        rect.addLine(to: CGPoint(x: frame.maxX, y: frame.minY))
        
        for interior in polygon.interiors {
          let interiorPoints = interior.positions.compactMap(converter).map(\.0)
          guard !interiorPoints.isEmpty else { continue }
          
          rect.move(to: interiorPoints[0].cgPoint)
          for point in interiorPoints[1...] {
            rect.addLine(to: point.cgPoint)
          }
        }
        
        context.addPath(rect)
        context.clip(using: .evenOdd)
      }
      
      // Then we can draw the polygon
      
      context.addPath(path)

      if let fillColor {
        
        if invert {
          // TODO: This doesn't actually invert. Would be nice to do that later.
          context.setStrokeColor(fillColor)
          context.setLineWidth(2)
          context.setLineCap(.round)
          context.setLineJoin(.round)
          context.strokePath()

        } else {
          context.setFillColor(fillColor)
          context.setLineWidth(0)
          context.fillPath()
        }
        
      } else if let strokeColor {
        context.setStrokeColor(strokeColor)
        context.setLineWidth(2)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.strokePath()
      }
    }
  }
  
  func drawCircle(_ position: GeoJSON.Position, radius: CGFloat, fillColor: CGColor, strokeColor: CGColor? = nil, in context: CGContext) {
    guard let origin = converter(position) else { return }
    
    let path = CGPath(ellipseIn: .init(
      origin: origin.0.cgPoint,
      size: .init(width: radius, height: radius)
    ), transform: nil)
    
    context.setFillColor(fillColor)
    
    context.addPath(path)
    context.fillPath()
    
    if let strokeColor {
      context.setStrokeColor(strokeColor)
      context.setLineWidth(2)
      context.strokePath()
    }
  }
  
  func draw(_ bounds: MapBounds, fillColor: CGColor? = nil, strokeColor: CGColor? = nil, in context: CGContext) {
    let path: CGPath
    
    switch bounds {
    case .ellipse:
      let min = projection.translate(.init(x: -1 * projection.projectionSize.width / 2, y: projection.projectionSize.height / 2), to: size)
      let max = projection.translate(.init(x: projection.projectionSize.width / 2, y: -1 * projection.projectionSize.height / 2), to: size)

      path = CGPath(ellipseIn: .init(
        origin: min.cgPoint,
        size: .init(width: max.x - min.x, height: max.y - min.y)
      ), transform: nil)
      
    case .rectangle:
      let min = projection.translate(.init(x: -1 * projection.projectionSize.width / 2, y: projection.projectionSize.height / 2), to: size)
      let max = projection.translate(.init(x: projection.projectionSize.width / 2, y: -1 * projection.projectionSize.height / 2), to: size)
      
      path = CGPath(rect: .init(
        origin: min.cgPoint,
        size: .init(width: max.x - min.x, height: max.y - min.y)
      ), transform: nil)

    case .bezier(let array):
      let points = array.map { projection.translate($0, to: size) }
      let mutable = CGMutablePath()
      mutable.move(to: points[0].cgPoint)
      for point in points[1...] {
        mutable.addLine(to: point.cgPoint)
      }
      path = mutable
    }
    
    context.addPath(path)
    if let fillColor {
      context.setFillColor(fillColor)
      context.fillPath()
    }
    
    if let strokeColor {
      context.setStrokeColor(strokeColor)
      context.setLineWidth(2)
      context.strokePath()
    }

  }
}


// MARK: - Image drawing

extension GeoDrawer {
  
  func draw(_ contents: [Content], mapBackground: CGColor, mapOutline: CGColor? = nil, background: CGColor? = nil, size: CGSize, in context: CGContext) {
    
    let bounds = CGRect(origin: .zero, size: size)

#warning("TODO: Break this up into first building shapes to draw, to share this with drawing as an SVG.")

    if let background {
      context.setFillColor(background)
      context.addPath(.init(rect: bounds, transform: nil))
      context.fillPath()
    }

    // Draw the background
    draw(projection.mapBounds, fillColor: mapBackground, in: context)
    
    // Then draw contents on top
    for content in contents {
      switch content {
      case let .circle(position, radius, fill, stroke):
        drawCircle(position, radius: radius, fillColor: fill, strokeColor: stroke, in: context)
      case let .line(line, stroke):
        draw(line, strokeColor: stroke, in: context)
      case let .polygon(polygon, fill, stroke):
        draw(polygon, fillColor: fill, strokeColor: stroke, frame: bounds, in: context)
      }
    }
    
    if let mapOutline {
      // Draw a border background *on top*
      draw(projection.mapBounds, strokeColor: mapOutline, in: context)
    }
  }
  
}

extension Point {
  var cgPoint: CGPoint {
    .init(x: x, y: y)
  }
}

#endif
