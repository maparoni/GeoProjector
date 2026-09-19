//
//  GeoDrawer+CGProjected.swift
//
//
//  Perf: build CGPaths during parallel projection so `draw(_:)` is
//  path-application only. GeoMapView used to reconstruct
//  `CGMutablePath` from raw `Point` arrays on every `setNeedsDisplay`,
//  even for trivial redraws (mapBackground toggle, tile arrival
//  re-render, drag frame). Doing the path-building loop once in the
//  projection task alongside the projection math means the render
//  path becomes `context.addPath(path)` — no allocation, no per-vertex
//  iteration per frame.
//
//  Also switches polygon-interior handling from a `CGContext` clip
//  state to an even-odd fill on a compound path — same visual result,
//  no clip leak between polygons with and without interiors.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

#if canImport(CoreGraphics)
import CoreGraphics
import Foundation
import Algorithms

import GeoProjector

// MARK: - CG-specific projected types

extension GeoDrawer {

  struct CGProjectedLine {
    let path: CGPath
  }

  struct CGProjectedPolygon {
    let path: CGPath
    let invert: Bool
  }

  enum CGProjectedContent {
    case line([CGProjectedLine], stroke: CGColor, strokeWidth: Double)
    case polygon([CGProjectedPolygon], fill: CGColor, stroke: CGColor?, strokeWidth: Double)
    case circle(Point, radius: Double, fill: CGColor, stroke: CGColor?, strokeWidth: Double)
    case baseMap(BaseMap)
    case tiledBaseMap(TiledBaseMap)
  }
}

// MARK: - Path construction

extension GeoDrawer {

  private static func cgPath(for points: [Point], close: Bool) -> CGPath {
    let path = CGMutablePath()
    guard !points.isEmpty else { return path }
    path.move(to: points[0].cgPoint)
    for point in points[1...] {
      path.addLine(to: point.cgPoint)
    }
    if close { path.closeSubpath() }
    return path
  }

  /// Exterior + interior rings combined into a single compound path. The
  /// caller fills with `.evenOdd` to punch out the interiors — no
  /// `context.clip` state to leak into subsequent draws.
  private static func cgPath(exterior: [Point], interiors: [[Point]]) -> CGPath {
    let path = CGMutablePath()
    guard !exterior.isEmpty else { return path }
    path.move(to: exterior[0].cgPoint)
    for point in exterior[1...] {
      path.addLine(to: point.cgPoint)
    }
    path.closeSubpath()
    for interior in interiors {
      guard !interior.isEmpty else { continue }
      path.move(to: interior[0].cgPoint)
      for point in interior[1...] {
        path.addLine(to: point.cgPoint)
      }
      path.closeSubpath()
    }
    return path
  }
}

// MARK: - Parallel projection

extension GeoDrawer {

  func projectCG(_ content: Content, coordinateSystem: CoordinateSystem) -> CGProjectedContent? {
    switch content {
    case let .line(line, stroke, strokeWidth):
      let lines = project(line, coordinateSystem: coordinateSystem)
      let cgLines = lines.compactMap { projected -> CGProjectedLine? in
        guard !projected.points.isEmpty else { return nil }
        return CGProjectedLine(path: Self.cgPath(for: projected.points, close: false))
      }
      return .line(cgLines, stroke: stroke, strokeWidth: strokeWidth)

    case let .polygon(polygon, fill, stroke, strokeWidth):
      let polygons = project(polygon, coordinateSystem: coordinateSystem)
      let cgPolygons = polygons.map { projected in
        CGProjectedPolygon(
          path: Self.cgPath(exterior: projected.exterior, interiors: projected.interiors),
          invert: projected.invert
        )
      }
      return .polygon(cgPolygons, fill: fill, stroke: stroke, strokeWidth: strokeWidth)

    case let .circle(center, radius, fill, stroke, strokeWidth):
      guard let point = converter(center, coordinateSystem) else { return nil }
      return .circle(point, radius: radius, fill: fill, stroke: stroke, strokeWidth: strokeWidth)

    case let .baseMap(baseMap):
      return .baseMap(baseMap)

    case let .tiledBaseMap(tiled):
      return .tiledBaseMap(tiled)
    }
  }

  /// Same shape as `projectInParallel` but returns pre-built-CGPath
  /// content, and uses smaller chunks (5 instead of 25) so the workload
  /// distributes more evenly across cores — a single 25-item chunk on
  /// one core was dominating end-to-end latency for continent-scale
  /// datasets.
  func projectInParallelCG(_ contents: [Content], coordinateSystem: CoordinateSystem) async throws -> [CGProjectedContent] {
    try await withThrowingTaskGroup(of: [OffsettedElement<CGProjectedContent>].self) { group in
      let chunks = Array(contents.enumerated()).chunks(ofCount: 5)
      for chunk in chunks {
        let added = group.addTaskUnlessCancelled {
          await Task {
            chunk.compactMap { input in
              guard !Task.isCancelled,
                    let projected = projectCG(input.element, coordinateSystem: coordinateSystem)
              else { return nil }
              return OffsettedElement(offset: input.offset, element: projected)
            }
          }.value
        }
        if !added { throw CancellationError() }
      }
      let unsorted = try await group.reduce(into: [OffsettedElement<CGProjectedContent>]()) { $0.append(contentsOf: $1) }
      return unsorted.sorted(by: <).map(\.element)
    }
  }
}

// GeoDrawer.OffsettedElement wants Equatable; CGProjectedContent
// currently isn't (CGPath doesn't conform). Give it a trivial one keyed
// on identity so the offset ordering works — the `sorted(by:)` only
// looks at the offset field anyway.
extension GeoDrawer.CGProjectedContent: Equatable {
  static func == (lhs: GeoDrawer.CGProjectedContent, rhs: GeoDrawer.CGProjectedContent) -> Bool {
    // Identity-only: we never compare projected content for
    // structural equality, only bucket them by their original input
    // offset.
    withUnsafePointer(to: lhs) { l in
      withUnsafePointer(to: rhs) { r in l == r }
    }
  }
}

// MARK: - Drawing pre-built paths

extension GeoDrawer {

  private func draw(_ line: CGProjectedLine, strokeColor: CGColor, strokeWidth: Double, in context: CGContext) {
    context.addPath(line.path)
    context.setStrokeColor(strokeColor)
    context.setLineWidth(strokeWidth)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.strokePath()
  }

  private func draw(_ polygon: CGProjectedPolygon, fillColor: CGColor?, strokeColor: CGColor?, strokeWidth: Double, in context: CGContext) {
    if let fillColor {
      if polygon.invert {
        // TODO: mirror the LineString branch (not actually inverting).
        context.addPath(polygon.path)
        context.setStrokeColor(fillColor)
        context.setLineWidth(strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.strokePath()
      } else {
        context.addPath(polygon.path)
        context.setFillColor(fillColor)
        context.fillPath(using: .evenOdd)
      }
    }
    if let strokeColor {
      context.addPath(polygon.path)
      context.setStrokeColor(strokeColor)
      context.setLineWidth(strokeWidth)
      context.setLineCap(.round)
      context.setLineJoin(.round)
      context.strokePath()
    }
  }

  func draw(_ contents: [CGProjectedContent], mapBackground: CGColor?, mapOutline: CGColor?, mapBackdrop: CGColor?, in context: CGContext) {
    let cgSize = CGSize(width: size.width, height: size.height)
    let bounds = CGRect(origin: .zero, size: cgSize)

    if let mapBackdrop {
      context.setFillColor(mapBackdrop)
      context.addPath(.init(rect: bounds, transform: nil))
      context.fillPath()
    }

    if let mapBackground, let projection {
      draw(projection.mapBounds, fillColor: mapBackground, in: context)
    }

    // Raster underlays: mirrors the path used by
    // `draw(_ contents: [ProjectedContent], …)` — same clip, same UIKit
    // CTM counter-flip, same tiled-vs-single-image split.
    if let projection {
      let clipPath = mapBoundsPath(projection.mapBounds)
      var clipped = false
      for content in contents {
        let raster: CGImage?
        switch content {
        case .baseMap(let baseMap):
          raster = renderedBaseMap(baseMap, coordinateSystem: coordinateSystem)
        case .tiledBaseMap(let tiled):
          raster = renderedTiledBaseMap(tiled, coordinateSystem: coordinateSystem)
        case .circle, .line, .polygon:
          continue
        }
        guard let raster else { continue }

        if !clipped, let clipPath {
          context.saveGState()
          context.addPath(clipPath)
          context.clip()
          clipped = true
        }
        context.saveGState()
        if coordinateSystem == .topLeft {
          context.translateBy(x: 0, y: bounds.maxY)
          context.scaleBy(x: 1, y: -1)
        }
        context.draw(raster, in: bounds)
        context.restoreGState()
      }
      if clipped { context.restoreGState() }
    }

    for content in contents {
      switch content {
      case .circle, .baseMap, .tiledBaseMap:
        break  // circles go on top of the outline; rasters drawn above
      case let .line(lines, stroke, strokeWidth):
        for line in lines {
          draw(line, strokeColor: stroke, strokeWidth: strokeWidth, in: context)
        }
      case let .polygon(polygons, fill, stroke, strokeWidth):
        for polygon in polygons {
          draw(polygon, fillColor: fill, strokeColor: stroke, strokeWidth: strokeWidth, in: context)
        }
      }
    }

    if let mapOutline, let projection {
      draw(projection.mapBounds, strokeColor: mapOutline, in: context)
    }

    for content in contents {
      if case let .circle(center, radius, fill, stroke, strokeWidth) = content {
        drawCircle(center, radius: CGFloat(radius), fillColor: fill, strokeColor: stroke, strokeWidth: strokeWidth, in: context)
      }
    }
  }
}

#endif
