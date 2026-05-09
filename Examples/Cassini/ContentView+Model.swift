//
//  ContentView+Model.swift
//  Cassini
//
//  Created by Adrian Schönig on 11/12/2022.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2022 Corporoni Pty Ltd. See LICENSE.

import Foundation
import CoreGraphics
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

import GeoJSONKit
import GeoDrawer
import GeoProjectorDanseiji

extension ContentView {

  enum ProjectionType: String, CaseIterable, Identifiable {
    case equirectangular
    case cassini
    case mercator
    case gallPeters
    case equalEarth
    case naturalEarth
    case orthographic
    case azimuthal
    case danseijiI
    case danseijiII
    case danseijiIII
    case danseijiIV
    case danseijiV
    case danseijiVI

    var id: String { rawValue }

    /// Whether the projection's output depends on the reference latitude.
    var usesReferenceLatitude: Bool {
      switch self {
      case .orthographic, .azimuthal: return true
      case .equirectangular, .cassini, .mercator, .gallPeters, .equalEarth, .naturalEarth,
           .danseijiI, .danseijiII, .danseijiIII, .danseijiIV, .danseijiV, .danseijiVI: return false
      }
    }

    /// Whether the projection's output depends on the reference longitude.
    /// Danseiji V and VI are hand-tuned asymmetric meshes (V emphasises
    /// continents over oceans; VI weighs population alongside area), so
    /// rotating their reference longitude misaligns the deformations from
    /// the underlying geography. They pin the reference at `(0, 0)` and
    /// the slider is disabled to match.
    var usesReferenceLongitude: Bool {
      switch self {
      case .cassini, .danseijiV, .danseijiVI: return false
      case .equirectangular, .mercator, .gallPeters, .equalEarth, .naturalEarth, .orthographic, .azimuthal,
           .danseijiI, .danseijiII, .danseijiIII, .danseijiIV: return true
      }
    }
  }
  
  struct Layer: Identifiable {
    var id: UUID = .init()
    var name: String
    let contents: [GeoDrawer.Content]
    var color: CGColor
    var visible: Bool = true
  }
  
  class Model: ObservableObject {
    init(layers: [Layer] = [], showBaseMap: Bool = false) {
      self.layers = layers
      self.projection = Projections.Orthographic()
      self.showBaseMap = showBaseMap
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

    @Published var showBaseMap: Bool = false

    /// Lazily-decoded NASA Blue Marble Next Generation base map. The asset is
    /// shipped in the Cassini asset catalogue (5400×2700 equirectangular JPEG
    /// from the 2004-08 monthly composite). The decode happens once on first
    /// toggle and is cached for the app's lifetime.
    private var _blueMarble: GeoDrawer.BaseMap?
    var baseMap: GeoDrawer.BaseMap? {
      guard showBaseMap else { return nil }
      if _blueMarble == nil {
        _blueMarble = BlueMarble.load()
      }
      return _blueMarble
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
      case .naturalEarth:
        projection = Projections.NaturalEarth(reference: reference)
      case .orthographic:
        projection = Projections.Orthographic(reference: reference)
      case .azimuthal:
        projection = Projections.AzimuthalEquidistant(reference: reference)
      case .danseijiI:
        projection = Projections.DanseijiI(reference: reference)
      case .danseijiII:
        projection = Projections.DanseijiII(reference: reference)
      case .danseijiIII:
        projection = Projections.DanseijiIII(reference: reference)
      case .danseijiIV:
        projection = Projections.DanseijiIV(reference: reference)
      case .danseijiV:
        projection = Projections.DanseijiV(reference: reference)
      case .danseijiVI:
        projection = Projections.DanseijiVI(reference: reference)
      }
    }
    
    var visibleContents: [GeoDrawer.Content] {
      var result: [GeoDrawer.Content] = []
      // Base map renders first so the vector layers land on top.
      if let baseMap {
        result.append(.baseMap(baseMap))
      }
      result.append(contentsOf: layers
        .filter(\.visible)
        .flatMap { layer in
          layer.contents.map { $0.settingColor(layer.color) }
        })
      return result
    }

    /// The same projected `Rect` that `GeoDrawer` (and therefore `GeoMap`) uses for the
    /// current `zoomTo` bounding box, suitable for passing to `Projection.coordinate(at:...)`.
    var projectedZoomTo: Rect? {
      guard let box = zoomTo?.0 else { return nil }
      // Size doesn't influence the computed zoom rect — pick anything.
      let drawer = GeoDrawer(size: .init(width: 100, height: 100), projection: projection, zoomTo: box, insets: insets)
      return drawer.zoomTo
    }
    
    func addLayer(_ data: Data, preferredName: String?) throws {
      let geoJSON = try GeoJSON(data: data)
      let color: GeoDrawer.Color = .init(
        red: Double((0...255).randomElement()!) / 255,
        green: Double((0...255).randomElement()!) / 255,
        blue: Double((0...255).randomElement()!) / 255,
        alpha: 1
      )
      
      layers.append(.init(
        name: preferredName ?? "New Layer",
        contents: GeoDrawer.Content.content(for: geoJSON, style: .init(color: color)),
        color: color
      ))
    }
    
    func zoom(to layer: Layer?) {
      guard let layer else {
        zoomTo = nil
        return
      }
      
      let positions = layer.contents.reduce(into: [GeoJSON.Position]()) { acc, next in
        switch next {
        case .circle(let position, _, _, _, _):
          acc.append(position)
        case .line(let line, _, _):
          acc.append(contentsOf: line.positions)
        case .polygon(let polygon, _, _, _):
          acc.append(contentsOf: polygon.exterior.positions)
        case .baseMap:
          break
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
    case .line(let lineString, _, let strokeWidth):
      return .line(lineString, stroke: color, strokeWidth: strokeWidth)
    case .polygon(let polygon, _, _, let strokeWidth):
      return .polygon(polygon, fill: color, strokeWidth: strokeWidth)
    case .circle(let position, let radius, _, _, let strokeWidth):
      return .circle(position, radius: radius, fill: color, strokeWidth: strokeWidth)
    case .baseMap:
      return self
    }
  }

}

// MARK: - Blue Marble base map

/// Loads NASA's Blue Marble Next Generation 2004-08 composite from the bundled
/// asset catalogue. Source: https://science.nasa.gov/earth/earth-observatory/blue-marble-next-generation/base-map/
enum BlueMarble {
  static let assetName = "world.200408.3x5400x2700"

  static func load() -> GeoDrawer.BaseMap? {
#if canImport(UIKit)
    guard let image = UIImage(named: assetName) else { return nil }
    return GeoDrawer.BaseMap(uiImage: image, sampling: .bilinear, alpha: 1.0)
#elseif canImport(AppKit)
    guard let image = NSImage(named: assetName) else { return nil }
    return GeoDrawer.BaseMap(nsImage: image, sampling: .bilinear, alpha: 1.0)
#else
    return nil
#endif
  }
}
