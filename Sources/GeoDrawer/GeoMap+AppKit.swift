//
//  GeoMap+AppKit.swift
//  
//
//  Created by Adrian Schönig on 10/12/2022.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2022 Corporoni Pty Ltd
//
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Lesser General Public
// License as published by the Free Software Foundation; either
// version 2.1 of the License, or (at your option) any later version.
//
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public
// License along with this library; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301
// USA

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import SwiftUI

import GeoProjector
import GeoJSONKit

public class GeoMapView: NSView {
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

  
  public override var frame: NSRect {
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
        size: .init(width: frame.size.width, height: frame.size.height),
        projection: projection,
        zoomTo: zoomTo,
        insets: insets
      )
      _drawer = drawer
      return drawer
    }
  }
  
  public override func draw(_ rect: NSRect) {
    super.draw(rect)
    
    // Get the current graphics context and cast it to a CGContext
    let context = NSGraphicsContext.current!.cgContext
    
    // Use Core Graphics functions to draw the content of your view
    drawer.draw(
      contents,
      mapBackground: mapBackground.cgColor,
      mapOutline: mapOutline.cgColor,
      size: frame.size,
      in: context
    )
  }
}

@available(macOS 10.15, *)
public struct GeoMap: NSViewRepresentable {
  
  public init(contents: [GeoDrawer.Content] = [], projection: Projection = Projections.Equirectangular(), zoomTo: GeoJSON.BoundingBox? = nil, insets: GeoProjector.EdgeInsets = .zero, mapBackground: NSColor? = nil, mapOutline: NSColor? = nil) {
    self.contents = contents
    self.projection = projection
    self.zoomTo = zoomTo
    self.insets = insets
    self.mapBackground = mapBackground
    self.mapOutline = mapOutline
  }
  
  public var contents: [GeoDrawer.Content] = []
  
  public var projection: Projection = Projections.Equirectangular()
  
  public var zoomTo: GeoJSON.BoundingBox? = nil
  
  public var insets: GeoProjector.EdgeInsets = .zero
  
  public var mapBackground: NSColor? = nil
  
  public var mapOutline: NSColor? = nil
  
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
  }

}

#if DEBUG
@available(iOS 13.0, macOS 11.0, *)
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
