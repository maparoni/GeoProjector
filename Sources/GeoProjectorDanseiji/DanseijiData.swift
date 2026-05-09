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
//      <pixelRows*pixelCols> rows of: phi,lam           (inverse lookup, ignored)
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

  let cells: [[Cell]]
  let edge: [Point]
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
          let edgeCount = Int(headerFields[3]) else {
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

    // The remaining "pixels" rows are an inverse-projection lookup we don't
    // expose, so they're left unread.

    var maxAbsX: Double = 0
    var maxAbsY: Double = 0
    for p in edge {
      maxAbsX = max(maxAbsX, abs(p.x))
      maxAbsY = max(maxAbsY, abs(p.y))
    }

    return DanseijiData(
      cells: cells,
      edge: edge,
      projectionSize: Size(width: 2 * maxAbsX, height: 2 * maxAbsY)
    )
  }
}
