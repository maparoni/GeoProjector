//
//  ContentView+Model.swift
//  Cassini
//
//  Created by Adrian Schönig on 11/12/2022.
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

import Foundation
import CoreGraphics
import SwiftUI

import GeoJSONKit
import GeoDrawer

extension ContentView {
  
  enum ProjectionType: String, CaseIterable {
    case equirectangular
    case cassini
    case mercator
    case gallPeters
    case equalEarth
    case orthographic
    case azimuthal
  }
  
  struct Layer: Identifiable {
    var id: UUID = .init()
    var name: String
    let contents: [GeoDrawer.Content]
    var color: CGColor
    var visible: Bool = true
  }
  
  class Model: ObservableObject {
    init(layers: [Layer] = []) {
      self.layers = layers
      self.projection = Projections.Orthographic()
    }
    
    @Published var layers: [Layer]
    
    @Published var projection: any Projection
    
    @AppStorage("options.projection")
    var projectionType: ProjectionType = .orthographic {
      didSet { updateProjection() }
    }
    
    @AppStorage("options.reference.latitude")
    var refLat: Double = 0 {
      didSet { updateProjection() }
    }

    @AppStorage("options.reference.longitude")
    var refLng: Double = 0 {
      didSet { updateProjection() }
    }

    @Published var equirectangularPhiOne: Double = 0 {
      didSet { updateProjection() }
    }
    
    @Published var insets: GeoProjector.EdgeInsets = .zero {
      didSet { updateProjection() }
    }
    
    @Published var zoomTo: (GeoJSON.BoundingBox, Layer.ID)?
    
    func updateProjection() {
      let reference = GeoJSON.Position(latitude: refLat, longitude: refLng)
      
      switch projectionType {
      case .equirectangular:
        projection = Projections.Equirectangular(reference: reference, phiOne: equirectangularPhiOne.toRadians())
      case .cassini:
        projection = Projections.Cassini(reference: reference)
      case .mercator:
        projection = Projections.Mercator(reference: reference)
      case .gallPeters:
        projection = Projections.GallPeters(reference: reference)
      case .equalEarth:
        projection = Projections.EqualEarth(reference: reference)
      case .orthographic:
        projection = Projections.Orthographic(reference: reference)
      case .azimuthal:
        projection = Projections.AzimuthalEquidistant(reference: reference)
      }
    }
    
    var visibleContents: [GeoDrawer.Content] {
      layers
        .filter(\.visible)
        .flatMap { layer in
          layer.contents.map { $0.settingColor(layer.color) }
        }
    }
    
    func zoom(to layer: Layer?) {
      guard let layer else {
        zoomTo = nil
        return
      }
      
      let positions = layer.contents.reduce(into: [GeoJSON.Position]()) { acc, next in
        switch next {
        case .circle(let position, _, _, _):
          acc.append(position)
        case .line(let line, _):
          acc.append(contentsOf: line.positions)
        case .polygon(let polygon, _, _):
          acc.append(contentsOf: polygon.exterior.positions)
        }
      }
      
      if positions.isEmpty {
        zoomTo = nil
      } else {
        zoomTo = (.init(positions: positions, allowSpanningAntimeridian: true), layer.id)
      }
    }
  }
  
}

extension GeoDrawer.Content {
  
  func settingColor(_ color: CGColor) -> GeoDrawer.Content {
    switch self {
    case .line(let lineString, _):
      return .line(lineString, stroke: color)
    case .polygon(let polygon, _, _):
      return .polygon(polygon, fill: color)
    case .circle(let position, let radius, _, _):
      return .circle(position, radius: radius, fill: color)
    }
  }
  
}
