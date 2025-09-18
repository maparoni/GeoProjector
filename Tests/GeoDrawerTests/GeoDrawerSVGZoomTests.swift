#if canImport(Testing)

import Testing
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

import GeoJSONKit
@testable import GeoDrawer
@testable import GeoProjector

struct GeoDrawerSVGZoomTests {

  @Test func testSVGWithoutZoom() throws {
    let drawer = GeoDrawer(
      size: .init(width: 400, height: 200),
      projection: Projections.Equirectangular()
    )

    let line = GeoJSON.LineString(positions: [
      .init(latitude: 40, longitude: -120), // West coast US
      .init(latitude: 40, longitude: -80)   // East coast US
    ])

    let content: [GeoDrawer.Content] = [
      .line(line, stroke: testColor(red: 1, green: 0, blue: 0), strokeWidth: 2)
    ]

    let svg = drawer.drawSVG(content)

    // Just verify the basic structure and that it contains the expected line
    #expect(svg.contains("<svg"))
    #expect(svg.contains("<path"))
    #expect(svg.contains("stroke=\"#FF0000\""))
    #expect(svg.contains("d=\"M 66.7 55.6 L 111.1 55.6\""))
  }

  @Test func testSVGWithZoom() throws {
    // Create a bounding box for North America
    let northAmericaBbox = GeoJSON.BoundingBox(positions: [
      .init(latitude: 10.0, longitude: -170.0),
      .init(latitude: 70.0, longitude: -50.0)
    ])

    let drawer = GeoDrawer(
      size: .init(width: 400, height: 200),
      projection: Projections.Equirectangular(),
      zoomTo: northAmericaBbox
    )

    let line = GeoJSON.LineString(positions: [
      .init(latitude: 40, longitude: -120), // West coast US
      .init(latitude: 40, longitude: -80)   // East coast US
    ])

    let content: [GeoDrawer.Content] = [
      .line(line, stroke: testColor(red: 1, green: 0, blue: 0), strokeWidth: 2)
    ]

    let svg = drawer.drawSVG(content)

    // With zoom to North America, the line should span a much larger portion of the width
    // The exact coordinates will depend on the zoom calculation, but it should be noticeably different
    // print("SVG with zoom: \(svg)")

    // For now, just check that we get a valid SVG with a path element
    #expect(svg.contains("<svg"))
    #expect(svg.contains("<path"))
    #expect(svg.contains("stroke=\"#FF0000\""))
  }

  @Test func testZoomActuallyChangesOutput() throws {
    let projection = Projections.Equirectangular()
    let size = Size(width: 400, height: 200)

    // Create a bounding box for North America
    let northAmericaBbox = GeoJSON.BoundingBox(positions: [
      .init(latitude: 10.0, longitude: -170.0),
      .init(latitude: 70.0, longitude: -50.0)
    ])

    let drawerNoZoom = GeoDrawer(size: size, projection: projection)
    let drawerWithZoom = GeoDrawer(size: size, projection: projection, zoomTo: northAmericaBbox)

    let line = GeoJSON.LineString(positions: [
      .init(latitude: 40, longitude: -120), // West coast US
      .init(latitude: 40, longitude: -80)   // East coast US
    ])

    let content: [GeoDrawer.Content] = [
      .line(line, stroke: testColor(red: 1, green: 0, blue: 0), strokeWidth: 2)
    ]

    let svgNoZoom = drawerNoZoom.drawSVG(content)
    let svgWithZoom = drawerWithZoom.drawSVG(content)

    // print("SVG without zoom: \(svgNoZoom)")
    // print("SVG with zoom: \(svgWithZoom)")

    // The SVGs should be different if zoom is working correctly
    #expect(svgNoZoom != svgWithZoom, "SVG output should be different when zoom is applied")
  }

  @Test func testMapBackgroundWithZoom() throws {
    let northAmericaBbox = GeoJSON.BoundingBox(positions: [
      .init(latitude: 10.0, longitude: -170.0),
      .init(latitude: 70.0, longitude: -50.0)
    ])

    let drawer = GeoDrawer(
      size: .init(width: 400, height: 200),
      projection: Projections.Equirectangular(),
      zoomTo: northAmericaBbox
    )

    let svg = drawer.drawSVG(
      [],
      mapBackground: testColor(red: 0.8, green: 0.8, blue: 1.0),
      mapOutline: testColor(red: 0, green: 0, blue: 0)
    )

    // The map background should respect zoom settings
    #expect(svg.contains("<svg"))
    #expect(svg.contains("<rect"))
    #expect(svg.contains("fill=\"#CCCCFF\""))
    #expect(svg.contains("stroke=\"#000000\""))

    // print("Map background with zoom: \(svg)")
  }

  // MARK: - Helper Methods

  private func testColor(red: Double, green: Double, blue: Double, alpha: Double = 1.0)
    -> GeoDrawer.Color
  {
    #if canImport(CoreGraphics)
      return CGColor(red: red, green: green, blue: blue, alpha: alpha)
    #else
      return GeoDrawer.Color(red: red, green: green, blue: blue, alpha: alpha)
    #endif
  }
}

#endif // canImport(Testing)
