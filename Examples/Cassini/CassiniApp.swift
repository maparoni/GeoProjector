//
//  CassiniApp.swift
//  Cassini
//
//  Created by Adrian Schönig on 10/12/2022.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2022 Corporoni Pty Ltd. See LICENSE.

import SwiftUI

import GeoDrawer

@main
struct CassiniApp: App {
  var body: some Scene {
#if os(macOS)
    Window("Cassini", id: "main-window") {
      windowContent
    }
#else
    WindowGroup {
      windowContent
    }
#endif
  }
    
  var windowContent: some View {
    // iOS doesn't expose the layers list yet, so default to the Blue Marble
    // raster on its own there, with the vector continents hidden.
#if os(macOS)
    let continentsVisible = true
    let baseMapMode = ContentView.BaseMapMode.none
#else
    let continentsVisible = false
    let baseMapMode = ContentView.BaseMapMode.blueMarble
#endif
    let continents = ContentView.Layer(
      name: "Continents",
      contents: try! GeoDrawer.Content.content(
        for: GeoDrawer.Content.countries(),
        style: .init(color: CassiniApp.Colors.continents.cgColor)
      ),
      color: CassiniApp.Colors.continents.cgColor,
      visible: continentsVisible
    )
    return ContentView(model: .init(layers: [continents], baseMapMode: baseMapMode))
  }
}

extension CassiniApp {
  enum Colors {
    case continents
    
    var cgColor: CGColor {
#if os(macOS)
      return NSColor.systemGreen.cgColor
#else
      return UIColor.systemGreen.cgColor
#endif
    }
  }
}
