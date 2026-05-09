//
//  StaticTileSource.swift
//
//
//  Created by Adrian Schönig on 10/5/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

import Foundation

import GeoProjector

/// A `TileSource` backed by an in-memory dictionary of pre-decoded tiles.
///
/// Use this for static high-resolution imagery you can fully load at
/// startup — for example, NASA's Blue Marble Next Generation 21600×10800
/// composite split into a 16×8 grid of 1350×1350 tiles, decoded once and
/// kept resident. Also handy for tests, where you want deterministic tile
/// content without touching the network.
///
/// All zoom levels present in the supplied dictionary are supported;
/// `minZoom`/`maxZoom` are computed from the keys. If the dictionary is
/// empty, both default to `0`.
public struct StaticTileSource: TileSource {

  public let projection: any Projection
  public let tileSize: Int
  public let minZoom: Int
  public let maxZoom: Int

  private let tiles: [TileKey: TileImage]

  public init(
    projection: any Projection,
    tileSize: Int,
    tiles: [TileKey: TileImage]
  ) {
    self.projection = projection
    self.tileSize = tileSize
    self.tiles = tiles
    let zooms = tiles.keys.map(\.z)
    self.minZoom = zooms.min() ?? 0
    self.maxZoom = zooms.max() ?? 0
  }

  public func tile(for key: TileKey) async throws -> TileImage? {
    tiles[key]
  }
}
