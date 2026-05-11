//
//  TileCache.swift
//
//
//  Created by Adrian Schönig on 10/5/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

import Foundation

extension GeoDrawer {

  /// Pre-fetched tile storage keyed by `(sourceID, tileKey)`. Shared
  /// across drawer copies so successive renders against the same drawer
  /// don't re-fetch unchanged tiles. Owners like `GeoMapView` swap in
  /// a long-lived instance via `drawer.tileCache = sharedCache` so
  /// fetched tile bytes survive drawer recreations triggered by
  /// projection/size/zoom/insets/quality changes.
  struct TileCacheKey: Hashable, Sendable {
    let sourceID: AnyHashable
    let tileKey: TileKey
  }

  /// Thread-safe storage of pre-fetched, decoded tile bitmaps. Reads
  /// and writes are serialised by an internal `NSLock`; tile bytes
  /// themselves are immutable once stored.
  final class TileCache: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [TileCacheKey: TileImage] = [:]

    func get(_ key: TileCacheKey) -> TileImage? {
      lock.lock(); defer { lock.unlock() }
      return entries[key]
    }

    func set(_ key: TileCacheKey, _ image: TileImage) {
      lock.lock(); defer { lock.unlock() }
      entries[key] = image
    }

    func contains(_ key: TileCacheKey) -> Bool {
      lock.lock(); defer { lock.unlock() }
      return entries[key] != nil
    }
  }
}
