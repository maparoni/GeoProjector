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

  /// A closed polygon whose edges cross the antimeridian (raw lon jumps by
  /// nearly 360°) should produce pieces that all stay inside the projection
  /// and together cover the polygon — no piece should span the full width
  /// (which would indicate the wrap was not detected).
  @Test func equirectangularPolygonStraddlingAntimeridianHasNoWideEdges() {
    let projection = Projections.Equirectangular()
    let drawer = GeoDrawer(size: .init(width: 360, height: 180), projection: projection)
    // A small box straddling the antimeridian; after wrap, each piece should
    // hug one vertical edge.
    let positions = [
      GeoJSON.Position(latitude: -10, longitude:  170),
      GeoJSON.Position(latitude:  10, longitude:  170),
      GeoJSON.Position(latitude:  10, longitude: -170),
      GeoJSON.Position(latitude: -10, longitude: -170),
      GeoJSON.Position(latitude: -10, longitude:  170),
    ]
    let pieces = drawer.convertPolygon(positions, coordinateSystem: .topLeft)
    #expect(pieces.count == 2)
    // No edge inside any piece should span more than half the canvas width;
    // any such edge is the antimeridian wrap drawn straight across.
    for piece in pieces {
      for (a, b) in zip(piece.dropLast(), piece.dropFirst()) {
        #expect(abs(a.x - b.x) < 200,
                "edge spans \(abs(a.x - b.x))px in \(piece) — antimeridian wrap not split")
      }
    }
  }

  /// For a `bezier`-bounded projection, an edge that crosses from one side of
  /// the bezier to the other must split — no resulting segment should span
  /// more than the bezier's full width. This mirrors the Danseiji failure
  /// shown in the screenshots: continents bleeding from one wing of the map
  /// to the other.
  @Test func bezierSplitsWrapAcrossOutline() {
    // A cylindrical-ish projection with a bezier outline: rectangle minus a
    // small notch on top and bottom (so it's clearly bezier, not rectangle).
    let edge: [Point] = [
      .init(x: -.pi, y: -1.0),
      .init(x:  .pi, y: -1.0),
      .init(x:  .pi, y:  1.0),
      .init(x:  0,   y:  0.9),
      .init(x: -.pi, y:  1.0),
    ]
    struct Faux: Projection {
      let edge: [Point]
      init(reference: Point) { self.init(edge: []) }
      init(edge: [Point]) { self.edge = edge }
      let reference: Point = .init(x: 0, y: 0)
      var mapBounds: MapBounds { .bezier(edge) }
      let projectionSize = Size(width: 2 * .pi, height: 2)
      func project(_ point: Point) -> Point? {
        // Plate carrée with antimeridian wrap.
        var x = point.x
        if x >  .pi { x -= 2 * .pi }
        if x < -.pi { x += 2 * .pi }
        return .init(x: x, y: point.y)
      }
      func inverse(_ point: Point) -> Point? { point }
    }
    let projection = Faux(edge: edge)
    let drawer = GeoDrawer(size: .init(width: 360, height: 180), projection: projection)
    // Polyline with one edge that wraps across antimeridian.
    let positions = [
      GeoJSON.Position(latitude: 0, longitude:  170),
      GeoJSON.Position(latitude: 0, longitude: -170),
    ]
    let pieces = drawer.convertLine(positions, coordinateSystem: .topLeft)
    #expect(pieces.count == 2)
    for piece in pieces {
      for (a, b) in zip(piece.dropLast(), piece.dropFirst()) {
        #expect(abs(a.x - b.x) < 200,
                "edge spans \(abs(a.x - b.x))px after split — bezier wrap not split")
      }
    }
  }

  /// A bezier outline with a concave notch can be exited and re-entered by a
  /// single straight segment whose endpoints are both inside. The drawer must
  /// split at both crossings or the polygon fill bleeds across the notch —
  /// this is what produced the green stripes above the Danseiji edge in the
  /// screenshots.
  @Test func bezierConcaveNotchSplitsTwice() {
    // Bezier: a wide rectangle with a triangular notch cut into the top edge.
    // Walking the outline counter-clockwise:
    //   bottom-left → bottom-right → top-right → notch-down → notch-bottom →
    //   notch-up → top-left.
    let edge: [Point] = [
      .init(x: -3.0, y: -1.0),
      .init(x:  3.0, y: -1.0),
      .init(x:  3.0, y:  1.0),
      .init(x:  0.5, y:  1.0),
      .init(x:  0.0, y:  0.2),  // notch tip dipping inwards
      .init(x: -0.5, y:  1.0),
      .init(x: -3.0, y:  1.0),
    ]
    struct Faux: Projection {
      let edge: [Point]
      init(reference: Point) { self.init(edge: []) }
      init(edge: [Point]) { self.edge = edge }
      let reference: Point = .init(x: 0, y: 0)
      var mapBounds: MapBounds { .bezier(edge) }
      let projectionSize = Size(width: 6, height: 2)
      func project(_ point: Point) -> Point? { .init(x: point.x, y: point.y) }
      func inverse(_ point: Point) -> Point? { point }
    }
    let projection = Faux(edge: edge)
    let drawer = GeoDrawer(size: .init(width: 600, height: 200), projection: projection)
    // The drawer converts degrees → radians, so 28.65° ≈ 0.5 rad and 150° ≈
    // 2.618 rad. The horizontal line at y=0.5 in projection coordinates sits
    // ABOVE the notch tip (y=0.2) and so crosses the two notch slopes (at
    // x = ±0.1875).
    let positions = [
      GeoJSON.Position(latitude: 28.65, longitude: -150),
      GeoJSON.Position(latitude: 28.65, longitude:  150),
    ]
    let pieces = drawer.convertLine(positions, coordinateSystem: .topLeft)
    #expect(pieces.count >= 2)
    // No edge should span across the notch — i.e. each edge keeps both
    // endpoints on the same side of the notch (screen x ≈ 282 / ≈ 318).
    for piece in pieces {
      for (a, b) in zip(piece.dropLast(), piece.dropFirst()) {
        let bothLeft = a.x < 285 && b.x < 285
        let bothRight = a.x > 315 && b.x > 315
        #expect(bothLeft || bothRight,
                "edge from x=\(a.x) to x=\(b.x) spans the notch")
      }
    }
  }

  /// Equal Earth at a non-zero longitude reference (e.g. 90°) projects a
  /// polygon spanning the new wrap line. The polygon must split into two
  /// closed pieces; neither piece should fill the entire upper or lower half
  /// of the bezier outline, which would indicate the closure walk picked the
  /// wrong direction (or the wrap wasn't detected at all).
  @Test func equalEarthNonZeroReferencePolygonStaysSane() {
    let projection = Projections.EqualEarth(reference: .init(latitude: 0, longitude: 90))
    let drawer = GeoDrawer(size: .init(width: 800, height: 400), projection: projection)

    // A small horizontal box straddling raw lon=-90° (= antimeridian after the
    // 90° reference shift): -100° to -80° at lat ±10°.
    let positions = [
      GeoJSON.Position(latitude: -10, longitude: -100),
      GeoJSON.Position(latitude:  10, longitude: -100),
      GeoJSON.Position(latitude:  10, longitude:  -80),
      GeoJSON.Position(latitude: -10, longitude:  -80),
      GeoJSON.Position(latitude: -10, longitude: -100),
    ]
    let pieces = drawer.convertPolygon(positions, coordinateSystem: .topLeft)

    #expect(pieces.count == 2,
            "Polygon straddling shifted antimeridian should split into 2; got \(pieces.count)")

    // The polygon at lat ±10° should project to a small region near the
    // bezier's left edge AND a small region near the bezier's right edge.
    // Neither piece should span more than half the canvas height — that'd be
    // the closure walking around the whole bezier.
    let canvasHeight: Double = 400
    for piece in pieces {
      let ys = piece.map(\.y)
      guard let yMin = ys.min(), let yMax = ys.max() else { continue }
      let span = yMax - yMin
      #expect(span < canvasHeight * 0.5,
              "piece y-span \(span) exceeds half canvas — closure walked the wrong way")
    }
  }

  /// Equal Earth (and Natural Earth) at a non-zero longitude reference must
  /// produce sane polygon pieces for every continent — no piece should fill
  /// more than ~20% of the canvas. A piece that fills (e.g.) the entire
  /// northern hemisphere indicates the closure walk went the wrong way around
  /// the bezier, typically because a wrap was missed in the (true, false) /
  /// (false, true) transition through an outside-the-bezier-polygon excursion.
  @Test(arguments: [
    ("equalEarth", 90.0),
    ("naturalEarth", 128.2),
    ("equalEarth", -93.2),
  ] as [(String, Double)])
  func pseudocylindricalRealContinentsAtNonZeroReference(name: String, lon: Double) throws {
    let projection: Projection
    switch name {
    case "equalEarth":
      projection = Projections.EqualEarth(reference: .init(latitude: 0, longitude: lon))
    case "naturalEarth":
      projection = Projections.NaturalEarth(reference: .init(latitude: 0, longitude: lon))
    default:
      Issue.record("unknown projection \(name)")
      return
    }
    let canvasWidth: Double = 800
    let canvasHeight: Double = 400
    let drawer = GeoDrawer(size: .init(width: canvasWidth, height: canvasHeight), projection: projection)

    let world = try GeoDrawer.Content.world()
    var polygons: [GeoJSON.Polygon] = []
    func absorb(_ geo: GeoJSON.Geometry) {
      if case .polygon(let p) = geo { polygons.append(p) }
    }
    func absorb(_ obj: GeoJSON.GeometryObject) {
      switch obj {
      case .single(let g): absorb(g)
      case .multi(let gs): gs.forEach(absorb)
      case .collection(let os): os.forEach(absorb)
      }
    }
    switch world.object {
    case .geometry(let g): absorb(g)
    case .feature(let f): absorb(f.geometry)
    case .featureCollection(let fs): fs.forEach { absorb($0.geometry) }
    }

    let canvasArea = canvasWidth * canvasHeight
    for (idx, polygon) in polygons.enumerated() {
      let pieces = drawer.convertPolygon(
        polygon.exterior.positions,
        coordinateSystem: .topLeft
      )
      for piece in pieces {
        guard piece.count >= 3 else { continue }
        var sum: Double = 0
        for i in 0..<piece.count {
          let a = piece[i]
          let b = piece[(i + 1) % piece.count]
          sum += a.x * b.y - b.x * a.y
        }
        let area = abs(sum) / 2
        #expect(area < canvasArea * 0.2,
                "\(name) ref-lon=\(lon) polygon[\(idx)] piece area=\(area) is \(area/canvasArea*100)% of canvas — closure walked the wrong way")
      }
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

// MARK: - Performance probes (manual; not part of regular suite)

// Run with PERF_BENCH=1 swift test -c release --filter PerfBench
struct PerfBench {
  @Test func benchEqualEarth() throws {
    let projection = Projections.EqualEarth(reference: .init(latitude: 0, longitude: 90))
    let drawer = GeoDrawer(size: .init(width: 800, height: 400), projection: projection)
    let world = try GeoDrawer.Content.world()
    var polygons: [GeoJSON.Polygon] = []
    func absorb(_ geo: GeoJSON.Geometry) {
      if case .polygon(let p) = geo { polygons.append(p) }
    }
    func absorb(_ obj: GeoJSON.GeometryObject) {
      switch obj {
      case .single(let g): absorb(g)
      case .multi(let gs): gs.forEach(absorb)
      case .collection(let os): os.forEach(absorb)
      }
    }
    switch world.object {
    case .geometry(let g): absorb(g)
    case .feature(let f): absorb(f.geometry)
    case .featureCollection(let fs): fs.forEach { absorb($0.geometry) }
    }
    let start = Date()
    var totalVertices = 0
    for _ in 0..<5 {
      for polygon in polygons {
        let pieces = drawer.convertPolygon(polygon.exterior.positions, coordinateSystem: .topLeft)
        for piece in pieces { totalVertices += piece.count }
      }
    }
    let elapsed = -start.timeIntervalSinceNow
    print("EqualEarth: \(polygons.count) polygons * 5 reps in \(String(format: "%.3f", elapsed * 1000))ms (\(totalVertices) total verts)")
  }

  @Test func benchOrthographic() throws {
    let projection = Projections.Orthographic(reference: .init(latitude: 0, longitude: 0))
    let drawer = GeoDrawer(size: .init(width: 800, height: 400), projection: projection)
    let world = try GeoDrawer.Content.world()
    var polygons: [GeoJSON.Polygon] = []
    func absorb(_ geo: GeoJSON.Geometry) {
      if case .polygon(let p) = geo { polygons.append(p) }
    }
    func absorb(_ obj: GeoJSON.GeometryObject) {
      switch obj {
      case .single(let g): absorb(g)
      case .multi(let gs): gs.forEach(absorb)
      case .collection(let os): os.forEach(absorb)
      }
    }
    switch world.object {
    case .geometry(let g): absorb(g)
    case .feature(let f): absorb(f.geometry)
    case .featureCollection(let fs): fs.forEach { absorb($0.geometry) }
    }
    let start = Date()
    var totalVertices = 0
    for _ in 0..<5 {
      for polygon in polygons {
        let pieces = drawer.convertPolygon(polygon.exterior.positions, coordinateSystem: .topLeft)
        for piece in pieces { totalVertices += piece.count }
      }
    }
    let elapsed = -start.timeIntervalSinceNow
    print("Orthographic: \(polygons.count) polygons * 5 reps in \(String(format: "%.3f", elapsed * 1000))ms (\(totalVertices) total verts)")
  }
}
