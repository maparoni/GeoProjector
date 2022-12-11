//
//  GeoMap+AppKit.swift
//  
//
//  Created by Adrian Schönig on 10/12/2022.
//

#if canImport(AppKit)
import AppKit
import SwiftUI

import GeoProjector

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
      let drawer = GeoDrawer(size: .init(width: frame.size.width, height: frame.size.height), projection: projection)
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
      mapBackground: NSColor.systemTeal.cgColor,
      mapOutline: NSColor.black.cgColor,
      size: frame.size,
      in: context
    )
  }
}

@available(macOS 10.15, *)
public struct GeoMap: NSViewRepresentable {
  public init(contents: [GeoDrawer.Content] = [], projection: Projection = Projections.Equirectangular()) {
    self.contents = contents
    self.projection = projection
  }
  
  public var contents: [GeoDrawer.Content] = []
  
  public var projection: Projection = Projections.Equirectangular()
  
  public typealias NSViewType = GeoMapView
  
  public func makeNSView(context: Context) -> GeoMapView {
    let view = GeoMapView()
    view.contents = contents
    view.projection = projection
    return view
  }
  
  public func updateNSView(_ nsView: GeoMapView, context: Context) {
    nsView.contents = contents
    nsView.projection = projection
  }

}

#if DEBUG
@available(iOS 13.0, macOS 11.0, *)
struct GeoMap_Previews: PreviewProvider {
  static var previews: some View {
    GeoMap(
      contents: try! GeoDrawer.Content.world(),
      projection: Projections.Cassini()
    )
      .previewLayout(.fixed(width: 300, height: 300))
  }
}
#endif

#endif
