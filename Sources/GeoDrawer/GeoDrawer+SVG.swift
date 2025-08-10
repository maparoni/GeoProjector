//
//  GeoDrawer+SVG.swift
//
//
//  Created by Adrian Schönig on 10/8/2025.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2025 Corporoni Pty Ltd. See LICENSE.

import Foundation
import GeoJSONKit
import GeoProjector

extension GeoDrawer {

  /// Generates an SVG string drawing the provided contents according to the configured
  /// projection, zoom and edge insets. When providing the different colours, the background of
  /// the map projection itself will be drawn, too.
  ///
  /// - Parameters:
  ///   - contents: GeoJSON contents to draw
  ///   - mapBackground: Background of the map itself
  ///   - mapOutline: Stroke colour around the map
  ///   - mapBackdrop: Background to draw outside the map / projection bounds
  /// - Returns: SVG string
  public func drawSVG(
    _ contents: [Content], mapBackground: Color? = nil, mapOutline: Color? = nil,
    mapBackdrop: Color? = nil
  ) -> String {
    let projected = contents.compactMap { project($0, coordinateSystem: .topLeft) }
    return drawSVG(
      projected, mapBackground: mapBackground, mapOutline: mapOutline, mapBackdrop: mapBackdrop)
  }

  private func drawSVG(
    _ contents: [ProjectedContent], mapBackground: Color?, mapOutline: Color?, mapBackdrop: Color?
  ) -> String {
    var svg = SVGBuilder(width: size.width, height: size.height)

    // Draw backdrop
    if let mapBackdrop {
      svg.addRectangle(
        x: 0, y: 0,
        width: size.width, height: size.height,
        fill: mapBackdrop,
        stroke: nil
      )
    }

    // Draw map background
    if let mapBackground, let projection {
      svg.addMapBounds(
        projection.mapBounds, projection: projection, drawer: self, fill: mapBackground, stroke: nil
      )
    }

    // Draw content (first pass - everything except circles)
    for content in contents {
      switch content {
      case .circle:
        break  // Draw circles on top
      case let .line(lines, stroke, strokeWidth):
        for line in lines {
          svg.addLine(line, stroke: stroke, strokeWidth: strokeWidth)
        }
      case let .polygon(polygons, fill, stroke, strokeWidth):
        for polygon in polygons {
          svg.addPolygon(polygon, fill: fill, stroke: stroke, strokeWidth: strokeWidth)
        }
      }
    }

    // Draw map outline
    if let mapOutline, let projection {
      svg.addMapBounds(
        projection.mapBounds, projection: projection, drawer: self, fill: nil, stroke: mapOutline)
    }

    // Draw content (second pass - circles on top)
    for content in contents {
      switch content {
      case let .circle(position, radius, fill, stroke, strokeWidth):
        svg.addCircle(
          position, radius: radius, fill: fill, stroke: stroke, strokeWidth: strokeWidth)
      case .line, .polygon:
        break  // Already drawn
      }
    }

    return svg.build()
  }
}

// MARK: - SVG Builder

private struct SVGBuilder {
  private let width: Double
  private let height: Double
  private var elements: [String] = []

  init(width: Double, height: Double) {
    self.width = width
    self.height = height
  }

  private func formatNumber(_ value: Double) -> String {
    return String(format: "%.1f", value)
  }

  mutating func addRectangle(
    x: Double, y: Double, width: Double, height: Double, fill: GeoDrawer.Color?,
    stroke: GeoDrawer.Color?, strokeWidth: Double = 2
  ) {
    var attributes = [
      "x=\"\(formatNumber(x))\"",
      "y=\"\(formatNumber(y))\"",
      "width=\"\(formatNumber(width))\"",
      "height=\"\(formatNumber(height))\"",
    ]

    if let fill {
      attributes.append("fill=\"\(fill.svgColor)\"")
    }

    if let stroke {
      attributes.append("stroke=\"\(stroke.svgColor)\"")
      attributes.append("stroke-width=\"\(formatNumber(strokeWidth))\"")
    }

    elements.append("<rect \(attributes.joined(separator: " ")) />")
  }

  mutating func addLine(
    _ line: GeoDrawer.ProjectedLineString, stroke: GeoDrawer.Color, strokeWidth: Double
  ) {
    let points = line.points
    guard !points.isEmpty else { return }

    var pathData = "M \(formatNumber(points[0].x)) \(formatNumber(points[0].y))"
    for point in points.dropFirst() {
      pathData += " L \(formatNumber(point.x)) \(formatNumber(point.y))"
    }

    let attributes = [
      "d=\"\(pathData)\"",
      "stroke=\"\(stroke.svgColor)\"",
      "stroke-width=\"\(formatNumber(strokeWidth))\"",
      "stroke-linecap=\"round\"",
      "stroke-linejoin=\"round\"",
      "fill=\"none\"",
    ]

    elements.append("<path \(attributes.joined(separator: " ")) />")
  }

  mutating func addPolygon(
    _ polygon: GeoDrawer.ProjectedPolygon, fill: GeoDrawer.Color?, stroke: GeoDrawer.Color?,
    strokeWidth: Double
  ) {
    let points = polygon.exterior
    guard !points.isEmpty else { return }

    var pathData = "M \(formatNumber(points[0].x)) \(formatNumber(points[0].y))"
    for point in points.dropFirst() {
      pathData += " L \(formatNumber(point.x)) \(formatNumber(point.y))"
    }
    pathData += " Z"

    // Add interior holes
    for interior in polygon.interiors {
      guard !interior.isEmpty else { continue }
      pathData += " M \(formatNumber(interior[0].x)) \(formatNumber(interior[0].y))"
      for point in interior.dropFirst() {
        pathData += " L \(formatNumber(point.x)) \(formatNumber(point.y))"
      }
      pathData += " Z"
    }

    var attributes = ["d=\"\(pathData)\""]

    if let fill {
      if polygon.invert {
        // For inverted polygons, use stroke instead of fill
        attributes.append("stroke=\"\(fill.svgColor)\"")
        attributes.append("stroke-width=\"\(formatNumber(strokeWidth))\"")
        attributes.append("stroke-linecap=\"round\"")
        attributes.append("stroke-linejoin=\"round\"")
        attributes.append("fill=\"none\"")
      } else {
        attributes.append("fill=\"\(fill.svgColor)\"")
      }
    } else {
      attributes.append("fill=\"none\"")
    }

    if let stroke, !polygon.invert {
      attributes.append("stroke=\"\(stroke.svgColor)\"")
      attributes.append("stroke-width=\"\(formatNumber(strokeWidth))\"")
      attributes.append("stroke-linecap=\"round\"")
      attributes.append("stroke-linejoin=\"round\"")
    }

    // Use fill-rule for interior holes
    if !polygon.interiors.isEmpty {
      attributes.append("fill-rule=\"evenodd\"")
    }

    elements.append("<path \(attributes.joined(separator: " ")) />")
  }

  mutating func addCircle(
    _ center: Point, radius: Double, fill: GeoDrawer.Color, stroke: GeoDrawer.Color?,
    strokeWidth: Double
  ) {
    var attributes = [
      "cx=\"\(formatNumber(center.x))\"",
      "cy=\"\(formatNumber(center.y))\"",
      "r=\"\(formatNumber(radius / 2))\"",
      "fill=\"\(fill.svgColor)\"",
    ]

    if let stroke {
      attributes.append("stroke=\"\(stroke.svgColor)\"")
      attributes.append("stroke-width=\"\(formatNumber(strokeWidth))\"")
    }

    elements.append("<circle \(attributes.joined(separator: " ")) />")
  }

  mutating func addMapBounds(
    _ bounds: MapBounds, projection: Projection, drawer: GeoDrawer, fill: GeoDrawer.Color?,
    stroke: GeoDrawer.Color?, strokeWidth: Double = 2
  ) {
    switch bounds {
    case .ellipse:
      let min = projection.translate(
        .init(x: -1 * projection.projectionSize.width / 2, y: projection.projectionSize.height / 2),
        to: drawer.size, zoomTo: drawer.zoomTo, insets: drawer.insets, coordinateSystem: .topLeft)
      let max = projection.translate(
        .init(x: projection.projectionSize.width / 2, y: -1 * projection.projectionSize.height / 2),
        to: drawer.size, zoomTo: drawer.zoomTo, insets: drawer.insets, coordinateSystem: .topLeft)

      let centerX = (min.x + max.x) / 2
      let centerY = (min.y + max.y) / 2
      let radiusX = (max.x - min.x) / 2
      let radiusY = (max.y - min.y) / 2

      var attributes = [
        "cx=\"\(formatNumber(centerX))\"",
        "cy=\"\(formatNumber(centerY))\"",
        "rx=\"\(formatNumber(radiusX))\"",
        "ry=\"\(formatNumber(radiusY))\"",
      ]

      if let fill {
        attributes.append("fill=\"\(fill.svgColor)\"")
      } else {
        attributes.append("fill=\"none\"")
      }

      if let stroke {
        attributes.append("stroke=\"\(stroke.svgColor)\"")
        attributes.append("stroke-width=\"\(formatNumber(strokeWidth))\"")
      }

      elements.append("<ellipse \(attributes.joined(separator: " ")) />")

    case .rectangle:
      let min = projection.translate(
        .init(x: -1 * projection.projectionSize.width / 2, y: projection.projectionSize.height / 2),
        to: drawer.size, zoomTo: drawer.zoomTo, insets: drawer.insets, coordinateSystem: .topLeft)
      let max = projection.translate(
        .init(x: projection.projectionSize.width / 2, y: -1 * projection.projectionSize.height / 2),
        to: drawer.size, zoomTo: drawer.zoomTo, insets: drawer.insets, coordinateSystem: .topLeft)

      addRectangle(
        x: min.x, y: min.y,
        width: max.x - min.x, height: max.y - min.y,
        fill: fill, stroke: stroke, strokeWidth: strokeWidth
      )

    case .bezier(let array):
      let points = array.map {
        projection.translate($0, to: drawer.size, zoomTo: drawer.zoomTo, insets: drawer.insets, coordinateSystem: .topLeft)
      }
      guard !points.isEmpty else { return }

      var pathData = "M \(formatNumber(points[0].x)) \(formatNumber(points[0].y))"
      for point in points.dropFirst() {
        pathData += " L \(formatNumber(point.x)) \(formatNumber(point.y))"
      }
      pathData += " Z"

      var attributes = ["d=\"\(pathData)\""]

      if let fill {
        attributes.append("fill=\"\(fill.svgColor)\"")
      } else {
        attributes.append("fill=\"none\"")
      }

      if let stroke {
        attributes.append("stroke=\"\(stroke.svgColor)\"")
        attributes.append("stroke-width=\"\(formatNumber(strokeWidth))\"")
      }

      elements.append("<path \(attributes.joined(separator: " ")) />")
    }
  }

  func build() -> String {
    let header = """
      <?xml version="1.0" encoding="UTF-8"?>
      <svg width="\(formatNumber(width))" height="\(formatNumber(height))" viewBox="0 0 \(formatNumber(width)) \(formatNumber(height))" xmlns="http://www.w3.org/2000/svg">
      """

    let footer = "</svg>"

    return header + "\n" + elements.joined(separator: "\n") + "\n" + footer
  }
}

// MARK: - Color Extension

extension GeoDrawer.Color {
  fileprivate var svgColor: String {
    #if canImport(CoreGraphics)
      // Convert CGColor to SVG color
      guard let components = components, numberOfComponents >= 3 else {
        return "black"
      }

      let red = Int(components[0] * 255)
      let green = Int(components[1] * 255)
      let blue = Int(components[2] * 255)

      if numberOfComponents >= 4 {
        let alpha = components[3]
        if alpha < 1.0 {
          return "rgba(\(red),\(green),\(blue),\(alpha))"
        }
      }

      return String(format: "#%02X%02X%02X", red, green, blue)
    #else
      // For platforms without CoreGraphics, use the Color struct
      let red = Int(self.red * 255)
      let green = Int(self.green * 255)
      let blue = Int(self.blue * 255)

      if alpha < 1.0 {
        return "rgba(\(red),\(green),\(blue),\(alpha))"
      }

      return String(format: "#%02X%02X%02X", red, green, blue)
    #endif
  }
}
