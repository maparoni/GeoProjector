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

  private var pendingTiledRerender: Task<Void, Never>?

  /// Schedule a background re-render of the tiled raster for `tiled` and
  /// then a redraw, debounced so a burst of tile arrivals collapses into
  /// a single render rather than thrashing the main thread.
  private func scheduleTiledRerender(for tiled: GeoDrawer.TiledBaseMap) {
    let coord = CoordinateSystem.bottomLeft
    pendingTiledRerender?.cancel()
    pendingTiledRerender = Task.detached(priority: .userInitiated) { [weak self] in
      try? await Task.sleep(nanoseconds: 150_000_000)
      guard let self, !Task.isCancelled else { return }
      _ = self.drawer.renderedTiledBaseMap(tiled, coordinateSystem: coord)
      if Task.isCancelled { return }
      await MainActor.run {
        self.setNeedsDisplay(self.bounds)
      }
    }
  }

  public override func draw(_ rect: NSRect) {
    // Don't draw if we're busy — rendering with the previously-projected
    // content but the *new* drawer (post-projection-change) produced a
    // buggy hybrid where vectors lived in the old projection space while
    // base-map rasters rendered against the new one and got stale-cached
    // with partial tile coverage. Hold the prior frame on screen instead;
    // the new render lands once projection completes.
    let projected: [GeoDrawer.ProjectedContent]
    switch projectProgress {
    case .busy, .idle:
      return
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
        if Task.isCancelled { return }

        // Pre-warm the raster caches off the main thread using whatever
        // tiles are already in the shared `tileCache`. Tiles from prior
        // projections cover the geographic overlap with the new one, so
        // the initial render is fast and visually meaningful for the
        // common projection-switch case.
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

        // Now fetch any tiles the new projection needs that the cache is
        // missing. Each tile arrival invalidates the rendered-raster cache
        // and triggers a debounced background re-render, so the user sees
        // tiles fill in progressively rather than waiting on the full set.
        await withTaskGroup(of: Void.self) { group in
          for content in projected {
            if Task.isCancelled { break }
            guard case let .tiledBaseMap(tiled) = content else { continue }
            group.addTask {
              try? await self.drawer.prefetchTiles(for: tiled) {
                Task { @MainActor in
                  self.scheduleTiledRerender(for: tiled)
                }
              }
            }
          }
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
