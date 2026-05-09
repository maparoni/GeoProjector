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
  
  private var coordinateSystem: CoordinateSystem {
    #if os(macOS)
    .bottomLeft
    #else
    .topLeft
    #endif
  }
  
  /// Draws the line into the current context
  public func draw(_ line: GeoJSON.LineString, strokeColor: CGColor, strokeWidth: Double = 2, in context: CGContext) {
    for line in project(line, coordinateSystem: coordinateSystem) {
      draw(line, strokeColor: strokeColor, strokeWidth: strokeWidth, in: context)
    }
  }
  
  public func draw(_ polygon: GeoJSON.Polygon, fillColor: CGColor? = nil, strokeColor: CGColor? = nil, strokeWidth: Double = 2, frame: CGRect, in context: CGContext) {
    for polygon in project(polygon, coordinateSystem: coordinateSystem) {
      draw(polygon, fillColor: fillColor, strokeColor: strokeColor, strokeWidth: strokeWidth, frame: frame, in: context)
    }
  }
  
  func drawCircle(_ position: GeoJSON.Position, radius: CGFloat, fillColor: CGColor, strokeColor: CGColor? = nil, strokeWidth: Double = 2, in context: CGContext) {
    guard let center = converter(position, coordinateSystem) else { return }
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
    guard let path = mapBoundsPath(bounds) else {
      return assertionFailure("Drawing map bounds not supported for provided converter.")
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

  /// Builds the screen-space path of the projection's `mapBounds`. Returns
  /// `nil` if the drawer was constructed without a projection. Factored out
  /// so both `draw(_ bounds:...)` and the base-map raster step can use it
  /// for clipping.
  func mapBoundsPath(_ bounds: MapBounds) -> CGPath? {
    guard let projection else { return nil }

    switch bounds {
    case .ellipse:
      let min = projection.translate(.init(x: -1 * projection.projectionSize.width / 2, y: projection.projectionSize.height / 2), to: size, zoomTo: zoomTo, insets: insets, coordinateSystem: coordinateSystem)
      let max = projection.translate(.init(x: projection.projectionSize.width / 2, y: -1 * projection.projectionSize.height / 2), to: size, zoomTo: zoomTo, insets: insets, coordinateSystem: coordinateSystem)
      return CGPath(ellipseIn: .init(
        origin: min.cgPoint,
        size: .init(width: max.x - min.x, height: max.y - min.y)
      ), transform: nil)

    case .rectangle:
      let min = projection.translate(.init(x: -1 * projection.projectionSize.width / 2, y: projection.projectionSize.height / 2), to: size, zoomTo: zoomTo, insets: insets, coordinateSystem: coordinateSystem)
      let max = projection.translate(.init(x: projection.projectionSize.width / 2, y: -1 * projection.projectionSize.height / 2), to: size, zoomTo: zoomTo, insets: insets, coordinateSystem: coordinateSystem)
      return CGPath(rect: .init(
        origin: min.cgPoint,
        size: .init(width: max.x - min.x, height: max.y - min.y)
      ), transform: nil)

    case .bezier(let array):
      let points = array.map { projection.translate($0, to: size, zoomTo: zoomTo, insets: insets, coordinateSystem: coordinateSystem) }
      let mutable = CGMutablePath()
      mutable.move(to: points[0].cgPoint)
      for point in points[1...] {
        mutable.addLine(to: point.cgPoint)
      }
      mutable.closeSubpath()
      return mutable
    }
  }
}


// MARK: - Image drawing

extension GeoDrawer {
  
  public func draw(_ contents: [Content], mapBackground: CGColor? = nil, mapOutline: CGColor? = nil, mapBackdrop: CGColor? = nil, in context: CGContext) {
    let projected = contents.compactMap { project($0, coordinateSystem: coordinateSystem) }
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

    // Base maps go under the vector layers but above the map background fill,
    // clipped to the projection's image so ellipse/bezier outlines don't leak
    // raster pixels past the projection's edge.
    if let projection {
      let clipPath = mapBoundsPath(projection.mapBounds)
      var clipped = false
      for content in contents {
        switch content {
        case .baseMap(let baseMap):
          guard let raster = renderedBaseMap(baseMap, coordinateSystem: coordinateSystem) else { continue }
          if !clipped, let clipPath {
            context.saveGState()
            context.addPath(clipPath)
            context.clip()
            clipped = true
          }
          context.saveGState()
          // `CGContext.draw(image:in:)` ignores the user-space y-axis
          // direction and always places image row 0 at the rect's maxY in
          // its own (y-up) frame. On UIKit the surrounding CTM is flipped,
          // so without a counter-flip the raster lands upside-down. AppKit
          // contexts are unflipped, so leave the CTM alone there.
          if coordinateSystem == .topLeft {
            context.translateBy(x: 0, y: bounds.maxY)
            context.scaleBy(x: 1, y: -1)
          }
          context.draw(raster, in: bounds)
          context.restoreGState()
        case .circle, .line, .polygon:
          break
        }
      }
      if clipped {
        context.restoreGState()
      }
    }

    for content in contents {
      switch content {
      case .circle, .baseMap:
        break // baseMap drawn above; circles go above the outline
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
      case .line, .polygon, .baseMap:
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
