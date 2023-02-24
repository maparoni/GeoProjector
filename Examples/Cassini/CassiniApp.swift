//
//  CassiniApp.swift
//  Cassini
//
//  Created by Adrian Schönig on 10/12/2022.
//

import SwiftUI

import GeoDrawer

@main
struct CassiniApp: App {
  var body: some Scene {
    Window("Cassini", id: "main-window") {
      ContentView(model: .init(layers: [
        .init(
          name: "Continents",
          contents: try! GeoDrawer.Content.content(
            for: GeoDrawer.Content.countries(),
            color: .init(red: 0, green: 1, blue: 0, alpha: 0)
          ),
          color: NSColor.systemGreen.cgColor
        )
      ]))
    }
  }
}
