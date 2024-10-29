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
  
  private var _drawer: GeoDrawer!
  private var drawer: GeoDrawer {
    if let _drawer {
      return _drawer
    } else {
      let drawer = GeoDrawer(
        size: .init(frame.size),
        projection: projection,
        zoomTo: zoomTo,
        insets: insets
      )
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

    projectProgress = .busy(Task.detached(priority: .high) { [weak self] in
      guard let self else { return }
      do {
        let projected = try await drawer.projectInParallel(contents)
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
