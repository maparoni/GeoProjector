//
//  ContentView.swift
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
import GeoJSONKit

struct ContentView: View {
  @ObservedObject var model: Model
  
  var body: some View {
#if os(macOS)
    ContentView_macOS(model: model)
#else
    ContentView_iOS(model: model)
#endif
  }
}

#if os(macOS)
struct ContentView_macOS: View {
  @ObservedObject var model: ContentView.Model
  
  @Environment(\.colorScheme) var colorScheme
  
  var body: some View {
    HSplitView {
      OptionsView(model: model)
        .frame(maxWidth: 300)
      
      VStack {
        GeoMap(
          contents: model.visibleContents,
          projection: model.projection,
          zoomTo: model.zoomTo?.0,
          insets: model.insets,
          mapBackground: colorScheme == .dark ? .systemPurple : .systemTeal,
          mapOutline: colorScheme == .dark ? .white : .black
        )
      }
      .padding()
    }
    
  }
}

#else

struct ContentView_iOS: View {
  @ObservedObject var model: ContentView.Model

  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    VStack {
      GeoMap(
        contents: model.visibleContents,
        projection: model.projection,
        zoomTo: model.zoomTo?.0,
        insets: model.insets,
        mapBackground: colorScheme == .dark ? .systemPurple : .systemTeal,
        mapOutline: colorScheme == .dark ? .white : .black
      )
      
      ScrollView {
        OptionsView(model: model)
      }
    }
    .padding()
  }
}
#endif

struct OptionsView: View {
  @ObservedObject var model: ContentView.Model
  
  var body: some View {
    VStack {
#if os(macOS)
      GroupBox("Contents") {
        List($model.layers, editActions: [.all]) { $layer in
          HStack {
            Toggle("", isOn: $layer.visible)
            Text(layer.name)
            
            Spacer()
            
            if model.zoomTo?.1 == layer.id {
              Image(systemName: "location.magnifyingglass")
            }
            
            ColorPicker("", selection: $layer.color)
              .frame(maxWidth: 50)
          }
          .contextMenu {
            if model.zoomTo?.1 == layer.id {
              Button("Remove Zoom") {
                model.zoom(to: nil)
              }
            } else {
              Button("Zoom") {
                model.zoom(to: layer)
              }
            }
            
            Button("Delete", role: .destructive) {
              if let index = model.layers.firstIndex(where: { $0.id == layer.id }) {
                model.layers.remove(at: index)
              }
            }
          }
        }
        .onDrop(of: ["public.json"], isTargeted: nil) { providers in
          print("Got \(providers)")
          Task {
            for provider in providers {
              let object = try await provider.loadItem(forTypeIdentifier: "public.json")
              let data: Data
              var preferredName: String? = nil
              switch object {
              case let aData as Data:
                data = aData
              case let url as URL:
                data = try Data(contentsOf: url)
                preferredName = url.deletingPathExtension().lastPathComponent
              default:
                preconditionFailure()
              }
              let geoJSON = try GeoJSON(data: data)
              let color: GeoDrawer.Color = .init(
                red: Double((0...255).randomElement()!) / 255,
                green: Double((0...255).randomElement()!) / 255,
                blue: Double((0...255).randomElement()!) / 255,
                alpha: 1
              )
              
              model.layers.append(.init(
                name: preferredName ?? provider.suggestedName ?? "New Layer",
                contents: GeoDrawer.Content.content(for: geoJSON, color: color),
                color: color
              ))
            }
          }
          
          return true
        }
      }
      
      GroupBox("Projection") {
        List(selection: $model.projectionType) {
          ForEach(ContentView.ProjectionType.allCases) {
            Text($0.rawValue).tag($0)
          }
        }
      }
#else
      Picker("Projection", selection: $model.projectionType) {
        ForEach(ContentView.ProjectionType.allCases) {
          Text($0.rawValue).tag($0)
        }
      }
#endif

      GroupBox("Reference") {
        HStack {
          Slider(value: $model.refLat, in: -90...90) {
            Text("Latitude")
              .frame(width: 100, alignment: .trailing)
          }
          .frame(minWidth: 200)
          
          TextField(value: $model.refLat, format: .number.precision(.fractionLength(1))) {
            EmptyView()
          }
          .frame(maxWidth: 55)
        }
        
        HStack {
          Slider(value: $model.refLng, in: -180...180) {
            Text("Longitude")
              .frame(width: 100, alignment: .trailing)
          }
          .frame(minWidth: 200)
          
          TextField(value: $model.refLng, format: .number.precision(.fractionLength(1))) {
            EmptyView()
          }
          .frame(maxWidth: 55)
        }
      }
      
      GroupBox("Edge Insets") {
        HStack {
          Spacer()
          
          TextField(value: $model.insets.top, format: .number.precision(.fractionLength(0))) {
            EmptyView()
          }
          .frame(maxWidth: 55)
          
          Spacer()
        }
        
        HStack {
          Spacer()
          
          TextField(value: $model.insets.left, format: .number.precision(.fractionLength(0))) {
            EmptyView()
          }
          .frame(maxWidth: 55)
          
          TextField(value: $model.insets.right, format: .number.precision(.fractionLength(0))) {
            EmptyView()
          }
          .frame(maxWidth: 55)
          
          Spacer()
        }
        
        HStack {
          Spacer()
          
          TextField(value: $model.insets.bottom, format: .number.precision(.fractionLength(0))) {
            EmptyView()
          }
          .frame(maxWidth: 55)
          
          Spacer()
        }
        
      }
    }
  }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
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
#endif
