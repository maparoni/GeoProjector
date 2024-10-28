//
//  GeoMap+UIKit.swift
//  
//
//  Created by Adrian Schönig on 24/2/2023.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2022 Corporoni Pty Ltd. See LICENSE.

#if canImport(UIKit)
import UIKit
import SwiftUI

import GeoProjector
import GeoJSONKit

public class GeoMapView: UIView {
  public var contents: [GeoDrawer.Content] = [] {
    didSet {
      if contents == oldValue { return }
      invalidateProjectedContents()
      setNeedsDisplay()
    }
  }
  
  public var projection: Projection = Projections.Equirectangular() {
    didSet {
      _drawer = nil
      invalidateProjectedContents()
      setNeedsDisplay()
    }
  }
  
  public var zoomTo: GeoJSON.BoundingBox? = nil {
    didSet {
      _drawer = nil
            
      setNeedsDisplay()
    }
  }

  public var insets: GeoProjector.EdgeInsets = .zero {
    didSet {
      _drawer = nil
      invalidateProjectedContents()
      setNeedsDisplay()
    }
  }

  public var mapBackground: UIColor = .systemTeal {
    didSet {
      setNeedsDisplay()
    }
  }
  
  public var mapOutline: UIColor = .black {
    didSet {
      setNeedsDisplay()
    }
  }

  
  public override var frame: CGRect {
    didSet {
      _drawer = nil
      invalidateProjectedContents()
      setNeedsDisplay()
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
  
  public override func draw(_ rect: CGRect) {
    
    // Get the current graphics context and cast it to a CGContext
    let context = UIGraphicsGetCurrentContext()!
    
    let background: UIColor
    if let backgroundColor {
      background = backgroundColor
    } else if #available(iOS 13.0, *) {
      background = .systemBackground
    } else {
      background = .white
    }
    
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
    
    // Use Core Graphics functions to draw the content of your view
    drawer.draw(
      projected,
      mapBackground: mapBackground.cgColor,
      mapOutline: mapOutline.cgColor,
      mapBackdrop: background.cgColor,
      in: context
    )
    
    context.flush()
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
      let contents = await self.contents
      let drawer = await self.drawer
      
      // This can be slow
      var projected: [GeoDrawer.ProjectedContent] = []
      for content in contents {
        if Task.isCancelled {
          return
        }
        if let item = drawer.project(content) {
          projected.append(item)
        }
      }
      
      let finished = projected
      await MainActor.run {
        self.projectProgress = .finished(finished)
        self.setNeedsDisplay(self.bounds)
      }
    }, previously: previous)
  }
}

@available(iOS 13.0, visionOS 1.0, *)
public struct GeoMap: UIViewRepresentable {
  
  public init(contents: [GeoDrawer.Content] = [], projection: Projection = Projections.Equirectangular(), zoomTo: GeoJSON.BoundingBox? = nil, insets: GeoProjector.EdgeInsets = .zero, mapBackground: UIColor? = nil, mapOutline: UIColor? = nil, mapBackdrop: UIColor? = nil) {
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
  
  public var mapBackground: UIColor? = nil
  
  public var mapOutline: UIColor? = nil
  
  public var mapBackdrop: UIColor? = nil
  
  public typealias UIViewType = GeoMapView
  
  public func makeUIView(context: Context) -> GeoMapView {
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
      view.backgroundColor = mapBackdrop
    }
    return view
  }
  
  public func updateUIView(_ view: GeoMapView, context: Context) {
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
      view.backgroundColor = mapBackdrop
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
