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
      cycleDrawer()
      invalidateProjectedContents()
      setNeedsDisplay(bounds)
    }
  }

  public var zoomTo: GeoJSON.BoundingBox? = nil {
    didSet {
      cycleDrawer()
      invalidateProjectedContents()
      setNeedsDisplay(bounds)
    }
  }

  public var insets: GeoProjector.EdgeInsets = .zero {
    didSet {
      cycleDrawer()
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

  /// Render-resolution policy. `.matchDisplay` (the default) renders at
  /// the destination display's backing scale; switch to `.draft` for
  /// fast interactive previews that accept some blur, or `.custom(_)`
  /// to pick an explicit pixel-density factor (e.g. for export).
  public var quality: GeoMap.Quality = .matchDisplay {
    didSet {
      if quality == oldValue { return }
      cycleDrawer()
      invalidateProjectedContents()
      setNeedsDisplay(bounds)
    }
  }

  /// Called on the main thread whenever the in-flight tile prefetch
  /// state changes — fires once with `loaded == 0` at the start of
  /// each projection's prefetch, then per tile completion (success or
  /// failure), and a final snapshot when complete. Drives Cassini's
  /// progress overlay + warning icon.
  public var onTileProgress: ((TileFetchProgress) -> Void)? = nil

  /// Resolves `quality` to the concrete `pixelDensity` value for the
  /// next drawer build. `.matchDisplay` reads the current window's
  /// backing scale, so moving the window between displays picks up the
  /// new value via `viewDidMoveToWindow`'s drawer rebuild.
  private var resolvedPixelDensity: Double {
    switch quality {
    case .draft: return 0.5
    case .standard: return 1.0
    case .matchDisplay: return Double(window?.backingScaleFactor ?? 1.0)
    case .custom(let d): return max(0.1, d)
    }
  }

  public override var frame: NSRect {
    didSet {
      cycleDrawer()
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
  /// The drawer we were rendering with at the last `.finished` state,
  /// kept alive across the next projection / size / zoom / quality
  /// change so `draw(_:)` can paint its prior frame while the new
  /// render is in flight. Without this, returning early during `.busy`
  /// cleared the backing store and flashed between every slider tick.
  /// Cleared on the next `.finished` transition.
  private var _previousDrawer: GeoDrawer?
  /// Shared across drawer recreations so fetched OSM (or other) tiles
  /// survive projection / size / zoom changes — tile bytes are
  /// projection-independent, so re-hitting the network for them on every
  /// projection switch would be wasteful and visibly delay redraw.
  private let _tileCache = GeoDrawer.TileCache()

  /// Save the current drawer for `draw(_:)` to use during the upcoming
  /// busy state, then clear `_drawer` so the next access rebuilds it
  /// against the new parameters. The save is sticky — burst slider
  /// drags don't overwrite the original prior drawer until a render
  /// actually finishes.
  private func cycleDrawer() {
    if _previousDrawer == nil, let existing = _drawer {
      _previousDrawer = existing
    }
    _drawer = nil
  }

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
      drawer.pixelDensity = resolvedPixelDensity
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
      _ = await self.drawer.renderedTiledBaseMap(tiled, coordinateSystem: coord)
      if Task.isCancelled { return }
      await MainActor.run {
        self.setNeedsDisplay(self.bounds)
      }
    }
  }

  public override func draw(_ rect: NSRect) {
    // Pick the drawer + projected content to paint. When busy with a
    // prior finished frame, we want a drawer whose projection matches
    // that frame:
    //   - If the drawer was cycled (projection / size / zoom / quality
    //     change), `_previousDrawer` holds the old drawer with the old
    //     projection — render the prior pair to reproduce the last
    //     good frame exactly. This dodges the hybrid "new drawer
    //     rendering old projected content" case that partially-cached
    //     a tiled raster, and also avoids white flashes from
    //     returning early.
    //   - If only `contents` changed, `_drawer` is still the same
    //     drawer with the same projection, so rendering the
    //     previously-projected content against it is correct — same
    //     layers as before the toggle, just briefly.
    let activeDrawer: GeoDrawer
    let projected: [GeoDrawer.ProjectedContent]
    switch projectProgress {
    case let .busy(_, .some(previously)):
      if let stale = _previousDrawer {
        activeDrawer = stale
      } else if let current = _drawer {
        activeDrawer = current
      } else {
        return
      }
      projected = previously
    case .busy(_, .none), .idle:
      return
    case let .finished(finished):
      activeDrawer = drawer
      projected = finished
    }

    super.draw(rect)

    // Get the current graphics context and cast it to a CGContext
    let context = NSGraphicsContext.current!.cgContext

    // Use Core Graphics functions to draw the content of your view
    activeDrawer.draw(
      projected,
      mapBackground: mapBackground.cgColor,
      mapOutline: mapOutline.cgColor,
      mapBackdrop: mapBackdrop.cgColor,
      in: context
    )

    if isStaleRender {
      // The new render has been in flight long enough that the prior
      // frame is misleadingly fresh — wash it in translucent grey to
      // signal "loading".
      context.setFillColor(CGColor(gray: 0.5, alpha: 0.25))
      context.fill(rect)
    }
  }

  // MARK: - Performance

  enum ProjectionProgress {
    case finished([GeoDrawer.ProjectedContent])
    case busy(Task<Void, Never>, previously: [GeoDrawer.ProjectedContent]?)
    case idle
  }

  private var projectProgress = ProjectionProgress.idle

  /// When `true`, `draw(_:)` tints the prior frame translucent grey to
  /// signal that the new render has been in flight for a while.
  private var isStaleRender = false
  private var staleRenderTimer: Task<Void, Never>?

  private func startStaleRenderTimer() {
    staleRenderTimer?.cancel()
    staleRenderTimer = Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: 500_000_000)
      guard let self, !Task.isCancelled else { return }
      if case .busy = self.projectProgress, !self.isStaleRender {
        self.isStaleRender = true
        self.setNeedsDisplay(self.bounds)
      }
    }
  }

  private func cancelStaleRenderTimer() {
    staleRenderTimer?.cancel()
    staleRenderTimer = nil
    if isStaleRender {
      isStaleRender = false
      // `setNeedsDisplay` is implicit at the .finished transition; no
      // need to schedule an extra one here.
    }
  }

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

    startStaleRenderTimer()

    projectProgress = .busy(Task.detached(priority: .high) { [weak self] in
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
            _ = await drawer.renderedBaseMap(baseMap, coordinateSystem: .bottomLeft)
          case let .tiledBaseMap(tiled):
            _ = await drawer.renderedTiledBaseMap(tiled, coordinateSystem: .bottomLeft)
          case .line, .polygon, .circle:
            break
          }
        }
        if Task.isCancelled { return }
        await MainActor.run {
          self.cancelStaleRenderTimer()
          self._previousDrawer = nil
          self.projectProgress = .finished(projected)
          self.setNeedsDisplay(self.bounds)
        }

        // Now fetch any tiles the new projection needs that the cache is
        // missing. Each tile arrival invalidates the rendered-raster cache
        // and triggers a debounced background re-render, so the user sees
        // tiles fill in progressively rather than waiting on the full set.
        // Progress is surfaced to the consumer via `onTileProgress`.
        await withTaskGroup(of: Void.self) { group in
          for content in projected {
            if Task.isCancelled { break }
            guard case let .tiledBaseMap(tiled) = content else { continue }
            group.addTask {
              await self.drawer.prefetchTiles(for: tiled) { progress in
                Task { @MainActor in
                  self.onTileProgress?(progress)
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

  /// Render-resolution policy. The consuming app picks the trade-off
  /// between rendering cost and crispness based on context (fast
  /// `.draft` while the user is interactively exploring, sharper
  /// `.matchDisplay` once they've settled on a view they like).
  public enum Quality: Hashable, Sendable {
    /// Render at half the canvas's logical-point size. Cheap and soft —
    /// good for live previews while dragging sliders or cycling projections.
    case draft
    /// Render at the canvas's logical-point size (no oversampling). Sharp
    /// on non-Retina displays; visibly soft on Retina.
    case standard
    /// Render at the destination display's backing scale factor — matches
    /// what native UIKit/AppKit drawing produces. Default.
    case matchDisplay
    /// Render at the supplied pixel-density factor (e.g. for export at a
    /// specific resolution, or fine-tuning quality vs. performance).
    case custom(Double)
  }

  public init(contents: [GeoDrawer.Content] = [], projection: Projection = Projections.Equirectangular(), zoomTo: GeoJSON.BoundingBox? = nil, insets: GeoProjector.EdgeInsets = .zero, mapBackground: NSColor? = nil, mapOutline: NSColor? = nil, mapBackdrop: NSColor? = nil, quality: Quality = .matchDisplay, onTileProgress: ((TileFetchProgress) -> Void)? = nil) {
    self.contents = contents
    self.projection = projection
    self.zoomTo = zoomTo
    self.insets = insets
    self.mapBackground = mapBackground
    self.mapOutline = mapOutline
    self.mapBackdrop = mapBackdrop
    self.quality = quality
    self.onTileProgress = onTileProgress
  }

  public var contents: [GeoDrawer.Content] = []

  public var projection: Projection = Projections.Equirectangular()

  public var zoomTo: GeoJSON.BoundingBox? = nil

  public var insets: GeoProjector.EdgeInsets = .zero

  public var mapBackground: NSColor? = nil

  public var mapOutline: NSColor? = nil

  public var mapBackdrop: NSColor? = nil

  public var quality: Quality = .matchDisplay

  public var onTileProgress: ((TileFetchProgress) -> Void)? = nil

  public typealias NSViewType = GeoMapView

  public func makeNSView(context: Context) -> GeoMapView {
    let view = GeoMapView()
    view.contents = contents
    view.projection = projection
    view.zoomTo = zoomTo
    view.insets = insets
    view.quality = quality
    view.onTileProgress = onTileProgress
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
    view.quality = quality
    view.onTileProgress = onTileProgress
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
