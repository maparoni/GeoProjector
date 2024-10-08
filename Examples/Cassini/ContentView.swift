//
//  ContentView.swift
//  Cassini
//
//  Created by Adrian Schönig on 10/12/2022.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2022 Corporoni Pty Ltd. See LICENSE.

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
        LayersList(model: model)
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

struct LayersList: View {
  @ObservedObject var model: ContentView.Model
  
  var body: some View {
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
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            data = try Data(contentsOf: url)
            preferredName = url.deletingPathExtension().lastPathComponent
          default:
            preconditionFailure()
          }
          try model.addLayer(data, preferredName: preferredName ?? provider.suggestedName)
        }
      }
      
      return true
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
          style: .init(color: CassiniApp.Colors.continents.cgColor)
        ),
        color: CassiniApp.Colors.continents.cgColor
      )
    ]))
  }
}
#endif
