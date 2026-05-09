//
//  RenderSamples.swift
//
//  Manual rendering helpers — gated behind the `RENDER_SAMPLES` env var so
//  they don't run in CI. Use them to produce a PNG you can eyeball:
//
//      RENDER_SAMPLES=1 swift test --filter RenderSamples
//
//  Output goes to `/tmp/geodrawer-samples/` (or `$RENDER_SAMPLES_DIR`).
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2026 Corporoni Pty Ltd. See LICENSE.

#if canImport(Testing) && canImport(CoreGraphics) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)

import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

@testable import GeoDrawer
import GeoProjector
import GeoProjectorDanseiji

struct RenderSamples {

  static var isEnabled: Bool {
    ProcessInfo.processInfo.environment["RENDER_SAMPLES"] != nil
  }

  static var outputDirectory: URL {
    let raw = ProcessInfo.processInfo.environment["RENDER_SAMPLES_DIR"]
      ?? "/tmp/geodrawer-samples"
    let url = URL(fileURLWithPath: raw, isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  static func loadBlueMarble() -> CGImage? {
    let path = "/Users/adrian/Development/GeoProjector/Examples/Cassini/Assets.xcassets/world.200408.3x5400x2700.imageset/world.200408.3x5400x2700.jpg"
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
  }

  static func writePNG(_ image: CGImage, to url: URL) throws {
    guard let dest = CGImageDestinationCreateWithURL(
      url as CFURL,
      UTType.png.identifier as CFString,
      1, nil
    ) else {
      throw NSError(domain: "RenderSamples", code: 1, userInfo: [NSLocalizedDescriptionKey: "destination"])
    }
    CGImageDestinationAddImage(dest, image, nil)
    if !CGImageDestinationFinalize(dest) {
      throw NSError(domain: "RenderSamples", code: 2, userInfo: [NSLocalizedDescriptionKey: "finalize"])
    }
  }

  /// Renders a Danseiji IV map with the bundled Blue Marble base map and
  /// writes it as `danseiji-iv-blue-marble.png` so the user can confirm the
  /// `drawImage` / image-export path picks up `Content.baseMap` correctly.
  @Test func render_danseiji_iv_blue_marble() throws {
    guard Self.isEnabled else { return }

    let cgImage = try #require(Self.loadBlueMarble(), "missing Blue Marble JPEG")
    let baseMap = try #require(GeoDrawer.BaseMap(cgImage: cgImage, sampling: .bilinear))

    let canvasW = 1600
    let canvasH = 800
    let drawer = GeoDrawer(
      size: .init(width: Double(canvasW), height: Double(canvasH)),
      projection: Projections.DanseijiIV()
    )

    let bytesPerRow = canvasW * 4
    var buffer = [UInt8](repeating: 0, count: bytesPerRow * canvasH)
    let cs = CGColorSpaceCreateDeviceRGB()
    let context = try #require(buffer.withUnsafeMutableBufferPointer { ptr -> CGContext? in
      CGContext(
        data: ptr.baseAddress,
        width: canvasW, height: canvasH,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    })

    let backdrop = CGColor(red: 0.05, green: 0.06, blue: 0.10, alpha: 1)
    let mapBackground = CGColor(red: 0.10, green: 0.20, blue: 0.30, alpha: 1)
    let mapOutline = CGColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)

    let continents = try GeoDrawer.Content.content(
      for: GeoDrawer.Content.countries(),
      style: .init(
        color: CGColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 0.4),
        lineWidth: 0.5
      )
    )

    var contents: [GeoDrawer.Content] = [.baseMap(baseMap)]
    contents.append(contentsOf: continents)

    drawer.draw(
      contents,
      mapBackground: mapBackground,
      mapOutline: mapOutline,
      mapBackdrop: backdrop,
      in: context
    )

    let rendered = try #require(context.makeImage())
    let outputURL = Self.outputDirectory.appendingPathComponent("danseiji-iv-blue-marble.png")
    try Self.writePNG(rendered, to: outputURL)

    print("Wrote sample to \(outputURL.path)")
  }
}

#endif
