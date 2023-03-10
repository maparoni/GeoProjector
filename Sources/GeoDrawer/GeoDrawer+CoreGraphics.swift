//
//  GeoDrawer+UIKit.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2022 Corporoni Pty Ltd
//
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Lesser General Public
// License as published by the Free Software Foundation; either
// version 2.1 of the License, or (at your option) any later version.
//
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public
// License along with this library; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301
// USA

#if canImport(CoreGraphics)
import CoreGraphics

import GeoJSONKit
import GeoJSONKitTurf
import GeoProjector

// MARK: - Context drawing

extension GeoDrawer {
  
  /// Draws the line into the current context
  public func draw(_ line: GeoJSON.LineString, strokeColor: CGColor, in context: CGContext) {
    for points in convertLine(line.positions) {
      
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
  
  public func draw(_ polygon: GeoJSON.Polygon, fillColor: CGColor? = nil, strokeColor: CGColor? = nil, strokeWidth: Double = 2, frame: CGRect, in context: CGContext) {
    // In some projections such as Azimuthal, we might need to colour a cut-out
    // rather than the projected polygon.
    let invert: Bool = invertCheck?(polygon) ?? false
    
    for points in convertLine(polygon.exterior.positions) {
      
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
          for interiorPoints in convertLine(interior.positions) {
            rect.move(to: interiorPoints[0].cgPoint)
            for point in interiorPoints[1...] {
              rect.addLine(to: point.cgPoint)
            }
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
  }
  
  func drawCircle(_ position: GeoJSON.Position, radius: CGFloat, fillColor: CGColor, strokeColor: CGColor? = nil, strokeWidth: Double = 2, in context: CGContext) {
    guard let origin = converter(position) else { return }
    
    context.addArc(center: origin.0.cgPoint, radius: radius / 2, startAngle: 0, endAngle: CGFloat(Double.pi * 2), clockwise: true)

    context.setFillColor(fillColor)
    context.fillPath()

    if let strokeColor {
      context.addArc(center: origin.0.cgPoint, radius: radius / 2, startAngle: 0, endAngle: CGFloat(Double.pi * 2), clockwise: true)
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
      case let .line(line, stroke):
        draw(line, strokeColor: stroke, in: context)
      case let .polygon(polygon, fill, stroke, strokeWidth):
        draw(polygon, fillColor: fill, strokeColor: stroke, strokeWidth: strokeWidth, frame: bounds, in: context)
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
