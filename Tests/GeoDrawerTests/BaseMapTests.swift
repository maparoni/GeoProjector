//
//  BaseMapTests.swift
//
//
//  Created by Adrian Schönig on 9/5/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

#if canImport(Testing) && canImport(CoreGraphics)

import Testing
import Foundation
import CoreGraphics

import GeoJSONKit
@testable import GeoDrawer
@testable import GeoProjector

struct BaseMapTests {

  // MARK: - Helpers

  /// Builds a synthetic equirectangular CGImage by filling each pixel from
  /// `pixel(x:y:)`. Output is RGBA8 premultiplied.
  private static func makeImage(
    width: Int,
    height: Int,
    pixel: (Int, Int) -> (UInt8, UInt8, UInt8, UInt8)
  ) -> CGImage {
    let bytesPerRow = width * 4
    let totalBytes = bytesPerRow * height
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: totalBytes)
    for y in 0..<height {
      for x in 0..<width {
        let off = y * bytesPerRow + x * 4
        let p = pixel(x, y)
        buffer[off + 0] = p.0
        buffer[off + 1] = p.1
        buffer[off + 2] = p.2
        buffer[off + 3] = p.3
      }
    }
    let cs = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    let provider = CGDataProvider(
      dataInfo: nil, data: buffer, size: totalBytes,
      releaseData: { _, ptr, _ in ptr.deallocate() }
    )!
    return CGImage(
      width: width, height: height,
      bitsPerComponent: 8, bitsPerPixel: 32,
      bytesPerRow: bytesPerRow,
      space: cs,
      bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
      provider: provider, decode: nil,
      shouldInterpolate: false, intent: .defaultIntent
    )!
  }

  /// Reads the RGBA pixel at `(x, y)` from a `CGImage` rendered by the
  /// base-map path. Returns components in 0...255 (premultiplied).
  private static func readPixel(_ image: CGImage, x: Int, y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
    let width = image.width
    let height = image.height
    let bytesPerRow = width * 4
    var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)
    let cs = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    let context = buffer.withUnsafeMutableBufferPointer { ptr -> CGContext? in
      CGContext(
        data: ptr.baseAddress,
        width: width, height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: cs,
        bitmapInfo: bitmapInfo
      )
    }!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    let off = y * bytesPerRow + x * 4
    return (buffer[off], buffer[off + 1], buffer[off + 2], buffer[off + 3])
  }

  // MARK: - Tests

  @Test func test_solidRedSource_orthographicCenter() throws {
    let source = Self.makeImage(width: 16, height: 8) { _, _ in (255, 0, 0, 255) }
    let baseMap = try #require(GeoDrawer.BaseMap(cgImage: source, sampling: .nearest))

    let drawer = GeoDrawer(
      size: .init(width: 200, height: 200),
      projection: Projections.Orthographic()
    )
    let raster = try #require(drawer.renderedBaseMap(baseMap, coordinateSystem: .topLeft))

    // Centre of the canvas projects to (0, 0) on the globe — must be red.
    let centre = Self.readPixel(raster, x: 100, y: 100)
    #expect(centre.0 > 200)
    #expect(centre.1 < 50)
    #expect(centre.2 < 50)
    #expect(centre.3 > 200)

    // A pixel well outside the disk (corner) must be transparent.
    let corner = Self.readPixel(raster, x: 5, y: 5)
    #expect(corner.3 == 0)
  }

  @Test func test_eastWestSplit_equirectangular() throws {
    // Source: left half red, right half blue. In an equirectangular
    // projection, the left half of the canvas (longitudes < 0) must be red.
    let source = Self.makeImage(width: 32, height: 16) { x, _ in
      x < 16 ? (255, 0, 0, 255) : (0, 0, 255, 255)
    }
    let baseMap = try #require(GeoDrawer.BaseMap(cgImage: source, sampling: .nearest))

    let drawer = GeoDrawer(
      size: .init(width: 200, height: 100),
      projection: Projections.Equirectangular()
    )
    let raster = try #require(drawer.renderedBaseMap(baseMap, coordinateSystem: .topLeft))

    // Sample 25% across — should be red.
    let leftish = Self.readPixel(raster, x: 50, y: 50)
    #expect(leftish.0 > 200)
    #expect(leftish.2 < 50)

    // Sample 75% across — should be blue.
    let rightish = Self.readPixel(raster, x: 150, y: 50)
    #expect(rightish.0 < 50)
    #expect(rightish.2 > 200)
  }

  @Test func test_alphaMultiplier_appliedToOpaqueSource() throws {
    let source = Self.makeImage(width: 8, height: 4) { _, _ in (200, 100, 50, 255) }
    let baseMap = try #require(
      GeoDrawer.BaseMap(cgImage: source, sampling: .nearest, alpha: 0.5)
    )

    let drawer = GeoDrawer(
      size: .init(width: 100, height: 100),
      projection: Projections.Equirectangular()
    )
    let raster = try #require(drawer.renderedBaseMap(baseMap, coordinateSystem: .topLeft))

    let centre = Self.readPixel(raster, x: 50, y: 50)
    // Premultiplied — every channel including alpha is scaled by 0.5.
    #expect(abs(Int(centre.3) - 127) <= 2)
    #expect(abs(Int(centre.0) - 100) <= 2)
    #expect(abs(Int(centre.1) - 50) <= 2)
    #expect(abs(Int(centre.2) - 25) <= 2)
  }

  @Test func test_renderedBaseMap_isCachedByDrawer() throws {
    let source = Self.makeImage(width: 8, height: 4) { _, _ in (10, 20, 30, 255) }
    let baseMap = try #require(GeoDrawer.BaseMap(cgImage: source, sampling: .nearest))

    let drawer = GeoDrawer(
      size: .init(width: 80, height: 40),
      projection: Projections.Equirectangular()
    )
    let first = try #require(drawer.renderedBaseMap(baseMap, coordinateSystem: .topLeft))
    let second = try #require(drawer.renderedBaseMap(baseMap, coordinateSystem: .topLeft))
    // Same drawer + same base map => identical CGImage instance from the cache.
    #expect(first === second)
  }

  @Test func test_outOfBoundsPole_isNotSmeared_mercator() throws {
    // Source has a single bright magenta row at the very top (y=0) and
    // dark pixels elsewhere. A naive cylindrical sampler with v clamped
    // to 0 would smear the magenta across the top of the canvas; the
    // half-pixel inset on `v` keeps the visible band thin.
    let source = Self.makeImage(width: 16, height: 16) { _, y in
      y == 0 ? (255, 0, 255, 255) : (0, 0, 0, 255)
    }
    let baseMap = try #require(GeoDrawer.BaseMap(cgImage: source, sampling: .bilinear))

    let drawer = GeoDrawer(
      size: .init(width: 100, height: 100),
      projection: Projections.Mercator()
    )
    let raster = try #require(drawer.renderedBaseMap(baseMap, coordinateSystem: .topLeft))

    // Several rows below the top must NOT be saturated magenta —
    // confirms the bright source row isn't bleeding south.
    let mid = Self.readPixel(raster, x: 50, y: 50)
    #expect(mid.0 < 50)
    #expect(mid.2 < 50)
  }
}

#endif
