//
//  ContentView.swift
//  Cassini
//
//  Created by Adrian Schönig on 10/12/2022.
//

import SwiftUI

import GeoDrawer
import GeoJSONKit

struct ContentView: View {
  @ObservedObject var model: Model
  
  var body: some View {
#if os(macOS)
    ContentView_macOS(model: model)
#else
    ContentView_iOS()
#endif
  }
}

#if os(macOS)
struct ContentView_macOS: View {
  @ObservedObject var model: ContentView.Model
  
  @Environment(\.colorScheme) var colorScheme
  
  var body: some View {
    HSplitView {
      VStack {
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
            ForEach(ContentView.ProjectionType.allCases, id: \.self) {
              Text($0.rawValue).tag($0)
            }
          }
        }
        
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
  var body: some View {
    VStack {
      Image(systemName: "globe")
        .imageScale(.large)
        .foregroundColor(.accentColor)
      Text("Hello, world!")
    }
    .padding()
  }
}
#endif

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
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
