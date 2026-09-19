//
//  URLTemplateTileSource.swift
//
//
//  Created by Adrian Schönig on 10/5/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@preconcurrency import GeoProjector

/// A `TileSource` that fetches tiles over HTTP from a URL template.
///
/// The template uses `{z}`, `{x}`, and `{y}` placeholders, matching the
/// XYZ slippy-map convention. Examples:
///
///     "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
///     "https://api.maptiler.com/maps/satellite/{z}/{x}/{y}.jpg?key=…"
///
/// Image decoding is performed by a caller-supplied closure so the type is
/// platform-agnostic. On Apple platforms a CoreGraphics-backed default is
/// available as `TileImage.coreGraphicsDecoder`; on Linux pass your own
/// (e.g. wrapping `swift-png`).
///
/// Most public tile servers require a meaningful `User-Agent` header
/// identifying your application — OSM in particular returns HTTP 429 for
/// requests without one. Pass `userAgent` to set it.
public struct URLTemplateTileSource: TileSource, @unchecked Sendable {

  public let template: String
  public let projection: any Projection
  public let tileSize: Int
  public let minZoom: Int
  public let maxZoom: Int
  public let attribution: String?

  /// The URL template uniquely identifies the tile content for caching
  /// purposes (assuming differing `{z}/{x}/{y}` substitutions return
  /// distinct images).
  public var tileSourceID: AnyHashable { template }

  private let userAgent: String?
  private let urlSession: URLSession
  private let decoder: @Sendable (Data) throws -> TileImage?

  public init(
    template: String,
    projection: any Projection,
    tileSize: Int = 256,
    minZoom: Int = 0,
    maxZoom: Int = 19,
    attribution: String? = nil,
    userAgent: String? = nil,
    urlSession: URLSession = .shared,
    decoder: @escaping @Sendable (Data) throws -> TileImage?
  ) {
    self.template = template
    self.projection = projection
    self.tileSize = tileSize
    self.minZoom = minZoom
    self.maxZoom = maxZoom
    self.attribution = attribution
    self.userAgent = userAgent
    self.urlSession = urlSession
    self.decoder = decoder
  }

#if canImport(CoreGraphics)
  /// Apple-platform convenience: defaults the decoder to
  /// `TileImage.coreGraphicsDecoder` and the projection to Web Mercator.
  public init(
    template: String,
    projection: any Projection = Projections.Mercator(),
    tileSize: Int = 256,
    minZoom: Int = 0,
    maxZoom: Int = 19,
    attribution: String? = nil,
    userAgent: String? = nil,
    urlSession: URLSession = .shared
  ) {
    self.init(
      template: template,
      projection: projection,
      tileSize: tileSize,
      minZoom: minZoom,
      maxZoom: maxZoom,
      attribution: attribution,
      userAgent: userAgent,
      urlSession: urlSession,
      decoder: TileImage.coreGraphicsDecoder
    )
  }
#endif

  public func tile(for key: TileKey) async throws -> TileImage? {
    guard contains(key) else { return nil }
    guard let url = url(for: key) else {
      throw URLTemplateTileSourceError.invalidTemplate(template)
    }

    var request = URLRequest(url: url)
    if let userAgent {
      request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    }

    let (data, response) = try await fetchData(for: request)

    if let http = response as? HTTPURLResponse {
      if http.statusCode == 404 {
        return nil
      }
      guard (200..<300).contains(http.statusCode) else {
        throw URLTemplateTileSourceError.httpStatus(http.statusCode, key: key)
      }
    }

    return try decoder(data)
  }

  /// Modern path uses `URLSession.data(for:)`. Linux toolchains older
  /// than Swift 6.0 didn't ship that async overload on
  /// `swift-corelibs-foundation`, so for those we fall back to a
  /// continuation wrapped around `dataTask(with:completionHandler:)` —
  /// same effect, just gluing the closure-based API onto async/await.
#if !canImport(FoundationNetworking) || swift(>=6.0)
  private func fetchData(for request: URLRequest) async throws -> (Data, URLResponse) {
    try await urlSession.data(for: request)
  }
#else
  private func fetchData(for request: URLRequest) async throws -> (Data, URLResponse) {
    try await withCheckedThrowingContinuation { continuation in
      let task = urlSession.dataTask(with: request) { data, response, error in
        if let error {
          continuation.resume(throwing: error)
        } else if let data, let response {
          continuation.resume(returning: (data, response))
        } else {
          continuation.resume(throwing: URLError(.zeroByteResource))
        }
      }
      task.resume()
    }
  }
#endif

  private func url(for key: TileKey) -> URL? {
    let expanded = template
      .replacingOccurrences(of: "{z}", with: String(key.z))
      .replacingOccurrences(of: "{x}", with: String(key.x))
      .replacingOccurrences(of: "{y}", with: String(key.y))
    return URL(string: expanded)
  }
}

public enum URLTemplateTileSourceError: Error, Equatable {
  case invalidTemplate(String)
  case httpStatus(Int, key: TileKey)
}
