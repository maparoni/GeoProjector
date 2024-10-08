//
//  GeoDrawerContent+Style.swift
//  GeoProjector
//
//  Created by Adrian Schönig on 18/9/2024.
//

import Foundation
import GeoJSONKit

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

extension GeoJSON.GeometryObject {
  var geometries: [GeoJSON.Geometry] {
    switch self {
    case .single(let geo): return [geo]
    case .multi(let geos): return geos
    case .collection(let geoObjects): return geoObjects.flatMap(\.geometries)
    }
  }
}

extension GeoDrawer.Content {
  
  public struct DefaultStyle {
    /// Fallback color to use for points, lines, and **fill** of polygons.
    public var color: GeoDrawer.Color
    
    /// Fallback color and width to use for polygons.
    public var polygonStroke: (GeoDrawer.Color, width: Double)? = nil
    
    /// Fallback stroke width for lines
    public var lineWidth: Double = 2
    
    /// Fallback radius to use for points.
    public var pointRadius: Double = 1
    
    /// Alpha to apply on every point or circle
    public var pointAlpha: Double = 1
    
    public init(color: GeoDrawer.Color, polygonStroke: (GeoDrawer.Color, width: Double)? = nil, lineWidth: Double = 2, pointRadius: Double = 1, pointAlpha: Double = 1) {
      self.color = color
      self.polygonStroke = polygonStroke
      self.lineWidth = lineWidth
      self.pointRadius = pointRadius
      self.pointAlpha = pointAlpha
    }
  }
  
  public static func content(for geoJSON: GeoJSON, style: DefaultStyle) -> [GeoDrawer.Content] {
    let elements: [(GeoJSON.Geometry, [String: AnyHashable]?)]
    switch geoJSON.object {
    case .geometry(let geo):
      elements = geo.geometries.map { ($0, nil) }
    case .feature(let feature):
      elements = feature.geometry.geometries.map { ($0, feature.properties) }
    case .featureCollection(let features):
      elements = features.flatMap { feature in
        feature.geometry.geometries.map { ($0, feature.properties) }
      }
    }
    
    return elements.map { geometry, properties in
      Self.content(for: geometry, properties: properties, style: style)
    }
  }

  public static func content(for geometry: GeoJSON.GeometryObject, properties: [String: AnyHashable]? = nil, style: DefaultStyle) -> [GeoDrawer.Content] {
    return geometry.geometries.map {
      Self.content(for: $0, properties: properties, style: style)
    }
  }
  
  
  /// Turns a GeoJSON geometry into a content draw.
  ///
  /// - Parameters:
  ///   - geometry: The geometry
  ///   - properties: Optional properties. If these follow [GeoJSON simplespec 1.1](https://github.com/mapbox/simplestyle-spec/tree/master/1.1.0), then those style is preferred over explicitly set style. Points can additionally be adjusted in size by setting `circle-radius`.
  ///   - style: Default style to use if not otherwise specified in `properties`
  /// - Returns: Drawable content.
  public static func content(for geometry: GeoJSON.Geometry, properties: [String: AnyHashable]? = nil, style: DefaultStyle) -> GeoDrawer.Content {
    switch geometry {
    case .polygon(let polygon):
      return .polygon(
        polygon,
        fill: Self.color(properties, colorKey: "fill", alphaKey: "fill-opacity") ?? style.color,
        stroke: Self.color(properties, colorKey: "stroke", alphaKey: "stroke-opacity") ?? style.polygonStroke?.0,
        strokeWidth: (properties?["stroke-width"] as? Double) ?? style.polygonStroke?.width ?? 0
      )
    
    case .lineString(let line):
      return .line(
        line,
        stroke: Self.color(properties, colorKey: "stroke", alphaKey: "stroke-opacity") ?? style.color,
        strokeWidth: properties?["stroke-width"] as? Double ?? style.lineWidth
      )
    
    case .point(let position):
      let baseFill = Self.color(properties, colorKey: "fill", alphaKey: "fill-opacity") ?? style.color
      return .circle(
        position,
        radius: properties?["circle-radius"] as? Double ?? style.pointRadius,
        fill: baseFill.copy(alpha: baseFill.alpha * style.pointAlpha) ?? baseFill,
        stroke: Self.color(properties, colorKey: "stroke", alphaKey: "stroke-opacity"),
        strokeWidth: (properties?["stroke-width"] as? Double) ?? style.lineWidth
      )
    }
  }
  
  private static func color(_ properties: [String: AnyHashable]?, colorKey: String, alphaKey: String? = nil) -> GeoDrawer.Color? {
    guard
      let properties,
      let provided = properties[colorKey] as? String
    else { return nil }
    
    let alpha = alphaKey.flatMap { properties[$0] as? Double }
    return color(code: provided, alpha: alpha)
  }
  
  private static func color(code: String, alpha: Double?) -> GeoDrawer.Color? {
    guard code.starts(with: "#") else { return nil }
    let pruned = String(code.dropFirst()).trimmingCharacters(in: .whitespaces)
    guard pruned.count == 6 else { return nil }
    
    let scanner = Scanner(string: pruned)
    var color: UInt64 = 0;
    guard scanner.scanHexInt64(&color) else { return nil }
    
    let mask = 0x000000FF
    let r = Double(Int(color >> 16) & mask)/255.0
    let g = Double(Int(color >> 8) & mask)/255.0
    let b = Double(Int(color) & mask)/255.0
    return GeoDrawer.Color(red: r, green: g, blue: b, alpha: alpha ?? 1.0)
  }
}
