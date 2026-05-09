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

    @Published var showBaseMap: Bool = false

    /// Lazily-built procedural equirectangular texture, used to demonstrate
    /// the base-map drawing path without bundling a real-world raster like
    /// NASA Blue Marble. Building it on demand keeps app launch instant.
    private var _proceduralBaseMap: GeoDrawer.BaseMap?
    var baseMap: GeoDrawer.BaseMap? {
      guard showBaseMap else { return nil }
      if _proceduralBaseMap == nil {
        _proceduralBaseMap = ProceduralBaseMap.make()
      }
      return _proceduralBaseMap
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

// MARK: - Procedural base map

/// Synthesises an equirectangular bitmap suitable for use as a base map
/// without bundling a real-world raster. Cosines of lat/lon produce
/// continent-ish blobs that read clearly across projections, with a 15°
/// graticule to make any UV-flip / antimeridian-seam / pole-stretch bug
/// immediately obvious.
enum ProceduralBaseMap {

  static func make(width: Int = 720, height: Int = 360) -> GeoDrawer.BaseMap? {
    let bytesPerRow = width * 4
    let totalBytes = bytesPerRow * height
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: totalBytes)
    buffer.initialize(repeating: 0, count: totalBytes)

    for y in 0..<height {
      let latRad = (.pi / 2) - (Double(y) + 0.5) / Double(height) * .pi
      let latDeg = latRad * 180 / .pi
      let absLat = abs(latDeg)
      let band: Band = absLat > 75 ? .iceCap
        : absLat > 60 ? .tundra
        : absLat > 25 ? .temperate
        : absLat > 8  ? .desert
        : .tropical

      for x in 0..<width {
        let lonRad = (Double(x) + 0.5) / Double(width) * 2 * .pi - .pi
        let lonDeg = lonRad * 180 / .pi

        let isLand = band != .iceCap && Self.landMask(latDeg: latDeg, lonDeg: lonDeg)
        var rgb: (UInt8, UInt8, UInt8)
        if band == .iceCap {
          rgb = (240, 240, 245)
        } else if isLand {
          rgb = band.land
        } else {
          rgb = band.ocean
        }

        if Self.onGraticule(latDeg: latDeg, lonDeg: lonDeg) {
          rgb = (UInt8(Int(rgb.0) * 3 / 4), UInt8(Int(rgb.1) * 3 / 4), UInt8(Int(rgb.2) * 3 / 4))
        }

        let off = y * bytesPerRow + x * 4
        buffer[off + 0] = rgb.0
        buffer[off + 1] = rgb.1
        buffer[off + 2] = rgb.2
        buffer[off + 3] = 255
      }
    }

    let cs = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let provider = CGDataProvider(
      dataInfo: nil,
      data: buffer,
      size: totalBytes,
      releaseData: { _, ptr, _ in ptr.deallocate() }
    ),
    let cgImage = CGImage(
      width: width, height: height,
      bitsPerComponent: 8, bitsPerPixel: 32,
      bytesPerRow: bytesPerRow,
      space: cs,
      bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
      provider: provider,
      decode: nil,
      shouldInterpolate: false,
      intent: .defaultIntent
    ) else {
      buffer.deallocate()
      return nil
    }

    return GeoDrawer.BaseMap(cgImage: cgImage, sampling: .bilinear, alpha: 1.0)
  }

  private enum Band {
    case iceCap, tundra, temperate, desert, tropical
    var land: (UInt8, UInt8, UInt8) {
      switch self {
      case .iceCap:    return (240, 240, 245)
      case .tundra:    return (190, 200, 180)
      case .temperate: return (110, 150, 90)
      case .desert:    return (210, 190, 140)
      case .tropical:  return (60, 130, 70)
      }
    }
    var ocean: (UInt8, UInt8, UInt8) {
      switch self {
      case .iceCap:    return (200, 220, 230)
      case .tundra:    return (60, 90, 130)
      case .temperate: return (40, 80, 140)
      case .desert:    return (35, 70, 130)
      case .tropical:  return (30, 80, 150)
      }
    }
  }

  private static func landMask(latDeg: Double, lonDeg: Double) -> Bool {
    let lat = latDeg * .pi / 180
    let lon = lonDeg * .pi / 180
    let v = sin(lon * 1.5) * cos(lat * 0.7)
          + sin(lon * 0.7 + 1.2) * cos(lat * 1.5 + 0.3)
          + 0.6 * sin(lon * 3 + 0.5) * cos(lat * 2)
    return v > 0.4
  }

  private static func onGraticule(latDeg: Double, lonDeg: Double) -> Bool {
    let latStep = 15.0
    let lonStep = 15.0
    let thresh = 0.5
    let latRem = abs(latDeg.truncatingRemainder(dividingBy: latStep))
    let lonRem = abs(lonDeg.truncatingRemainder(dividingBy: lonStep))
    return latRem < thresh || latRem > latStep - thresh
        || lonRem < thresh || lonRem > lonStep - thresh
  }
}
