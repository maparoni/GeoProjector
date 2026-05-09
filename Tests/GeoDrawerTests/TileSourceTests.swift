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
