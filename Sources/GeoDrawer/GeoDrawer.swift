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

    self.converter = { position, coordinateSystem -> Point? in
      let point = Point(x: position.longitude.toRadians(), y: position.latitude.toRadians())
      return projection.point(for: point, size: size, zoomTo: zoomToRect, insets: insets, coordinateSystem: coordinateSystem)
    }
  }

  public init(size: Size, converter: @escaping (GeoJSON.Position, CoordinateSystem) -> Point) {
    self.projection = nil
    self.size = size
    self.zoomTo = nil
    self.insets = .zero
    self.converter = { converter($0, $1) }
  }

  public let projection: Projection?

  public let size: Size

  public let zoomTo: Rect?

  public let insets: EdgeInsets

#if canImport(CoreGraphics)
  /// Class-backed cache of rendered base-map rasters. Sharing a reference
  /// across drawer copies is intentional: as long as the drawer's
  /// `(projection, size, zoomTo, insets)` tuple is the same, the raster
  /// for a given `BaseMap` is the same; when any of those change, the
  /// owner (e.g. `GeoMapView`) builds a new `GeoDrawer`, dropping this cache.
  let baseMapCache = BaseMapCache()
#endif

  var invertCheck: ((GeoJSON.Polygon) -> Bool)? { projection?.invertCheck }

  let converter: (GeoJSON.Position, CoordinateSystem) -> Point?

  public func point(for position: GeoJSON.Position, coordinateSystem: CoordinateSystem) -> Point? {
    converter(position, coordinateSystem)
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
#if canImport(CoreGraphics)
    /// A raster image draped under the vector layers, sampled per output pixel
    /// via the projection's `inverse(_:)`. SVG output omits this case in v1.
    case baseMap(BaseMap)
#endif
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
#if canImport(CoreGraphics)
    /// Pass-through case. The raster is rendered later, against the active
    /// drawing context, since per-pixel inverse projection has nothing to do
    /// with per-vertex projection.
    case baseMap(BaseMap)
#endif
  }
}

extension GeoDrawer {
  func project(_ line: GeoJSON.LineString, coordinateSystem: CoordinateSystem) -> [ProjectedLineString] {
    let lines = convertLine(line.positions, coordinateSystem: coordinateSystem)
    return lines.map(ProjectedLineString.init(points:))
  }

  func project(_ polygon: GeoJSON.Polygon, coordinateSystem: CoordinateSystem) -> [ProjectedPolygon] {
    let invert: Bool = invertCheck?(polygon) ?? false
    let interiors = polygon.interiors.flatMap { convertLine($0.positions, coordinateSystem: coordinateSystem) }
    return convertPolygon(polygon.exterior.positions, coordinateSystem: coordinateSystem).map { points in
      return .init(exterior: points, interiors: interiors, invert: invert)
    }
  }

  func project(_ content: Content, coordinateSystem: CoordinateSystem) -> ProjectedContent? {
    switch content {
    case let .line(line, stroke, strokeWidth):
      return .line(project(line, coordinateSystem: coordinateSystem), stroke: stroke, strokeWidth: strokeWidth)
    case let .polygon(polygon, fill, stroke, strokeWidth):
      return .polygon(project(polygon, coordinateSystem: coordinateSystem), fill: fill, stroke: stroke, strokeWidth: strokeWidth)
    case let .circle(center, radius, fill, stroke, strokeWidth):
      guard let point = converter(center, coordinateSystem) else { return nil }
      return .circle(point, radius: radius, fill: fill, stroke: stroke, strokeWidth: strokeWidth)
#if canImport(CoreGraphics)
    case let .baseMap(baseMap):
      return .baseMap(baseMap)
#endif
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

  func projectInParallel(_ contents: [Content], coordinateSystem: CoordinateSystem) async throws -> [ProjectedContent] {
    try await withThrowingTaskGroup(of: [OffsettedElement<ProjectedContent>].self) { group in
      let chunks = Array(contents.enumerated()).chunks(ofCount: 25)
      for chunk in chunks {
        let added = group.addTaskUnlessCancelled {
          await Task {
            return chunk.compactMap { input in
              guard !Task.isCancelled, let projected = project(input.element, coordinateSystem: coordinateSystem) else { return nil }
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

  /// Splits a polyline of GeoJSON positions into one or more on-screen
  /// polylines, each of which stays inside the projection's `mapBounds`.
  /// Sub-paths that cross the projection edge are anchored at the boundary
  /// crossing point.
  func convertLine(_ positions: [GeoJSON.Position], coordinateSystem: CoordinateSystem) -> [[Point]] {
    Self.convertLine(positions, projection: projection, size: size, zoomTo: zoomTo, insets: insets, coordinateSystem: coordinateSystem, converter: converter, close: false)
  }

  /// Same as ``convertLine(_:coordinateSystem:)`` but each split piece is
  /// closed back to its first point along the projection boundary, so the
  /// resulting rings are suitable for polygon fill.
  func convertPolygon(_ positions: [GeoJSON.Position], coordinateSystem: CoordinateSystem) -> [[Point]] {
    Self.convertLine(positions, projection: projection, size: size, zoomTo: zoomTo, insets: insets, coordinateSystem: coordinateSystem, converter: converter, close: true)
  }

  static func projectLine(_ positions: [GeoJSON.Position], projection: Projection) -> [(Point, Point?)] {
    // 1. Turn degrees into radians once.
    let unprojected = positions.map { Point(x: $0.longitude.toRadians(), y: $0.latitude.toRadians()) }
    guard !unprojected.isEmpty else { return [] }

    // 2. Project each input vertex once. Endpoints between consecutive pairs
    //    are shared, so previously this list re-projected every interior
    //    vertex twice.
    let projectedVertices: [Point?] = unprojected.map { projection.project($0) }

    // 3. Walk consecutive pairs, interpolating between them. Curved
    //    projections need the interpolation, otherwise the straight-line
    //    drawing between projected endpoints loses fidelity.
    var output: [(Point, Point?)] = []
    output.reserveCapacity(unprojected.count * 2)
    let maxDiff: Double = 0.0025
    let diffSquared = maxDiff * maxDiff
    for i in 0..<(unprojected.count - 1) {
      let a = unprojected[i]
      let b = unprojected[i + 1]
      let aProj = projectedVertices[i]
      let bProj = projectedVertices[i + 1]
      output.append((a, aProj))
      Interpolator.interpolateInto(
        from: a, aProj: aProj,
        to: b, bProj: bProj,
        diffSquared: diffSquared,
        projector: projection.project(_:),
        output: &output
      )
    }
    output.append((unprojected.last!, projectedVertices.last!))
    return output
  }

  private static func convertLine(_ positions: [GeoJSON.Position], projection: Projection?, size: Size, zoomTo: Rect?, insets: EdgeInsets, coordinateSystem: CoordinateSystem, converter: (GeoJSON.Position, CoordinateSystem) -> Point?, close: Bool) -> [[Point]] {

    guard let projection else {
      return [positions.compactMap {
        converter($0, coordinateSystem)
      }]
    }

    let projected = Self.projectLine(positions, projection: projection)

    let pieces: [[Point]]
    if close {
      pieces = boundarySplitClosed(projected, mapBounds: projection.mapBounds, projectionSize: projection.projectionSize)
    } else {
      pieces = boundarySplit(projected, mapBounds: projection.mapBounds, projectionSize: projection.projectionSize)
    }

    // Translate each piece (still in projected radians) to screen coordinates.
    return pieces.map { piece in
      piece.map { p in
        let translated = projection.translate(p, to: size, zoomTo: zoomTo, insets: insets, coordinateSystem: coordinateSystem)
        assert(translated.isGood)
        return translated
      }
    }
  }
}

fileprivate extension Point {
  var isGood: Bool {
    !x.isNaN && !y.isNaN && !x.isInfinite && !y.isInfinite
  }
}
