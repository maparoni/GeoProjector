//
//  CassiniApp.swift
//  Cassini
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
