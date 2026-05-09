//
//  DanseijiData.swift
//  GeoProjectorDanseiji
//
//  Parses and caches Danseiji CSV mesh files. The CSV format is:
//
//      header: vertexCount,cellRows,cellCols,edgeCount,pixelRows,pixelCols,projW,projH
//      <vertexCount> rows of: x,y                       (planar vertex, radians)
//      <cellRows*cellCols> rows of: shape,idx0,idx1,... (4 or 6 vertex indices)
//      <edgeCount> rows of: idx                         (boundary polygon)
//      <pixelRows*pixelCols> rows of: phi,lam           (inverse lookup)
//
//  Vendored verbatim from https://github.com/jkunimune/Map-Projections (MIT).
//

import Foundation
import GeoProjector

struct DanseijiData {
  struct Cell {
    let shape: Int
    let vertices: [Point]
  }

  /// Spherical coordinate (`phi` = latitude, `lam` = longitude) sampled at one
  /// node of the inverse-lookup grid.
  struct PixelSample {
    let phi: Double
    let lam: Double
  }

  let cells: [[Cell]]
  let edge: [Point]
  /// Inverse-lookup samples laid out as `[row][col]`, with `row 0` along the
  /// top of the projected image (largest `y`) and `row last` along the bottom.
  let pixels: [[PixelSample]]
  /// Tight bounding box of the edge polygon. Used by `inverse` to map projected
  /// (x, y) back to (col, row) in the pixel grid.
  let edgeBounds: Rect
  let projectionSize: Size
}

enum DanseijiLoadError: Error {
  case missingResource(String)
  case malformed(String)
}

enum DanseijiLoader {
  private static let lock = NSLock()
  private static var cache: [DanseijiVariant: DanseijiData] = [:]

  static func data(for variant: DanseijiVariant) -> DanseijiData {
    lock.lock()
    if let cached = cache[variant] {
      lock.unlock()
      return cached
    }
    lock.unlock()

    let parsed: DanseijiData
    do {
      parsed = try parse(variant: variant)
    } catch {
      preconditionFailure("Failed to load Danseiji \(variant.rawValue): \(error)")
    }

    lock.lock()
    cache[variant] = parsed
    lock.unlock()
    return parsed
  }

  private static func parse(variant: DanseijiVariant) throws -> DanseijiData {
    let resource = variant.resourceName
    let url = Bundle.module.url(forResource: resource, withExtension: "csv", subdirectory: "Resources")
      ?? Bundle.module.url(forResource: resource, withExtension: "csv")
    guard let url else {
      throw DanseijiLoadError.missingResource(resource)
    }

    let raw = try String(contentsOf: url, encoding: .utf8)
    var iterator = raw.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline).makeIterator()

    guard let headerLine = iterator.next() else {
      throw DanseijiLoadError.malformed("empty file: \(resource)")
    }
    let headerFields = headerLine.split(separator: ",").map { String($0) }
    guard headerFields.count >= 6,
          let vertexCount = Int(headerFields[0]),
          let cellRows = Int(headerFields[1]),
          let cellCols = Int(headerFields[2]),
          let edgeCount = Int(headerFields[3]),
          let pixelRows = Int(headerFields[4]),
          let pixelCols = Int(headerFields[5]) else {
      throw DanseijiLoadError.malformed("bad header in \(resource): \(headerLine)")
    }

    var vertices: [Point] = []
    vertices.reserveCapacity(vertexCount)
    for _ in 0..<vertexCount {
      guard let line = iterator.next() else {
        throw DanseijiLoadError.malformed("truncated vertex section in \(resource)")
      }
      let parts = line.split(separator: ",").map { String($0) }
      guard parts.count == 2,
            let x = Double(parts[0]),
            let y = Double(parts[1]) else {
        throw DanseijiLoadError.malformed("bad vertex line in \(resource): \(line)")
      }
      vertices.append(Point(x: x, y: y))
    }

    var cells: [[DanseijiData.Cell]] = []
    cells.reserveCapacity(cellRows)
    for _ in 0..<cellRows {
      var row: [DanseijiData.Cell] = []
      row.reserveCapacity(cellCols)
      for _ in 0..<cellCols {
        guard let line = iterator.next() else {
          throw DanseijiLoadError.malformed("truncated cell section in \(resource)")
        }
        let parts = line.split(separator: ",").map { String($0) }
        guard parts.count >= 2, let shape = Int(parts[0]) else {
          throw DanseijiLoadError.malformed("bad cell line in \(resource): \(line)")
        }
        var cellVertices: [Point] = []
        cellVertices.reserveCapacity(parts.count - 1)
        for k in 1..<parts.count {
          guard let idx = Int(parts[k]), idx >= 0, idx < vertices.count else {
            throw DanseijiLoadError.malformed("bad vertex index in \(resource): \(line)")
          }
          cellVertices.append(vertices[idx])
        }
        row.append(.init(shape: shape, vertices: cellVertices))
      }
      cells.append(row)
    }

    var edge: [Point] = []
    edge.reserveCapacity(edgeCount)
    for _ in 0..<edgeCount {
      guard let line = iterator.next() else {
        throw DanseijiLoadError.malformed("truncated edge section in \(resource)")
      }
      let parts = line.split(separator: ",").map { String($0) }
      guard let idx = Int(parts[0]), idx >= 0, idx < vertices.count else {
        throw DanseijiLoadError.malformed("bad edge index in \(resource): \(line)")
      }
      edge.append(vertices[idx])
    }

    var pixels: [[DanseijiData.PixelSample]] = []
    pixels.reserveCapacity(pixelRows)
    for _ in 0..<pixelRows {
      var row: [DanseijiData.PixelSample] = []
      row.reserveCapacity(pixelCols)
      for _ in 0..<pixelCols {
        guard let line = iterator.next() else {
          throw DanseijiLoadError.malformed("truncated pixel section in \(resource)")
        }
        let parts = line.split(separator: ",").map { String($0) }
        guard parts.count >= 2,
              let phi = Double(parts[0]),
              let lam = Double(parts[1]) else {
          throw DanseijiLoadError.malformed("bad pixel line in \(resource): \(line)")
        }
        row.append(.init(phi: phi, lam: lam))
      }
      pixels.append(row)
    }

    // The mesh files store planar coordinates with the bounding box centred
    // around (0, 0), but the geographic origin (lat=0, lon=0) does not always
    // map there: variants III–VI are deformed off-centre. The `Projection`
    // contract requires `reference` to project to `(0, 0)`, so probe the
    // parsed mesh for where (0, 0) lands and translate everything by that
    // offset. Variants whose data is already centred (I, II) get a near-zero
    // offset and are unaffected.
    let probe = DanseijiData(
      cells: cells,
      edge: edge,
      pixels: pixels,
      edgeBounds: Rect(origin: .zero, size: .zero),
      projectionSize: .zero
    )
    let offset = DanseijiCore.project(.init(x: 0, y: 0), data: probe) ?? .zero

    let shiftedCells: [[DanseijiData.Cell]] = cells.map { row in
      row.map { cell in
        DanseijiData.Cell(
          shape: cell.shape,
          vertices: cell.vertices.map { Point(x: $0.x - offset.x, y: $0.y - offset.y) }
        )
      }
    }
    let shiftedEdge = edge.map { Point(x: $0.x - offset.x, y: $0.y - offset.y) }

    var xMin = Double.infinity
    var xMax = -Double.infinity
    var yMin = Double.infinity
    var yMax = -Double.infinity
    for p in shiftedEdge {
      if p.x < xMin { xMin = p.x }
      if p.x > xMax { xMax = p.x }
      if p.y < yMin { yMin = p.y }
      if p.y > yMax { yMax = p.y }
    }
    let maxAbsX = max(abs(xMin), abs(xMax))
    let maxAbsY = max(abs(yMin), abs(yMax))

    return DanseijiData(
      cells: shiftedCells,
      edge: shiftedEdge,
      pixels: pixels,
      edgeBounds: Rect(
        origin: Point(x: xMin, y: yMin),
        size: Size(width: xMax - xMin, height: yMax - yMin)
      ),
      projectionSize: Size(width: 2 * maxAbsX, height: 2 * maxAbsY)
    )
  }
}
