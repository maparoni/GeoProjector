//
//  ContentView.swift
//  Cassini
//
//  Created by Adrian Schönig on 10/12/2022.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2022 Corporoni Pty Ltd. See LICENSE.

import SwiftUI

#if os(macOS)
import AppKit
#endif

import GeoDrawer
import GeoJSONKit
import GeoProjector

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

  @State private var hoverCoord: GeoJSON.Position?
  @State private var lockedCoord: GeoJSON.Position?

  var body: some View {
    HSplitView {
      OptionsView(model: model)
        .frame(maxWidth: 300)

      VStack(spacing: 0) {
        GeometryReader { geo in
          GeoMap(
            contents: model.visibleContents,
            projection: model.projection,
            zoomTo: model.zoomTo?.0,
            insets: model.insets,
            mapBackground: colorScheme == .dark ? .systemPurple : .systemTeal,
            mapOutline: colorScheme == .dark ? .white : .black
          )
          .onContinuousHover { phase in
            switch phase {
            case .active(let location):
              hoverCoord = coordinate(at: location, in: geo.size)
            case .ended:
              hoverCoord = nil
            }
          }
          .onTapGesture(coordinateSpace: .local) { location in
            if let coord = coordinate(at: location, in: geo.size) {
              lockedCoord = coord
            }
          }
          .overlay(alignment: .bottomTrailing) {
            if let attribution = model.baseMapMode.attribution {
              AttributionLabel(text: attribution)
                .padding(8)
            }
          }
        }
        .padding()

        MapStatusBar(
          live: hoverCoord,
          locked: lockedCoord,
          onCopy: copyLockedCoord,
          onDiscard: { lockedCoord = nil }
        )
      }
    }
  }

  private func coordinate(at location: CGPoint, in size: CGSize) -> GeoJSON.Position? {
    model.projection.coordinate(
      at: .init(x: location.x, y: location.y),
      size: .init(width: size.width, height: size.height),
      zoomTo: model.projectedZoomTo,
      insets: model.insets,
      coordinateSystem: .topLeft
    )
  }

  private func copyLockedCoord() {
    guard let lockedCoord else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(formatCoord(lockedCoord), forType: .string)
    self.lockedCoord = nil
  }
}

struct MapStatusBar: View {
  let live: GeoJSON.Position?
  let locked: GeoJSON.Position?
  let onCopy: () -> Void
  let onDiscard: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      if let locked {
        Image(systemName: "mappin.circle.fill")
          .foregroundStyle(.tint)
        Text(formatCoord(locked))
          .font(.system(.body, design: .monospaced))
        Spacer()
        Button("Copy", action: onCopy)
          .keyboardShortcut("c", modifiers: [.command])
        Button("Discard", role: .cancel, action: onDiscard)
          .keyboardShortcut(.escape, modifiers: [])
      } else if let live {
        Image(systemName: "mappin.and.ellipse")
          .foregroundStyle(.secondary)
        Text(formatCoord(live))
          .font(.system(.body, design: .monospaced))
          .foregroundStyle(.secondary)
        Spacer()
      } else {
        Image(systemName: "mappin.slash")
          .foregroundStyle(.tertiary)
        Text("Hover over the map to see coordinates")
          .foregroundStyle(.secondary)
        Spacer()
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .frame(maxWidth: .infinity, minHeight: 30)
    .background(.bar)
    .overlay(Divider(), alignment: .top)
  }
}

private func formatCoord(_ p: GeoJSON.Position) -> String {
  let latHem = p.latitude  >= 0 ? "N" : "S"
  let lonHem = p.longitude >= 0 ? "E" : "W"
  return String(format: "%7.4f° %@   %8.4f° %@", abs(p.latitude), latHem, abs(p.longitude), lonHem)
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
      .overlay(alignment: .bottomTrailing) {
        if let attribution = model.baseMapMode.attribution {
          AttributionLabel(text: attribution)
            .padding(8)
        }
      }

      ScrollView {
        OptionsView(model: model)
      }
    }
    .padding()
  }
}
#endif

struct AttributionLabel: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.caption2)
      .padding(.horizontal, 6)
      .padding(.vertical, 3)
      .background(Color.black.opacity(0.6))
      .foregroundStyle(.white)
      .clipShape(RoundedRectangle(cornerRadius: 4))
  }
}

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

      GroupBox("Base map") {
        Picker("Base map", selection: $model.baseMapMode) {
          ForEach(ContentView.BaseMapMode.allCases) {
            Text($0.label).tag($0)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
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
        .disabled(!model.projectionType.usesReferenceLatitude)

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
        .disabled(!model.projectionType.usesReferenceLongitude)
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
