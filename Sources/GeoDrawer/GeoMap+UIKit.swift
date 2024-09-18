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
    didSet { setNeedsDisplay(bounds) }
  }
  
  public var projection: Projection = Projections.Equirectangular() {
    didSet {
      _drawer = nil
      setNeedsDisplay(bounds)
    }
  }
  
  public var zoomTo: GeoJSON.BoundingBox? = nil {
    didSet {
      _drawer = nil
      setNeedsDisplay(bounds)
    }
  }

  public var insets: GeoProjector.EdgeInsets = .zero {
    didSet {
      _drawer = nil
      setNeedsDisplay(bounds)
    }
  }

  public var mapBackground: UIColor = .systemTeal {
    didSet {
      setNeedsDisplay(bounds)
    }
  }
  
  public var mapOutline: UIColor = .black {
    didSet {
      setNeedsDisplay(bounds)
    }
  }

  
  public override var frame: CGRect {
    didSet {
      _drawer = nil
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
        zoomOutFactor: 5,
        insets: insets
      )
      _drawer = drawer
      return drawer
    }
  }
  
  public override func draw(_ rect: CGRect) {
    super.draw(rect)
    
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
    
    // Use Core Graphics functions to draw the content of your view
    drawer.draw(
      contents,
      mapBackground: mapBackground.cgColor,
      mapOutline: mapOutline.cgColor,
      mapBackdrop: background.cgColor,
      in: context
    )
    
    context.flush()
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
      contents: try! GeoDrawer.Content.content(for: GeoDrawer.Content.countries(), color: .init(red: 0, green: 1, blue: 0, alpha: 0)),
      projection: Projections.Cassini()
    )
      .previewLayout(.fixed(width: 300, height: 300))
  }
}
#endif

#endif
