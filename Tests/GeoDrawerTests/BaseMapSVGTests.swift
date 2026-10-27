//
//  BaseMapSVGTests.swift
//
//
//  Created by Adrian Schönig on 28/10/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

#if canImport(Testing)

import Testing
import Foundation

import GeoJSONKit
@testable import GeoDrawer
import GeoProjector

/// Renders a single-image base map to SVG without CoreGraphics: a synthetic
/// equirectangular image gets sampled through the pure-Swift inverse
/// projection, encoded as PNG and embedded as an `<image>` beneath the
/// vector content. Runs on Linux and Apple platforms alike.
struct BaseMapSVGTests {

  private static let red: [UInt8] = [255, 0, 0, 255]
  private static let blue: [UInt8] = [0, 0, 255, 255]
  private static let green: [UInt8] = [0, 255, 0, 255]
  private static let yellow: [UInt8] = [255, 255, 0, 255]

  /// 32×16 equirectangular image: north-west red, north-east blue,
  /// south-west green, south-east yellow.
  private static func quadrantImage() -> GeoDrawer.BaseMapImage {
    let width = 32
    let height = 16
    var pixels = [UInt8]()
    pixels.reserveCapacity(width * height * 4)
    for y in 0..<height {
      for x in 0..<width {
        switch (x < width / 2, y < height / 2) {
        case (true, true): pixels += red
        case (false, true): pixels += blue
        case (true, false): pixels += green
        case (false, false): pixels += yellow
        }
      }
    }
    return GeoDrawer.BaseMapImage(width: width, height: height, pixels: pixels)!
  }

  private static func embeddedBitmap(in svg: String) throws -> GeoDrawer.RasterBitmap {
    let base64 = try #require(dataURIPayload(in: svg))
    let png = try #require(Data(base64Encoded: base64))
    return try #require(try PNGCodec.decode(png))
  }

  private static func dataURIPayload(in svg: String) -> String? {
    guard let start = svg.range(of: "href=\"data:image/png;base64,") else { return nil }
    let rest = svg[start.upperBound...]
    guard let end = rest.firstIndex(of: "\"") else { return nil }
    return String(rest[..<end])
  }

  private static func pixel(_ bitmap: GeoDrawer.RasterBitmap, x: Int, y: Int) -> [UInt8] {
    let off = (y * bitmap.width + x) * 4
    return Array(bitmap.pixels[off..<off + 4])
  }

  /// `GeoDrawer.Color` is `CGColor` on Apple platforms and a plain struct
  /// elsewhere; both offer this initialiser.
  private static func color(red: Double, green: Double, blue: Double) -> GeoDrawer.Color {
    .init(red: red, green: green, blue: blue, alpha: 1)
  }

  @Test func orthographicGlobeSamplesQuadrantsAndLeavesCornersClear() throws {
    let baseMap = GeoDrawer.BaseMap(image: Self.quadrantImage(), sampling: .nearest)
    let drawer = GeoDrawer(
      size: .init(width: 100, height: 100),
      projection: Projections.Orthographic()
    )
    let prime = GeoJSON.LineString(positions: [
      .init(latitude: -60, longitude: 0), .init(latitude: 60, longitude: 0),
    ])
    let contents: [GeoDrawer.Content] = [
      .baseMap(baseMap),
      .line(prime, stroke: Self.color(red: 0, green: 0, blue: 0), strokeWidth: 1),
    ]

    let svg = drawer.drawSVG(contents)

    // One <image> with a PNG data URI, before the vector path.
    #expect(svg.components(separatedBy: "<image ").count == 2)
    #expect(svg.contains("xmlns:xlink=\"http://www.w3.org/1999/xlink\""))
    #expect(svg.contains("width=\"100.0\" height=\"100.0\" preserveAspectRatio=\"none\""))
    let imageRange = try #require(svg.range(of: "<image "))
    let pathRange = try #require(svg.range(of: "<path "))
    #expect(imageRange.lowerBound < pathRange.lowerBound)

    let bitmap = try Self.embeddedBitmap(in: svg)
    #expect(bitmap.width == 100)
    #expect(bitmap.height == 100)

    // The globe fills the canvas; the disk centre is (0°, 0°). A point a
    // quarter of the way towards each edge inverse-projects to the
    // matching hemisphere pair of the source image.
    #expect(Self.pixel(bitmap, x: 30, y: 30) == Self.red)     // NW
    #expect(Self.pixel(bitmap, x: 70, y: 30) == Self.blue)    // NE
    #expect(Self.pixel(bitmap, x: 30, y: 70) == Self.green)   // SW
    #expect(Self.pixel(bitmap, x: 70, y: 70) == Self.yellow)  // SE

    // Outside the disk the raster is transparent.
    #expect(Self.pixel(bitmap, x: 2, y: 2)[3] == 0)
    #expect(Self.pixel(bitmap, x: 97, y: 97)[3] == 0)
  }

  @Test func mercatorSheetSamplesQuadrants() throws {
    let baseMap = GeoDrawer.BaseMap(image: Self.quadrantImage(), sampling: .nearest)
    let drawer = GeoDrawer(
      size: .init(width: 32, height: 32),
      projection: Projections.Mercator()
    )

    let svg = drawer.drawSVG([.baseMap(baseMap)])
    let bitmap = try Self.embeddedBitmap(in: svg)
    #expect(bitmap.width == 32)
    #expect(bitmap.height == 32)

    // Row 16 is the equator in Mercator; rows above are north.
    #expect(Self.pixel(bitmap, x: 4, y: 8) == Self.red)
    #expect(Self.pixel(bitmap, x: 27, y: 8) == Self.blue)
    #expect(Self.pixel(bitmap, x: 4, y: 24) == Self.green)
    #expect(Self.pixel(bitmap, x: 27, y: 24) == Self.yellow)
  }

  /// An equirectangular map of an equirectangular image takes the direct
  /// path; it must give the round trip's pixels, re-centred and zoomed in.
  @Test(arguments: [0.0, 2.8])
  func equirectangularDirectPathMatchesTheRoundTrip(centreLongitude: Double) throws {
    let box = GeoJSON.BoundingBox(positions: [
      .init(latitude: -40, longitude: 150), .init(latitude: 10, longitude: -170),
    ])
    let drawer = GeoDrawer(
      size: .init(width: 48, height: 40),
      projection: Projections.Equirectangular(reference: .init(x: centreLongitude, y: -0.4)),
      zoomTo: box
    )
    #expect(drawer.projection!.cylindricalTransform(to: Projections.Equirectangular()) != nil)

    for sampling in [GeoDrawer.Sampling.nearest, .bilinear] {
      let baseMap = GeoDrawer.BaseMap(
        image: Self.quadrantImage(), sourceProjection: Projections.Equirectangular(), sampling: sampling)
      let direct = try #require(drawer.renderBaseMapBitmap(baseMap))
      let roundTrip = try #require(drawer.renderBaseMapBitmap(baseMap, allowDirect: false))
      #expect(direct.pixels.contains { $0 != 0 })
      let pixelCount = direct.width * direct.height
      let differing = (0..<pixelCount).filter { i in
        (0..<4).contains { abs(Int(direct.pixels[i * 4 + $0]) - Int(roundTrip.pixels[i * 4 + $0])) > 1 }
      }.count
      // As for tiles: nearest may round one row or column of edge-aligned
      // pixel centres the other way.
      #expect(differing <= max(direct.width, direct.height), "\(sampling): \(differing) of \(pixelCount) pixels differ")
    }
  }

  @Test func pixelDensityScalesTheEmbeddedRaster() throws {
    let baseMap = GeoDrawer.BaseMap(image: Self.quadrantImage(), sampling: .nearest, alpha: 0.5)
    var drawer = GeoDrawer(
      size: .init(width: 20, height: 10),
      projection: Projections.Equirectangular()
    )
    drawer.pixelDensity = 2

    let svg = drawer.drawSVG([.baseMap(baseMap)])
    // Drawn at point size, backed by a raster at twice that.
    #expect(svg.contains("width=\"20.0\" height=\"10.0\" preserveAspectRatio=\"none\""))
    let bitmap = try Self.embeddedBitmap(in: svg)
    #expect(bitmap.width == 40)
    #expect(bitmap.height == 20)
    // The PNG round trip un-premultiplies and the decoder re-premultiplies,
    // so a half-alpha red lands back at (128, 0, 0, 128) give or take one.
    let nw = Self.pixel(bitmap, x: 10, y: 5)
    #expect(abs(Int(nw[0]) - 128) <= 1)
    #expect(nw[1] == 0 && nw[2] == 0)
    #expect(abs(Int(nw[3]) - 128) <= 1)
  }

  @Test func baseMapImageDecodesPNGOnEveryPlatform() throws {
    let source = GeoDrawer.RasterBitmap(
      width: 2, height: 1,
      pixels: Self.red + Self.blue
    )
    let image = try #require(try GeoDrawer.BaseMapImage.decode(pngData: source.pngData()))
    #expect(image.width == 2)
    #expect(image.height == 1)
    #expect(Array(image.pixels) == Self.red + Self.blue)

    // Not a PNG: nil rather than an error, like `TileImage.pngDecoder`.
    #expect(try GeoDrawer.BaseMapImage.decode(pngData: Data([1, 2, 3, 4, 5, 6, 7, 8, 9])) == nil)
    #expect(try GeoDrawer.BaseMap(pngData: Data([1, 2, 3, 4, 5, 6, 7, 8, 9])) == nil)
  }
}

#endif
