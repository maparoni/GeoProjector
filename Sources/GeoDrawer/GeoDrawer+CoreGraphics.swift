//
//  GeoDrawer+UIKit.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2022 Corporoni Pty Ltd. See LICENSE.

#if canImport(CoreGraphics)
import CoreGraphics

import GeoJSONKit
import GeoJSONKitTurf
import GeoProjector

// MARK: - Context drawing

extension GeoDrawer {
  
  /// Draws the line into the current context
  public func draw(_ line: GeoJSON.LineString, strokeColor: CGColor, strokeWidth: Double = 2, in context: CGContext) {
    for line in project(line) {
      draw(line, strokeColor: strokeColor, strokeWidth: strokeWidth, in: context)
    }
  }
  
  public func draw(_ polygon: GeoJSON.Polygon, fillColor: CGColor? = nil, strokeColor: CGColor? = nil, strokeWidth: Double = 2, frame: CGRect, in context: CGContext) {
    for polygon in project(polygon) {
      draw(polygon, fillColor: fillColor, strokeColor: strokeColor, strokeWidth: strokeWidth, frame: frame, in: context)
    }
  }
  
  func drawCircle(_ position: GeoJSON.Position, radius: CGFloat, fillColor: CGColor, strokeColor: CGColor? = nil, strokeWidth: Double = 2, in context: CGContext) {
    guard let center = converter(position)?.0 else { return }
    drawCircle(center, radius: radius, fillColor: fillColor, strokeColor: strokeColor, strokeWidth: strokeWidth, in: context)
  }
  
  func draw(_ projectedLine: ProjectedLineString, strokeColor: CGColor, strokeWidth: Double, in context: CGContext) {
    let points = projectedLine.points
    let path = CGMutablePath()
    path.move(to: points[0].cgPoint)
    for point in points[1...] {
      path.addLine(to: point.cgPoint)
    }
    
    context.setStrokeColor(strokeColor)

    context.setLineWidth(strokeWidth)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    
    context.addPath(path)
    context.strokePath()
  }
  
  func draw(_ polygon: ProjectedPolygon, fillColor: CGColor?, strokeColor: CGColor?, strokeWidth: Double, frame: CGRect, in context: CGContext) {
    let invert = polygon.invert
    
    let points = polygon.exterior
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
      
      for interiorPoints in polygon.interiors {
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
        context.setLineWidth(strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.strokePath()

      } else {
        context.setFillColor(fillColor)
        context.setLineWidth(0)
        context.fillPath()
      }
      
    }
    
    if let strokeColor {
      context.addPath(path)
      context.setStrokeColor(strokeColor)
      context.setLineWidth(strokeWidth)
      context.setLineCap(.round)
      context.setLineJoin(.round)
      context.strokePath()
    }
  }

  
  func drawCircle(_ center: Point, radius: CGFloat, fillColor: CGColor, strokeColor: CGColor? = nil, strokeWidth: Double = 2, in context: CGContext) {
    context.addArc(center: center.cgPoint, radius: radius / 2, startAngle: 0, endAngle: CGFloat(Double.pi * 2), clockwise: true)

    context.setFillColor(fillColor)
    context.fillPath()

    if let strokeColor {
      context.addArc(center: center.cgPoint, radius: radius / 2, startAngle: 0, endAngle: CGFloat(Double.pi * 2), clockwise: true)
      context.setStrokeColor(strokeColor)
      context.setLineWidth(strokeWidth)
      context.strokePath()
    }

  }
  
  func draw(_ bounds: MapBounds, fillColor: CGColor? = nil, strokeColor: CGColor? = nil, in context: CGContext) {
    guard let projection else {
      return assertionFailure("Drawing map bounds not supported for provided converter.")
    }
    
    let path: CGPath
    
    switch bounds {
    case .ellipse:
      let min = projection.translate(.init(x: -1 * projection.projectionSize.width / 2, y: projection.projectionSize.height / 2), to: size, zoomTo: zoomTo, insets: insets)
      let max = projection.translate(.init(x: projection.projectionSize.width / 2, y: -1 * projection.projectionSize.height / 2), to: size, zoomTo: zoomTo, insets: insets)

      path = CGPath(ellipseIn: .init(
        origin: min.cgPoint,
        size: .init(width: max.x - min.x, height: max.y - min.y)
      ), transform: nil)
      
    case .rectangle:
      let min = projection.translate(.init(x: -1 * projection.projectionSize.width / 2, y: projection.projectionSize.height / 2), to: size, zoomTo: zoomTo, insets: insets)
      let max = projection.translate(.init(x: projection.projectionSize.width / 2, y: -1 * projection.projectionSize.height / 2), to: size, zoomTo: zoomTo, insets: insets)
      
      path = CGPath(rect: .init(
        origin: min.cgPoint,
        size: .init(width: max.x - min.x, height: max.y - min.y)
      ), transform: nil)

    case .bezier(let array):
      let points = array.map { projection.translate($0, to: size, zoomTo: zoomTo, insets: insets) }
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
  
  public func draw(_ contents: [Content], mapBackground: CGColor? = nil, mapOutline: CGColor? = nil, mapBackdrop: CGColor? = nil, in context: CGContext) {
    let projected = contents.compactMap(project)
    draw(projected, mapBackground: mapBackground, mapOutline: mapOutline, mapBackdrop: mapBackdrop, in: context)
  }
  
  func draw(_ contents: [ProjectedContent], mapBackground: CGColor?, mapOutline: CGColor?, mapBackdrop: CGColor?, in context: CGContext) {
    let size = CGSize(width: self.size.width, height: self.size.height)
    let bounds = CGRect(origin: .zero, size: size)
    
    // LATER: Break this up into first building shapes to draw, to share this with drawing as an SVG.
    
    if let mapBackdrop {
      context.setFillColor(mapBackdrop)
      context.addPath(.init(rect: bounds, transform: nil))
      context.fillPath()
    }
    
    if let mapBackground, let projection {
      draw(projection.mapBounds, fillColor: mapBackground, in: context)
    }
    
    for content in contents {
      switch content {
      case .circle:
        break // this will go above the outline, as they might go outside projection
      case let .line(lines, stroke, strokeWidth):
        for line in lines {
          draw(line, strokeColor: stroke, strokeWidth: strokeWidth, in: context)
        }
      case let .polygon(polygons, fill, stroke, strokeWidth):
        for polygon in polygons {
          draw(polygon, fillColor: fill, strokeColor: stroke, strokeWidth: strokeWidth, frame: bounds, in: context)
        }
      }
    }
    
    if let mapOutline, let projection {
      // Draw a border background *on top*
      draw(projection.mapBounds, strokeColor: mapOutline, in: context)
    }
    
    for content in contents {
      switch content {
      case let .circle(position, radius, fill, stroke, strokeWidth):
        drawCircle(position, radius: radius, fillColor: fill, strokeColor: stroke, strokeWidth: strokeWidth, in: context)
      case .line, .polygon:
        break // under the outline, as they follow projection
      }
    }

  }
  
}

extension Point {
  var cgPoint: CGPoint {
    .init(x: x, y: y)
  }
}

#endif
