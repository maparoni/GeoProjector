//
//  TileSourceTests.swift
//
//
//  Created by Adrian Schönig on 10/5/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

#if canImport(Testing)

import Testing
import Foundation

#if canImport(CoreGraphics) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
#endif

@testable import GeoDrawer
import GeoProjector

struct TileSourceTests {

  // MARK: - Helpers

  /// 4×4 tile filled with one solid colour. Premultiplied RGBA.
  private static func solidTile(_ rgba: (UInt8, UInt8, UInt8, UInt8)) -> TileImage {
    var pixels = [UInt8](repeating: 0, count: 4 * 4 * 4)
    for i in stride(from: 0, to: pixels.count, by: 4) {
      pixels[i + 0] = rgba.0
      pixels[i + 1] = rgba.1
      pixels[i + 2] = rgba.2
      pixels[i + 3] = rgba.3
    }
    return TileImage(width: 4, height: 4, pixels: pixels)
  }

  // MARK: - Tests

  @Test func staticSource_returnsTileForKnownKey() async throws {
    let red = Self.solidTile((255, 0, 0, 255))
    let source = StaticTileSource(
      projection: Projections.Mercator(),
      tileSize: 4,
      tiles: [TileKey(z: 0, x: 0, y: 0): red]
    )
    let fetched = try await source.tile(for: TileKey(z: 0, x: 0, y: 0))
    let tile = try #require(fetched)
    #expect(tile.width == 4)
    #expect(tile.height == 4)
    #expect(tile.pixels[0] == 255)
    #expect(tile.pixels[3] == 255)
  }

  @Test func staticSource_missingKey_returnsNil() async throws {
    let source = StaticTileSource(
      projection: Projections.Mercator(),
      tileSize: 4,
      tiles: [TileKey(z: 0, x: 0, y: 0): Self.solidTile((1, 2, 3, 255))]
    )
    let fetched = try await source.tile(for: TileKey(z: 0, x: 1, y: 0))
    #expect(fetched == nil)
  }

  @Test func staticSource_zoomRangeReflectsKeys() {
    let source = StaticTileSource(
      projection: Projections.Mercator(),
      tileSize: 4,
      tiles: [
        TileKey(z: 0, x: 0, y: 0): Self.solidTile((1, 1, 1, 255)),
        TileKey(z: 2, x: 1, y: 2): Self.solidTile((2, 2, 2, 255)),
        TileKey(z: 3, x: 7, y: 7): Self.solidTile((3, 3, 3, 255)),
      ]
    )
    #expect(source.minZoom == 0)
    #expect(source.maxZoom == 3)
  }

#if canImport(CoreGraphics) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
  @Test func coreGraphicsDecoder_roundTripsPNG() throws {
    // Build a 4×4 image: top half red, bottom half blue.
    let w = 4, h = 4
    let bytesPerRow = w * 4
    var raw = [UInt8](repeating: 0, count: bytesPerRow * h)
    for y in 0..<h {
      for x in 0..<w {
        let off = y * bytesPerRow + x * 4
        if y < 2 {
          raw[off + 0] = 255; raw[off + 3] = 255  // red
        } else {
          raw[off + 2] = 255; raw[off + 3] = 255  // blue
        }
      }
    }

    let cs = CGColorSpaceCreateDeviceRGB()
    let context = try #require(raw.withUnsafeMutableBufferPointer { ptr -> CGContext? in
      CGContext(
        data: ptr.baseAddress, width: w, height: h,
        bitsPerComponent: 8, bytesPerRow: bytesPerRow,
        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    })
    let cgImage = try #require(context.makeImage())

    let pngData = NSMutableData()
    let dest = try #require(CGImageDestinationCreateWithData(
      pngData, UTType.png.identifier as CFString, 1, nil
    ))
    CGImageDestinationAddImage(dest, cgImage, nil)
    #expect(CGImageDestinationFinalize(dest))

    let tile = try #require(try TileImage.coreGraphicsDecoder(pngData as Data))
    #expect(tile.width == 4)
    #expect(tile.height == 4)

    // Top row (y=0) should be red, bottom row (y=3) should be blue.
    #expect(tile.pixels[0 * bytesPerRow + 0 * 4 + 0] == 255)
    #expect(tile.pixels[0 * bytesPerRow + 0 * 4 + 2] == 0)
    #expect(tile.pixels[3 * bytesPerRow + 0 * 4 + 0] == 0)
    #expect(tile.pixels[3 * bytesPerRow + 0 * 4 + 2] == 255)
  }

  @Test func coreGraphicsDecoder_returnsNilForGarbage() throws {
    let garbage = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05])
    let result = try TileImage.coreGraphicsDecoder(garbage)
    #expect(result == nil)
  }
#endif

#if canImport(CoreGraphics)
  @Test func tiledBaseMap_autoZoom_picksLevelMatchingCanvas() throws {
    // tileSize=256, source supports z=0..10. Auto-zoom should pick:
    //   round(log2(canvasMax / 256)).
    // 1024-pixel canvas → log2(4) = 2.
    // 800-pixel canvas → log2(800/256) = log2(3.125) ≈ 1.64 → 2.
    // 384-pixel canvas → log2(384/256) = log2(1.5) ≈ 0.58 → 1.
    let zoomLevels = (0...10).map {
      TileKey(z: $0, x: 0, y: 0)
    }
    let dummyTiles = Dictionary(uniqueKeysWithValues: zoomLevels.map { key in
      let pixels = [UInt8](repeating: 0, count: 256 * 256 * 4)
      return (key, TileImage(width: 256, height: 256, pixels: pixels))
    })
    let source = StaticTileSource(
      projection: Projections.Mercator(),
      tileSize: 256,
      tiles: dummyTiles
    )
    let auto = GeoDrawer.TiledBaseMap(source: source)  // .auto

    let cases: [(canvas: Double, expectedZoom: Int)] = [
      (1024, 2),
      (800, 2),
      (384, 1),
    ]
    for (canvas, expected) in cases {
      let drawer = GeoDrawer(
        size: .init(width: canvas, height: canvas),
        projection: Projections.Mercator()
      )
      #expect(drawer.resolvedZoom(auto.zoom, source: source) == expected,
              "canvas=\(canvas) → expected z=\(expected)")
    }
  }

  @Test func tiledBaseMap_autoZoom_clampsToSourceRange() throws {
    let dummy = TileImage(width: 256, height: 256, pixels: [UInt8](repeating: 0, count: 256 * 256 * 4))
    let source = StaticTileSource(
      projection: Projections.Mercator(),
      tileSize: 256,
      tiles: [
        TileKey(z: 3, x: 0, y: 0): dummy,
        TileKey(z: 4, x: 0, y: 0): dummy,
      ]
    )
    let auto = GeoDrawer.TiledBaseMap(source: source)
    // Tiny canvas would suggest z<3, but source minZoom is 3.
    let smallDrawer = GeoDrawer(size: .init(width: 64, height: 64), projection: Projections.Mercator())
    #expect(smallDrawer.resolvedZoom(auto.zoom, source: source) == 3)
    // Huge canvas would suggest z>4, but source maxZoom is 4.
    let bigDrawer = GeoDrawer(size: .init(width: 16384, height: 16384), projection: Projections.Mercator())
    #expect(bigDrawer.resolvedZoom(auto.zoom, source: source) == 4)
  }
#endif

  @Test func contains_rejectsOutOfRangeZoomAndCoords() {
    let source = StaticTileSource(
      projection: Projections.Mercator(),
      tileSize: 4,
      tiles: [
        TileKey(z: 1, x: 0, y: 0): Self.solidTile((1, 1, 1, 255)),
        TileKey(z: 2, x: 0, y: 0): Self.solidTile((2, 2, 2, 255)),
      ]
    )
    // Zoom in supported range, valid (x,y).
    #expect(source.contains(TileKey(z: 1, x: 1, y: 1)))
    #expect(source.contains(TileKey(z: 2, x: 3, y: 3)))
    // Out of zoom range.
    #expect(source.contains(TileKey(z: 0, x: 0, y: 0)) == false)
    #expect(source.contains(TileKey(z: 3, x: 0, y: 0)) == false)
    // Out of grid range at zoom 1 (2×2 tiles → max coord 1).
    #expect(source.contains(TileKey(z: 1, x: 2, y: 0)) == false)
    #expect(source.contains(TileKey(z: 1, x: 0, y: -1)) == false)
  }
}

#endif
