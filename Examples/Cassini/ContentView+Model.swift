//
//  ContentView+Model.swift
//  Cassini
//
//  Created by Adrian Schönig on 11/12/2022.
//

import Foundation
import CoreGraphics

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
      self.projectionType = .orthographic
    }
    
    @Published var layers: [Layer]
    
    @Published var projection: any Projection
    
    @Published var projectionType: ProjectionType {
      didSet { updateProjection() }
    }
    
    @Published var refLat: Double = 0 {
      didSet { updateProjection() }
    }

    @Published var refLng: Double = 0 {
      didSet { updateProjection() }
    }

    @Published var equirectangularPhiOne: Double = 0 {
      didSet { updateProjection() }
    }
    
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
