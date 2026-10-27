//
//  TiledBaseMapSVGTests.swift
//
//
//  Created by Adrian Schönig on 27/10/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

#if canImport(Testing)

import Testing
import Foundation

import GeoJSONKit
@testable import GeoDrawer
import GeoProjector

/// Renders a tiled base map to SVG without CoreGraphics: tiles come from a
/// `StaticTileSource`, get composited by the pure-Swift sampler, encoded
/// as PNG and embedded as an `<image>` beneath the vector content.
struct TiledBaseMapSVGTests {

  private static let tileSize = 8

  /// Solid-colour tile, premultiplied RGBA.
  private static func solidTile(_ rgba: (UInt8, UInt8, UInt8, UInt8)) -> TileImage {
    var pixels = [UInt8](repeating: 0, count: tileSize * tileSize * 4)
    for i in stride(from: 0, to: pixels.count, by: 4) {
      pixels[i + 0] = rgba.0
      pixels[i + 1] = rgba.1
      pixels[i + 2] = rgba.2
      pixels[i + 3] = rgba.3
    }
    return TileImage(width: tileSize, height: tileSize, pixels: pixels)
  }

  /// Zoom 1 Web Mercator grid: west tiles red, east tiles blue.
  private static func source() -> StaticTileSource {
    StaticTileSource(
      projection: Projections.Mercator(),
      tileSize: tileSize,
      tiles: [
        TileKey(z: 1, x: 0, y: 0): solidTile((255, 0, 0, 255)),
        TileKey(z: 1, x: 0, y: 1): solidTile((255, 0, 0, 255)),
        TileKey(z: 1, x: 1, y: 0): solidTile((0, 0, 255, 255)),
        TileKey(z: 1, x: 1, y: 1): solidTile((0, 0, 255, 255)),
      ]
    )
  }

  /// `GeoDrawer.Color` is `CGColor` on Apple platforms and a plain struct
  /// elsewhere; both offer this initialiser.
  private static func color(red: Double, green: Double, blue: Double) -> GeoDrawer.Color {
    .init(red: red, green: green, blue: blue, alpha: 1)
  }

  @Test func svgEmbedsTiledBaseMapBeneathVectors() async throws {
    let drawer = GeoDrawer(
      size: .init(width: 32, height: 32),
      projection: Projections.Mercator()
    )
    let equator = GeoJSON.LineString(positions: [
      .init(latitude: 0, longitude: -90),
      .init(latitude: 0, longitude: 90),
    ])
    let contents: [GeoDrawer.Content] = [
      .line(equator, stroke: Self.color(red: 0, green: 1, blue: 0), strokeWidth: 2),
      .tiledBaseMap(.init(source: Self.source(), zoom: 1, sampling: .nearest)),
    ]

    await drawer.prefetchTiles(for: contents)
    let svg = drawer.drawSVG(contents)

    // One <image> with a PNG data URI, declared with the xlink namespace.
    let imageRange = try #require(svg.range(of: "<image "))
    #expect(svg.components(separatedBy: "<image ").count == 2)
    #expect(svg.contains("xmlns:xlink=\"http://www.w3.org/1999/xlink\""))
    #expect(svg.contains("href=\"data:image/png;base64,"))
    #expect(svg.contains("width=\"32.0\" height=\"32.0\" preserveAspectRatio=\"none\""))

    // The vector content is still there, and draws after (on top of) the image.
    let pathRange = try #require(svg.range(of: "<path "))
    #expect(imageRange.lowerBound < pathRange.lowerBound)
    #expect(svg.contains("stroke=\"#00FF00\""))

    // Decode the embedded PNG and check the tiles landed on the right side.
    let base64 = try #require(Self.dataURIPayload(in: svg))
    let png = try #require(Data(base64Encoded: base64))
    let bitmap = try #require(try PNGCodec.decode(png))
    #expect(bitmap.width == 32)
    #expect(bitmap.height == 32)
    // Row 16 (equator), column 4 (west) → red; column 27 (east) → blue.
    let west = bitmap.pixels[(16 * 32 + 4) * 4..<(16 * 32 + 4) * 4 + 4]
    let east = bitmap.pixels[(16 * 32 + 27) * 4..<(16 * 32 + 27) * 4 + 4]
    #expect(Array(west) == [255, 0, 0, 255])
    #expect(Array(east) == [0, 0, 255, 255])
  }

  @Test func svgOmitsImageWhenNoTilesFetched() {
    let drawer = GeoDrawer(
      size: .init(width: 16, height: 16),
      projection: Projections.Mercator()
    )
    let contents: [GeoDrawer.Content] = [
      .tiledBaseMap(.init(source: Self.source(), zoom: 1))
    ]
    // No prefetch: the compositor finds no tiles and the raster is fully
    // transparent, but the element is still emitted.
    let svg = drawer.drawSVG(contents)
    #expect(svg.contains("<image "))
  }

  /// Street-level zooms have a 2^z × 2^z tile grid; the compositor must
  /// only touch the tiles that were fetched, or a single render takes
  /// minutes. A 64×64 canvas zoomed to a few blocks of Sydney at zoom 16.
  @Test(.timeLimit(.minutes(1))) func streetLevelZoomRendersQuickly() async throws {
    let box = GeoJSON.BoundingBox(positions: [
      .init(latitude: -33.875, longitude: 151.20), .init(latitude: -33.86, longitude: 151.22),
    ])
    let drawer = GeoDrawer(size: .init(width: 64, height: 64), projection: Projections.Mercator(), zoomTo: box)

    // Provide exactly the tiles the drawer needs at zoom 16, all green.
    let probe = StaticTileSource(
      projection: Projections.Mercator(), tileSize: Self.tileSize,
      tiles: [TileKey(z: 16, x: 0, y: 0): Self.solidTile((0, 0, 0, 0))]
    )
    let needed = drawer.tilesNeeded(for: .init(source: probe, zoom: 16))
    #expect(needed.count > 0 && needed.count < 200)
    let tiles = Dictionary(uniqueKeysWithValues: needed.map { ($0, Self.solidTile((0, 128, 0, 255))) })
    let source = StaticTileSource(projection: Projections.Mercator(), tileSize: Self.tileSize, tiles: tiles)
    let contents: [GeoDrawer.Content] = [.tiledBaseMap(.init(source: source, zoom: 16, sampling: .nearest))]
    await drawer.prefetchTiles(for: contents)

    let start = Date()
    let svg = drawer.drawSVG(contents)
    #expect(Date().timeIntervalSince(start) < 5)

    let base64 = try #require(Self.dataURIPayload(in: svg))
    let png = try #require(Data(base64Encoded: base64))
    let bitmap = try #require(try PNGCodec.decode(png))
    let centre = bitmap.pixels[(32 * 64 + 32) * 4..<(32 * 64 + 32) * 4 + 4]
    #expect(Array(centre) == [0, 128, 0, 255])
  }

  @Test func pngCodecRoundTripsPremultipliedAlpha() throws {
    // 2×1: opaque red, then 50% green (premultiplied: 0,128,0,128).
    let bitmap = GeoDrawer.RasterBitmap(
      width: 2, height: 1,
      pixels: [255, 0, 0, 255, 0, 128, 0, 128]
    )
    let png = bitmap.pngData()
    #expect(png.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    let decoded = try #require(try PNGCodec.decode(png))
    #expect(decoded.pixels == [255, 0, 0, 255, 0, 128, 0, 128])
  }

  @Test func pngDecoderReturnsNilForGarbage() throws {
    let garbage = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
    #expect(try TileImage.pngDecoder(garbage) == nil)
  }

  private static func dataURIPayload(in svg: String) -> String? {
    guard let start = svg.range(of: "href=\"data:image/png;base64,") else { return nil }
    let rest = svg[start.upperBound...]
    guard let end = rest.firstIndex(of: "\"") else { return nil }
    return String(rest[..<end])
  }
}

#endif
