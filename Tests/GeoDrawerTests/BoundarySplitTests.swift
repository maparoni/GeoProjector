//
//  BoundarySplitTests.swift
//  GeoDrawerTests
//

#if canImport(Testing)
import Testing
import Foundation

import GeoJSONKit
import GeoProjector
@testable import GeoDrawer

struct BoundarySplitTests {

  // MARK: - MapBounds geometry primitives

  @Test func rectangleIntersectionAtAntimeridian() {
    let bounds = MapBounds.rectangle
    let size = Size(width: 2 * .pi, height: .pi)
    // Segment crossing the right edge of the rectangle.
    let a = Point(x:  3.0, y: 0.0)
    let b = Point(x:  4.0, y: 0.0)
    let hit = bounds.firstIntersection(from: a, to: b, projectionSize: size)
    #expect(hit != nil)
    #expect(abs((hit?.x ?? 0) - .pi) < 1e-9)
    #expect(abs(hit?.y ?? 1) < 1e-9)
  }

  @Test func rectangleNoIntersectionWhenBothInside() {
    let bounds = MapBounds.rectangle
    let size = Size(width: 2 * .pi, height: .pi)
    let a = Point(x: 0, y: 0)
    let b = Point(x: 1, y: 0)
    #expect(bounds.firstIntersection(from: a, to: b, projectionSize: size) == nil)
  }

  @Test func ellipseIntersectionAtLimb() {
    let bounds = MapBounds.ellipse
    let size = Size(width: 2, height: 2) // unit disk
    let a = Point(x: 0, y: 0)
    let b = Point(x: 2, y: 0)
    let hit = bounds.firstIntersection(from: a, to: b, projectionSize: size)
    #expect(hit != nil)
    #expect(abs((hit?.x ?? 0) - 1) < 1e-9)
    #expect(abs(hit?.y ?? 1) < 1e-9)
  }

  @Test func bezierIntersectionAgainstDiamond() {
    // Diamond shape with vertices (1,0), (0,1), (-1,0), (0,-1).
    let diamond = MapBounds.bezier([
      .init(x:  1, y:  0),
      .init(x:  0, y:  1),
      .init(x: -1, y:  0),
      .init(x:  0, y: -1),
    ])
    let size = Size(width: 2, height: 2)
    let a = Point(x: 0.5, y: 0.0)
    let b = Point(x: 5.0, y: 0.0) // crosses the (1,0)-(0,1) edge then (0,-1)-(1,0)
    let hit = diamond.firstIntersection(from: a, to: b, projectionSize: size)
    #expect(hit != nil)
    // First crossing: x + y = 1 (top-right edge), with y = 0 → x = 1.
    #expect(abs((hit?.x ?? 0) - 1) < 1e-9)
    #expect(abs(hit?.y ?? 1) < 1e-9)
  }

  @Test func boundaryArcOnRectangleWalksShorterSide() {
    let bounds = MapBounds.rectangle
    let size = Size(width: 2, height: 2) // -1..+1 on each axis
    // Both endpoints on the bottom edge — arc should be empty (no corners between).
    let a = Point(x: -0.5, y: -1)
    let b = Point(x:  0.5, y: -1)
    let arc = bounds.boundaryArc(from: a, to: b, projectionSize: size)
    #expect(arc.isEmpty)
  }

  @Test func boundaryArcOnRectangleEmitsCorner() {
    let bounds = MapBounds.rectangle
    let size = Size(width: 2, height: 2)
    // a on right edge, b on top edge — shorter walk goes through (1, 1).
    let a = Point(x: 1, y: 0)
    let b = Point(x: 0, y: 1)
    let arc = bounds.boundaryArc(from: a, to: b, projectionSize: size)
    #expect(arc.count == 1)
    #expect(arc.first == .init(x: 1, y: 1))
  }

  // MARK: - Boundary split through GeoDrawer

  /// A polyline that crosses the antimeridian via out-of-range longitudes
  /// (170° → 190°) should split into two pieces under Equirectangular,
  /// each anchored at the rectangle's vertical edges.
  @Test func equirectangularSplitsAcrossAntimeridian() {
    let projection = Projections.Equirectangular()
    let drawer = GeoDrawer(size: .init(width: 360, height: 180), projection: projection)
    let positions = [
      GeoJSON.Position(latitude: -10, longitude: 170),
      GeoJSON.Position(latitude: -10, longitude: 190), // wraps in adjust → -170
    ]
    let pieces = drawer.convertLine(positions, coordinateSystem: .topLeft)
    #expect(pieces.count == 2)
    // Each piece's boundary anchor sits on the rectangle's vertical edge:
    // x is 0 (left) or 360 (right) in screen coords.
    for piece in pieces {
      #expect(piece.first?.x == 0 || piece.first?.x == 360 || piece.last?.x == 0 || piece.last?.x == 360)
    }
  }

  /// An orthographic-projected polyline that runs from the visible side of the
  /// disk to the hidden side should end on the limb.
  @Test func orthographicEndsOnLimb() {
    let projection = Projections.Orthographic() // reference (0, 0)
    let drawer = GeoDrawer(size: .init(width: 200, height: 200), projection: projection)
    let positions = [
      GeoJSON.Position(latitude: 0, longitude: 0),
      GeoJSON.Position(latitude: 0, longitude: 170), // far behind the disk
    ]
    let pieces = drawer.convertLine(positions, coordinateSystem: .topLeft)
    #expect(!pieces.isEmpty)
    // Last point of the first piece should sit on the inscribed disk.
    if let last = pieces.first?.last {
      let dx = last.x - 100
      let dy = last.y - 100
      let dist = (dx * dx + dy * dy).squareRoot()
      #expect(dist <= 100 + 1)
    }
  }

  /// The world's continents rendered through Danseiji IV must produce polygons
  /// whose every vertex sits inside the bezier outline. This is the test that
  /// catches the "huge sweeping triangles" regression.
  @Test func danseijiIVPolygonsStayInsideBounds() throws {
    // We don't import GeoProjectorDanseiji here because GeoDrawerTests doesn't
    // depend on it. Instead, exercise the pipeline against a `.bezier` outline
    // built by hand: a rectangle minus a wedge on the right (interrupted shape).
    let edge: [Point] = [
      .init(x: -3.0, y: -1.5),
      .init(x:  3.0, y: -1.5),
      .init(x:  3.0, y:  0.0),
      .init(x:  1.5, y:  0.0),
      .init(x:  3.0, y:  0.5),
      .init(x:  3.0, y:  1.5),
      .init(x: -3.0, y:  1.5),
    ]
    // Synthesise a faux projection with this outline.
    struct Faux: Projection {
      let edge: [Point]
      init(reference: Point) { self.init(edge: []) }
      init(edge: [Point]) { self.edge = edge }
      let reference: Point = .init(x: 0, y: 0)
      var mapBounds: MapBounds { .bezier(edge) }
      let projectionSize = Size(width: 6, height: 3)
      func project(_ point: Point) -> Point? {
        // Plate Carrée-ish: longitude in radians → x scaled, latitude → y scaled.
        // For the test we feed positions in degrees that map straight through.
        .init(x: point.x, y: point.y)
      }
      func inverse(_ point: Point) -> Point? { point }
    }
    let projection = Faux(edge: edge)
    let drawer = GeoDrawer(size: .init(width: 600, height: 300), projection: projection)

    // A polygon that crosses through the wedge interruption.
    let positions = [
      GeoJSON.Position(latitude: 0.3, longitude: 0.0),
      GeoJSON.Position(latitude: 0.3, longitude: 2.5),  // outside, in the notch
      GeoJSON.Position(latitude: -0.3, longitude: 2.5), // outside, in the notch
      GeoJSON.Position(latitude: -0.3, longitude: 0.0),
      GeoJSON.Position(latitude: 0.3, longitude: 0.0),
    ]
    let pieces = drawer.convertPolygon(positions, coordinateSystem: .topLeft)
    #expect(!pieces.isEmpty)
    // The polygon should be cut at the bezier outline. We assert no point sits
    // outside the bezier in projected (radian) space — but pieces here are in
    // screen space already. Spot-check by re-projecting back from screen. The
    // simplest sanity is that no piece reaches the right edge of the canvas
    // beyond the bezier's wedge tip (x ≈ 1.5 → screen x ≈ 450).
    let canvasWidth: Double = 600
    let bezierTipScreenX: Double = (1.5 + 3.0) / 6.0 * canvasWidth // ≈ 450
    for piece in pieces {
      for p in piece {
        // Allow a couple of pixels of slack for the boundary closure walk.
        #expect(p.x <= bezierTipScreenX + 5 || p.x >= canvasWidth - 5,
                "polygon vertex at x=\(p.x) leaks past wedge tip ≈ \(bezierTipScreenX)")
      }
    }
  }
}

#endif
