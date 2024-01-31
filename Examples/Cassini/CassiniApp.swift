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
    ContentView(model: .init(layers: [
      .init(
        name: "Continents",
        contents: try! GeoDrawer.Content.content(
          for: GeoDrawer.Content.countries(),
          color: CassiniApp.Colors.continents.cgColor
        ),
        color: CassiniApp.Colors.continents.cgColor
      )
    ]))
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
