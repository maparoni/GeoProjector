//
//  GeoMap+AppKit.swift
//
//
//  Created by Adrian Schönig on 10/12/2022.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2022 Corporoni Pty Ltd. See LICENSE.

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import SwiftUI

import GeoProjector
import GeoJSONKit

public class GeoMapView: NSView {
  public var contents: [GeoDrawer.Content] = [] {
    didSet {
      invalidateProjectedContents()
      setNeedsDisplay(bounds)
    }
  }

  public var projection: Projection = Projections.Equirectangular() {
    didSet {
      _drawer = nil
      invalidateProjectedContents()
      setNeedsDisplay(bounds)
    }
  }

  public var zoomTo: GeoJSON.BoundingBox? = nil {
    didSet {
      _drawer = nil
      invalidateProjectedContents()
      setNeedsDisplay(bounds)
    }
  }

  public var insets: GeoProjector.EdgeInsets = .zero {
    didSet {
      _drawer = nil
      invalidateProjectedContents()
      setNeedsDisplay(bounds)
    }
  }

  public var mapBackground: NSColor = .systemTeal {
    didSet {
      setNeedsDisplay(bounds)
    }
  }

  public var mapOutline: NSColor = .black {
    didSet {
      setNeedsDisplay(bounds)
    }
  }

  public var mapBackdrop: NSColor = .white {
    didSet {
      setNeedsDisplay(bounds)
    }
  }

  public override var frame: NSRect {
    didSet {
      _drawer = nil
      invalidateProjectedContents()
      setNeedsDisplay(bounds)
    }
  }

  /// Rebuild the drawer when the view's window changes so `pixelDensity`
  /// picks up the new screen's backing scale factor (moving the window
  /// between Retina and non-Retina displays, or initial window attach).
  public override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    _drawer = nil
    invalidateProjectedContents()
    setNeedsDisplay(bounds)
  }

  private var _drawer: GeoDrawer!
  /// Shared across drawer recreations so fetched OSM (or other) tiles
  /// survive projection / size / zoom changes — tile bytes are
  /// projection-independent, so re-hitting the network for them on every
  /// projection switch would be wasteful and visibly delay redraw.
  private let _tileCache = GeoDrawer.TileCache()
  private var drawer: GeoDrawer {
    if let _drawer {
      return _drawer
    } else {
      var drawer = GeoDrawer(
        size: .init(frame.size),
        projection: projection,
        zoomTo: zoomTo,
        insets: insets
      )
      drawer.tileCache = _tileCache
      drawer.pixelDensity = Double(window?.backingScaleFactor ?? 1.0)
      _drawer = drawer
      return drawer
    }
  }

  public override func draw(_ rect: NSRect) {
    // Don't draw if we're busy as this will flicker weirdly
    let projected: [GeoDrawer.ProjectedContent]
    switch projectProgress {
    case .busy(_, .some(let previous)):
      projected = previous
    case .busy(_, .none), .idle:
      return // Don't update drawing; will get called again instead when finished
    case .finished(let finished):
      projected = finished
    }

    super.draw(rect)

    // Get the current graphics context and cast it to a CGContext
    let context = NSGraphicsContext.current!.cgContext

    // Use Core Graphics functions to draw the content of your view
    drawer.draw(
      projected,
      mapBackground: mapBackground.cgColor,
      mapOutline: mapOutline.cgColor,
      mapBackdrop: mapBackdrop.cgColor,
      in: context
    )
  }

  // MARK: - Performance

  enum ProjectionProgress {
    case finished([GeoDrawer.ProjectedContent])
    case busy(Task<Void, Never>, previously: [GeoDrawer.ProjectedContent]?)
    case idle
  }

  private var projectProgress = ProjectionProgress.idle

  private func invalidateProjectedContents() {
    let previous: [GeoDrawer.ProjectedContent]?
    switch projectProgress {
    case .finished(let projected):
      previous = projected
    case .busy(let task, let previously):
      task.cancel()
      previous = previously
    case .idle:
      previous = nil
    }

    projectProgress = .busy(Task(priority: .high) { [weak self] in
      guard let self else { return }
      do {
        let projected = try await drawer.projectInParallel(contents, coordinateSystem: .bottomLeft)
        // Pre-fetch tiled base-map tiles, then pre-warm both raster
        // caches. A cold miss inside `draw(_:)` would block the run loop
        // for either the network round-trip or the per-pixel sweep.
        for content in projected {
          if Task.isCancelled { break }
          if case let .tiledBaseMap(tiled) = content {
            try? await drawer.prefetchTiles(for: tiled)
          }
        }
        for content in projected {
          if Task.isCancelled { break }
          switch content {
          case let .baseMap(baseMap):
            _ = drawer.renderedBaseMap(baseMap, coordinateSystem: .bottomLeft)
          case let .tiledBaseMap(tiled):
            _ = drawer.renderedTiledBaseMap(tiled, coordinateSystem: .bottomLeft)
          case .line, .polygon, .circle:
            break
          }
        }
        if Task.isCancelled { return }
        await MainActor.run {
          self.projectProgress = .finished(projected)
          self.setNeedsDisplay(self.bounds)
        }
      } catch {
        assert(error is CancellationError)
      }
    }, previously: previous)
  }
}

@available(macOS 10.15, *)
public struct GeoMap: NSViewRepresentable {

  public init(contents: [GeoDrawer.Content] = [], projection: Projection = Projections.Equirectangular(), zoomTo: GeoJSON.BoundingBox? = nil, insets: GeoProjector.EdgeInsets = .zero, mapBackground: NSColor? = nil, mapOutline: NSColor? = nil, mapBackdrop: NSColor? = nil) {
    self.contents = contents
    self.projection = projection
    self.zoomTo = zoomTo
    self.insets = insets
    self.mapBackground = mapBackground
    self.mapOutline = mapOutline
    self.mapBackdrop = mapBackdrop
  }

  public var contents: [GeoDrawer.Content] = []

  public var projection: Projection = Projections.Equirectangular()

  public var zoomTo: GeoJSON.BoundingBox? = nil

  public var insets: GeoProjector.EdgeInsets = .zero

  public var mapBackground: NSColor? = nil

  public var mapOutline: NSColor? = nil

  public var mapBackdrop: NSColor? = nil

  public typealias NSViewType = GeoMapView

  public func makeNSView(context: Context) -> GeoMapView {
    let view = GeoMapView()
    view.contents = contents
    view.projection = projection
    view.zoomTo = zoomTo
    view.insets = insets
    if let mapBackground {
      view.mapBackground = mapBackground
    }
    if let mapOutline {
      view.mapOutline = mapOutline
    }
    if let mapBackdrop {
      view.mapBackdrop = mapBackdrop
    }
    return view
  }

  public func updateNSView(_ view: GeoMapView, context: Context) {
    view.contents = contents
    view.projection = projection
    view.zoomTo = zoomTo
    view.insets = insets
    if let mapBackground {
      view.mapBackground = mapBackground
    }
    if let mapOutline {
      view.mapOutline = mapOutline
    }
    if let mapBackdrop {
      view.mapBackdrop = mapBackdrop
    }
  }

}

#if DEBUG
@available(iOS 13.0, visionOS 1.0, macOS 11.0, *)
struct GeoMap_Previews: PreviewProvider {
  static var previews: some View {
    GeoMap(
      contents: try! GeoDrawer.Content.content(
        for: GeoDrawer.Content.countries(),
        style: .init(color: .init(red: 0, green: 1, blue: 0, alpha: 0))
      ),
      projection: Projections.Cassini()
    )
      .previewLayout(.fixed(width: 300, height: 300))
  }
}
#endif

#endif
