//
//  TileSource.swift
//
//
//  Created by Adrian Schönig on 10/5/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

import Foundation

@preconcurrency import GeoProjector

/// Identifies a single tile in an XYZ ("slippy map") tile scheme.
///
/// At zoom `z` the source is divided into `2^z × 2^z` tiles. `(x, y)` is the
/// tile position within that grid, with `(0, 0)` at the top-left
/// (north-west) corner; `y` increases southward, matching OpenStreetMap,
/// Google Maps, MapTiler, and most Web Mercator services. Static
/// (non-zoomable) tile sets use `z = 0` and pack the world into a single
/// row or column at that level.
public struct TileKey: Hashable, Sendable {
  public let z: Int
  public let x: Int
  public let y: Int

  public init(z: Int, x: Int, y: Int) {
    self.z = z
    self.x = x
    self.y = y
  }
}

extension TileKey: CustomStringConvertible {
  public var description: String { "\(z)/\(x)/\(y)" }
}

/// A pre-decoded tile bitmap. RGBA8 premultiplied, row-major, with row 0
/// at the visual top of the tile (XYZ convention). The pixel buffer
/// length must be exactly `width * height * 4`.
public struct TileImage: Sendable, Hashable {
  public let width: Int
  public let height: Int
  public let pixels: [UInt8]

  public init(width: Int, height: Int, pixels: [UInt8]) {
    precondition(width > 0 && height > 0)
    precondition(pixels.count == width * height * 4,
                 "expected \(width * height * 4) RGBA bytes, got \(pixels.count)")
    self.width = width
    self.height = height
    self.pixels = pixels
  }
}

/// A pluggable source of map tiles. Implementations include slippy-map URL
/// fetchers, on-disk caches, and pre-loaded static grids for high-resolution
/// imagery like NASA Blue Marble Next Generation.
///
/// All members are read-only and `Sendable`: a `TileSource` is shared across
/// the renderer's parallel pixel-sampling tasks, and `tile(for:)` may be
/// invoked concurrently from many actors.
public protocol TileSource: Sendable {
  /// Stable identifier for this tile source. Two sources with the same
  /// `tileSourceID` are treated as interchangeable by the renderer's cache
  /// and by `Hashable`/`Equatable` checks on `Content` — so the value
  /// should be cheap to compare and uniquely identify the underlying tile
  /// data (a URL template string, a UUID generated at construction, etc.).
  var tileSourceID: AnyHashable { get }

  /// The projection that the tiles render through. Slippy-map services use
  /// Web Mercator (`Projections.Mercator`); static grids may use any
  /// projection that has a square or near-square `projectionSize` aspect.
  /// Equirectangular tile sets are supported in principle but require the
  /// caller to pick zoom levels where the `2^z × 2^z` grid divides cleanly
  /// (e.g. an equirectangular set typically has `2^z` columns and
  /// `2^(z-1)` rows; v1 doesn't model that asymmetry).
  var projection: any Projection { get }

  /// Pixel width/height of every tile. Most services serve 256×256;
  /// high-DPI variants serve 512×512.
  var tileSize: Int { get }

  /// Lowest supported zoom level (inclusive). For static grids this is the
  /// only level — set `minZoom == maxZoom`.
  var minZoom: Int { get }

  /// Highest supported zoom level (inclusive).
  var maxZoom: Int { get }

  /// Fetches and decodes the tile at `key`. Returns `nil` if the source
  /// has no data at that location (e.g. some commercial services omit
  /// ocean tiles); throws on network or decode errors. May be called
  /// concurrently from multiple tasks.
  func tile(for key: TileKey) async throws -> TileImage?
}

extension TileSource {
  /// Whether `key` is within this source's supported zoom and grid range.
  /// Useful for skipping out-of-range queries before hitting the network.
  public func contains(_ key: TileKey) -> Bool {
    guard key.z >= minZoom, key.z <= maxZoom else { return false }
    let n = 1 << key.z
    return key.x >= 0 && key.x < n && key.y >= 0 && key.y < n
  }
}

/// Snapshot of how a tile prefetch is progressing.
///
/// `total` is the count of distinct tiles the renderer needs at the
/// current canvas configuration. `loaded` includes both freshly-fetched
/// tiles and tiles already in the drawer's `TileCache` from a prior
/// call. `failed` covers network and decode errors per tile — these
/// are counted here rather than re-thrown so partial coverage still
/// renders.
///
/// Consumers (e.g. a SwiftUI overlay) typically watch `fraction` for
/// the in-progress UI and `failed` for an at-a-glance warning state.
public struct TileFetchProgress: Hashable, Sendable {
  public let total: Int
  public let loaded: Int
  public let failed: Int

  public init(total: Int, loaded: Int, failed: Int) {
    self.total = total
    self.loaded = loaded
    self.failed = failed
  }

  /// Tiles still being awaited. `max(0, …)` because `loaded + failed`
  /// is only ever >= `total` at completion.
  public var pending: Int { max(0, total - loaded - failed) }

  /// Resolved fraction in `0...1`. Failures count as resolved so the
  /// bar finishes (rather than getting stuck near 100% on a partial
  /// outage).
  public var fraction: Double {
    guard total > 0 else { return 1 }
    return Double(loaded + failed) / Double(total)
  }

  /// Every needed tile has either landed or failed.
  public var isComplete: Bool { loaded + failed >= total }
}
