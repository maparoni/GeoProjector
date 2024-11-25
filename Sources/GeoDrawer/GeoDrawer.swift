//
//  GeoDrawer.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2022 Corporoni Pty Ltd. See LICENSE.

#if canImport(CoreGraphics)
import CoreGraphics
#endif

import GeoJSONKit
import Algorithms

@_exported import GeoProjector

/// GeoDrawer let's you draw GeoJSON content using different map projections
///
/// Depending on the platform, it can be used to generate a `UIImage` from a GeoJSON or draw it into a `CGContext`.
///
/// **Generating images**
///
/// ```
/// let myContext: CGContext = ...
///
/// // The GeoJSON content, e.g., the provided GeoJSON of the continents
/// let myContent: GeoJSON = try GeoDrawer.Content.world()
///
/// let drawer = GeoDrawer(
///   size: .init(width: 400, height: 200),
///   projection: Projections.EqualEarth()
/// )
///
/// let image = drawer.drawImage(myContent
///   mapBackground: .systemGreen,
///   mapOutline: .black,
///   mapBackdrop: .white
/// )
/// ```
///
/// **Drawing into a CoreGraphics Context**
///
/// ```
/// let myContext: CGContext = ...
///
/// // The GeoJSON content, e.g., the provided GeoJSON of the continents
/// let myContent: GeoJSON = try GeoDrawer.Content.world()
///
/// let drawer = GeoDrawer(
///   size: .init(width: 400, height: 200),
///   projection: Projections.EqualEarth()
/// )
///
/// drawer.draw(myContent, in: myContext)
/// ```
public struct GeoDrawer {
  
  public init(size: Size, projection: Projection, zoomTo: GeoJSON.BoundingBox? = nil, zoomOutFactor: Double = 1, insets: EdgeInsets = .zero) {
    self.projection = projection
    self.size = size
    self.insets = insets
    
    let zoomToRect: Rect? = zoomTo.flatMap { box in
      let positions = [
        GeoJSON.Position(latitude: box.northEasterlyLatitude, longitude: box.southWesterlyLongitude),
        GeoJSON.Position(latitude: box.northEasterlyLatitude, longitude: box.northEasterlyLongitude),
        GeoJSON.Position(latitude: box.southWesterlyLatitude, longitude: box.northEasterlyLongitude),
        GeoJSON.Position(latitude: box.southWesterlyLatitude, longitude: box.southWesterlyLongitude),
      ]
      
      let lines = [
        GeoJSON.LineString(positions: [positions[0], positions[1]]),
        GeoJSON.LineString(positions: [positions[1], positions[2]]),
        GeoJSON.LineString(positions: [positions[2], positions[3]]),
        GeoJSON.LineString(positions: [positions[3], positions[0]]),
      ]
      
      let bounds: Rect? = lines.reduce(nil) { acc, next in
        let points = Self.projectLine(next.positions, projection: projection).compactMap(\.1)
        if var acc {
          for point in points {
            acc.absorb(point)
          }
          return acc
        } else if let first = points.first {
          var rect = Rect(origin: first, size: .zero)
          for point in points.dropFirst() {
            rect.absorb(point)
          }
          return rect
        } else {
          return nil
        }
      }
      guard let bounds else { return nil }
      
      // Zoom out a whole bit to give some global context
      let scaled = bounds.scaled(x: zoomOutFactor, y: zoomOutFactor)
      
      // But don't zoom out further than 75% of the projection size
      // (75% is a bit arbitrary, but it looks weird if you zoom in
      // just a little bit; better to just show not zoomed-in then.)
      if scaled.size.width < projection.projectionSize.width * 0.75, scaled.size.height < projection.projectionSize.height * 0.75 {
        return scaled
      } else {
        return nil
      }
    }
    
    self.zoomTo = zoomToRect
    
    self.converter = { position -> (Point, Bool)? in
      let point = Point(x: position.longitude.toRadians(), y: position.latitude.toRadians())
      return projection.point(for: point, size: size, zoomTo: zoomToRect, insets: insets)
    }
  }
  
  public init(size: Size, converter: @escaping (GeoJSON.Position) -> Point) {
    self.projection = nil
    self.size = size
    self.zoomTo = nil
    self.insets = .zero
    self.converter = { (converter($0), false) }
  }
  
  public let projection: Projection?
  
  public let size: Size
  
  let zoomTo: Rect?

  public let insets: EdgeInsets

  var invertCheck: ((GeoJSON.Polygon) -> Bool)? { projection?.invertCheck }
  
  let converter: (GeoJSON.Position) -> (Point, Bool)?
  
  public func point(for position: GeoJSON.Position) -> Point? {
    converter(position)?.0
  }
}

// MARK: - Content

extension GeoDrawer {
  
#if canImport(CoreGraphics)
  public typealias Color = CGColor
#else
  public struct Color: Hashable {
    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
      self.red = red
      self.green = green
      self.blue = blue
      self.alpha = alpha
    }
    
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double
    
    public func copy(alpha: Double) -> Self? {
      guard alpha != self.alpha else { return nil }
      var updated = self
      updated.alpha = alpha
      return updated
    }
  }
#endif

  public enum Content: Hashable {
    case line(GeoJSON.LineString, stroke: Color, strokeWidth: Double = 2)
    case polygon(GeoJSON.Polygon, fill: Color, stroke: Color? = nil, strokeWidth: Double = 2)
    case circle(GeoJSON.Position, radius: Double, fill: Color, stroke: Color? = nil, strokeWidth: Double = 2)
  }
  
}

// MARK: - Projected content

extension GeoDrawer {
  
  struct ProjectedLineString: Hashable {
    let points: [Point]
  }
  
  struct ProjectedPolygon: Hashable {
    let exterior: [Point]
    let interiors: [[Point]]
    
    // In some projections such as Azimuthal, we might need to colour a cut-out
    // rather than the projected polygon.
    let invert: Bool
  }
  
  enum ProjectedContent: Hashable {
    case line([ProjectedLineString], stroke: Color, strokeWidth: Double)
    case polygon([ProjectedPolygon], fill: Color, stroke: Color?, strokeWidth: Double)
    case circle(Point, radius: Double, fill: Color, stroke: Color?, strokeWidth: Double)
  }
}

extension GeoDrawer {
  func project(_ line: GeoJSON.LineString) -> [ProjectedLineString] {
    let lines = convertLine(line.positions)
    return lines.map(ProjectedLineString.init(points:))
  }
  
  func project(_ polygon: GeoJSON.Polygon) -> [ProjectedPolygon] {
    let invert: Bool = invertCheck?(polygon) ?? false
    let interiors = polygon.interiors.flatMap { convertLine($0.positions) }
    return convertLine(polygon.exterior.positions).map { points in
      return .init(exterior: points, interiors: interiors, invert: invert)
    }
  }
  
  func project(_ content: Content) -> ProjectedContent? {
    switch content {
    case let .line(line, stroke, strokeWidth):
      return .line(project(line), stroke: stroke, strokeWidth: strokeWidth)
    case let .polygon(polygon, fill, stroke, strokeWidth):
      return .polygon(project(polygon), fill: fill, stroke: stroke, strokeWidth: strokeWidth)
    case let .circle(center, radius, fill, stroke, strokeWidth):
      guard let point = converter(center)?.0 else { return nil }
      return .circle(point, radius: radius, fill: fill, stroke: stroke, strokeWidth: strokeWidth)
    }
  }
  
  struct OffsettedElement<Element: Equatable>: Comparable, Equatable {
    let offset: Int
    let element: Element
    
    static func == (lhs: OffsettedElement, rhs: OffsettedElement) -> Bool {
      lhs.offset == rhs.offset && lhs.element == rhs.element
    }
    
    static func < (lhs: OffsettedElement, rhs: OffsettedElement) -> Bool {
      lhs.offset < rhs.offset
    }
  }
  
  func projectInParallel(_ contents: [Content]) async throws -> [ProjectedContent] {
    try await withThrowingTaskGroup(of: [OffsettedElement<ProjectedContent>].self) { group in
      let chunks = Array(contents.enumerated()).chunks(ofCount: 25)
      for chunk in chunks {
        let added = group.addTaskUnlessCancelled {
          await Task {
            return chunk.compactMap { input in
              guard !Task.isCancelled, let projected = project(input.element) else { return nil }
              return OffsettedElement(offset: input.offset, element: projected)
            }
          }.value
        }
        if !added {
          throw CancellationError()
        }
      }
      
      let unsorted = try await group.reduce(into: []) { $0.append(contentsOf: $1) }
      return unsorted.sorted(by: <).map(\.element)
    }
  }
}

// MARK: - Line helper

extension GeoDrawer {
  
  enum Grouping: Equatable {
    case wrapped
    case notWrapped
    case notProjected
  }
  
  /// - Returns: Typically returns a single element, but can return multiple, if the line wraps around
  func convertLine(_ positions: [GeoJSON.Position]) -> [[Point]] {
    Self.convertLine(positions, projection: projection, size: size, zoomTo: zoomTo, insets: insets, converter: converter)
  }
  
  private static func projectLine(_ positions: [GeoJSON.Position], projection: Projection) -> [(Point, Point?)] {
    
    // 1. Turn degrees into radians
    let unprojected = positions.map { Point(x: $0.longitude.toRadians(), y: $0.latitude.toRadians()) }
    
    // 2. Project pairs and interpolate between them, which is necessary if
    //    we can't just draw a line between the two projected points as the
    //    projection itself should be curved or it might not cover both
    //    endpoints.
    let projected = zip(unprojected.dropLast(), unprojected.dropFirst())
      .reduce(into: [(Point, Point?)]()) { acc, next in
        acc.append((next.0, projection.project(next.0)))
        acc.append(contentsOf: Interpolator.interpolate(from: next.0, to: next.1, maxDiff: 0.0025, projector: projection.project(_:)))
        acc.append((next.1, projection.project(next.1)))
      }
    
    return projected
  }
  
  /// - Returns: Typically returns a single element, but can return multiple, if the line wraps around
  private static func convertLine(_ positions: [GeoJSON.Position], projection: Projection?, size: Size, zoomTo: Rect?, insets: EdgeInsets, converter: (GeoJSON.Position) -> (Point, Bool)?) -> [[Point]] {
    
    guard let projection else {
      return [positions.compactMap {
        converter($0)?.0
      }]
    }
    
    let projected = Self.projectLine(positions, projection: projection)
    
    // 3. Now translate the projected points into point coordinates to draw
    let converted = projected
      .map { (unproj, projected) -> (Point, Point?, Grouping) in
        assert(unproj.isGood)
        if let projected {
          let proj = projection.translate(projected, to: size, zoomTo: zoomTo, insets: insets)
          assert(proj.isGood)
          return (unproj, proj, projection.willWrap(unproj) ? .wrapped : .notWrapped)
        } else {
          return (unproj, nil, .notProjected)
        }
      }

    // 4. Lastly split them up according to whether they were wrapped around
    //    the edge of the projection to the other side (or hidden).
    var wraps: [(Point, Point)] = []
    var unwraps: [(Point, Point)] = []
    var wip: ([(Point, Point)], Grouping) = ([], .notProjected)
    for (unproj, proj, group) in converted {
      if group == wip.1 {
        if let proj {
          wip.0.append((unproj, proj))
        }
        
      } else {
        // We got to a new group
        if !wip.0.isEmpty {
          switch wip.1 {
          case .notWrapped:
            unwraps = wip.0
          case .wrapped:
            wraps = wip.0
          case .notProjected:
            break
          }
        }
          
        var new: [(Point, Point)]
        switch group {
        case .notWrapped:
          new = unwraps
        case .wrapped:
          new = wraps
        case .notProjected:
          new = []
        }

        if let last = new.last?.0 {
          // When "resuming" the same group, connect with the previous points
          // in the group, but interpolate again.
          let interpolated = Interpolator.interpolate(from: last, to: unproj, maxDiff: 0.0025, projector: projection.project(_:))
          let translated = interpolated.map {
            let translated = projection.translate($0.1, to: size, zoomTo: zoomTo, insets: insets)
            assert(translated.isGood)
            return ($0.0, translated)
          }
          new.append(contentsOf: translated)
        }
        if let proj {
          new.append((unproj, proj))
        }
        wip = (new, group)
      }
    }
    if !wip.0.isEmpty {
      switch wip.1 {
      case .notWrapped:
        unwraps = wip.0
      case .wrapped:
        wraps = wip.0
      case .notProjected:
        break
      }
    }
    return [wraps.map(\.1), unwraps.map(\.1)].filter { !$0.isEmpty }
  }
}

fileprivate extension Point {
  var isGood: Bool {
    !x.isNaN && !y.isNaN && !x.isInfinite && !y.isInfinite
  }
}
