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
