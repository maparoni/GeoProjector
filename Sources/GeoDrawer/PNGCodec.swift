//
//  PNGCodec.swift
//
//
//  Created by Adrian Schönig on 27/10/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

import Foundation
import PNG

extension TileImage {

  /// Decoder closure suitable for passing to `URLTemplateTileSource` on
  /// any platform. Decodes PNG bytes via `swift-png` into the RGBA8
  /// premultiplied layout the raster sampler consumes. Returns `nil` if
  /// the bytes don't carry a PNG signature (e.g. a JPEG tile — on Apple
  /// platforms use `coreGraphicsDecoder` for those); throws on malformed
  /// PNG data.
  public static let pngDecoder: @Sendable (Data) throws -> TileImage? = { data in
    guard let bitmap = try PNGCodec.decode(data) else { return nil }
    return TileImage(width: bitmap.width, height: bitmap.height, pixels: bitmap.pixels)
  }
}

extension GeoDrawer.RasterBitmap {
  /// Encodes the bitmap as PNG, un-premultiplying the alpha first.
  func pngData(level: Int = 6) -> Data {
    PNGCodec.encode(self, level: level)
  }
}

/// Pure-Swift PNG bridge around `swift-png`: converts between its
/// straight-alpha `RGBA<UInt8>` pixels and the premultiplied byte buffers
/// used throughout GeoDrawer.
enum PNGCodec {

  static func decode(_ data: Data) throws -> GeoDrawer.RasterBitmap? {
    var source = ByteSource(bytes: [UInt8](data))
    let image: PNG.Image
    do {
      image = try PNG.Image.decompress(stream: &source)
    } catch PNG.LexingError.invalidSignature {
      return nil
    } catch PNG.LexingError.truncatedSignature {
      return nil
    }
    let width = image.size.x
    let height = image.size.y
    guard width > 0, height > 0 else { return nil }

    let rgba = image.unpack(as: PNG.RGBA<UInt8>.self)
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    for (i, px) in rgba.enumerated() {
      let off = i * 4
      let a = px.a
      if a == 255 {
        pixels[off + 0] = px.r
        pixels[off + 1] = px.g
        pixels[off + 2] = px.b
      } else if a > 0 {
        pixels[off + 0] = premultiply(px.r, a)
        pixels[off + 1] = premultiply(px.g, a)
        pixels[off + 2] = premultiply(px.b, a)
      }
      pixels[off + 3] = a
    }
    return GeoDrawer.RasterBitmap(width: width, height: height, pixels: pixels)
  }

  static func encode(_ bitmap: GeoDrawer.RasterBitmap, level: Int) -> Data {
    let count = bitmap.width * bitmap.height
    var rgba: [PNG.RGBA<UInt8>] = []
    rgba.reserveCapacity(count)
    bitmap.pixels.withUnsafeBufferPointer { ptr in
      for i in 0..<count {
        let off = i * 4
        let a = ptr[off + 3]
        if a == 255 || a == 0 {
          rgba.append(.init(ptr[off], ptr[off + 1], ptr[off + 2], a))
        } else {
          rgba.append(.init(
            unpremultiply(ptr[off], a),
            unpremultiply(ptr[off + 1], a),
            unpremultiply(ptr[off + 2], a),
            a
          ))
        }
      }
    }
    let image = PNG.Image(
      packing: rgba,
      size: (x: bitmap.width, y: bitmap.height),
      layout: .init(format: .rgba8(palette: [], fill: nil))
    )
    var destination = ByteDestination()
    // `compress` only throws when the destination refuses a write, which
    // an in-memory buffer never does.
    try? image.compress(stream: &destination, level: level)
    return Data(destination.bytes)
  }

  @inline(__always)
  private static func premultiply(_ value: UInt8, _ alpha: UInt8) -> UInt8 {
    UInt8((Int(value) * Int(alpha) + 127) / 255)
  }

  @inline(__always)
  private static func unpremultiply(_ value: UInt8, _ alpha: UInt8) -> UInt8 {
    UInt8(min(255, (Int(value) * 255 + Int(alpha) / 2) / Int(alpha)))
  }

  private struct ByteSource: PNG.BytestreamSource {
    let bytes: [UInt8]
    var position = 0

    mutating func read(count: Int) -> [UInt8]? {
      guard position + count <= bytes.count else { return nil }
      defer { position += count }
      return Array(bytes[position..<position + count])
    }
  }

  private struct ByteDestination: PNG.BytestreamDestination {
    var bytes: [UInt8] = []

    mutating func write(_ buffer: [UInt8]) -> Void? {
      bytes.append(contentsOf: buffer)
      return ()
    }
  }
}
