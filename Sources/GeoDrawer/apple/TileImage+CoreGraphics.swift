//
//  TileImage+CoreGraphics.swift
//
//
//  Created by Adrian Schönig on 10/5/2026.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

#if canImport(CoreGraphics) && canImport(ImageIO)

import Foundation
import CoreGraphics
import ImageIO

extension TileImage {

  /// Decoder closure suitable for passing to `URLTemplateTileSource`.
  /// Decodes any image format ImageIO supports (PNG, JPEG, WebP on
  /// recent OS versions, etc.) into RGBA8 premultiplied bytes that the
  /// raster sampler can consume directly.
  ///
  /// Returns `nil` if the supplied bytes don't form a recognisable
  /// image; throws are reserved for unrecoverable errors (none occur in
  /// the current implementation).
  public static let coreGraphicsDecoder: @Sendable (Data) throws -> TileImage? = { data in
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
      return nil
    }

    let width = cgImage.width
    let height = cgImage.height
    guard width > 0, height > 0 else { return nil }

    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
    let cs = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

    let drew: Bool = pixels.withUnsafeMutableBufferPointer { ptr in
      guard let ctx = CGContext(
        data: ptr.baseAddress,
        width: width, height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: cs,
        bitmapInfo: bitmapInfo
      ) else { return false }
      ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    guard drew else { return nil }

    return TileImage(width: width, height: height, pixels: pixels)
  }
}

#endif
