#if canImport(Testing)

  import Testing
  import Foundation
  #if canImport(CoreGraphics)
    import CoreGraphics
  #endif

  import GeoJSONKit
  @testable import GeoDrawer
  @testable import GeoProjector

  struct GeoDrawerSVGTests {

    @Test func testBasicSVGGeneration() throws {
      let drawer = GeoDrawer(
        size: .init(width: 400, height: 200),
        projection: Projections.Equirectangular()
      )

      let line = GeoJSON.LineString(positions: [
        .init(latitude: 0, longitude: -90),
        .init(latitude: 0, longitude: 90),
      ])

      let content: [GeoDrawer.Content] = [
        .line(line, stroke: testColor(red: 1, green: 0, blue: 0), strokeWidth: 2)
      ]

      let svg = drawer.drawSVG(content)

      let expectedSVG = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="400.0" height="200.0" viewBox="0 0 400.0 200.0" xmlns="http://www.w3.org/2000/svg">
        <path d="M 100.0 100.0 L 300.0 100.0" stroke="#FF0000" stroke-width="2.0" stroke-linecap="round" stroke-linejoin="round" fill="none" />
        </svg>
        """

      #expect(svg == expectedSVG)
    }

    @Test func testPolygonSVG() throws {
      let drawer = GeoDrawer(
        size: .init(width: 400, height: 200),
        projection: Projections.Equirectangular()
      )

      let polygon = GeoJSON.Polygon(
        exterior: .init(positions: [
          .init(latitude: 10, longitude: -10),
          .init(latitude: 10, longitude: 10),
          .init(latitude: -10, longitude: 10),
          .init(latitude: -10, longitude: -10),
          .init(latitude: 10, longitude: -10),
        ]))

      let content: [GeoDrawer.Content] = [
        .polygon(
          polygon, fill: testColor(red: 0, green: 1, blue: 0),
          stroke: testColor(red: 0, green: 0, blue: 1), strokeWidth: 1)
      ]

      let svg = drawer.drawSVG(content)

      let expectedSVG = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="400.0" height="200.0" viewBox="0 0 400.0 200.0" xmlns="http://www.w3.org/2000/svg">
        <path d="M 188.9 111.1 L 211.1 111.1 L 211.1 111.1 L 211.1 88.9 L 211.1 88.9 L 188.9 88.9 L 188.9 88.9 L 188.9 111.1 Z" fill="#00FF00" stroke="#0000FF" stroke-width="1.0" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
        """

      #expect(svg == expectedSVG)
    }

    @Test func testCircleSVG() throws {
      let drawer = GeoDrawer(
        size: .init(width: 400, height: 200),
        projection: Projections.Equirectangular()
      )

      let content: [GeoDrawer.Content] = [
        .circle(
          .init(latitude: 0, longitude: 0), radius: 10, fill: testColor(red: 1, green: 0, blue: 0))
      ]

      let svg = drawer.drawSVG(content)

      let expectedSVG = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="400.0" height="200.0" viewBox="0 0 400.0 200.0" xmlns="http://www.w3.org/2000/svg">
        <circle cx="200.0" cy="100.0" r="5.0" fill="#FF0000" />
        </svg>
        """

      #expect(svg == expectedSVG)
    }

    @Test func testMapBackgroundAndOutline() throws {
      let drawer = GeoDrawer(
        size: .init(width: 400, height: 200),
        projection: Projections.Equirectangular()
      )

      let svg = drawer.drawSVG(
        [],
        mapBackground: testColor(red: 0.8, green: 0.8, blue: 1.0),
        mapOutline: testColor(red: 0, green: 0, blue: 0),
        mapBackdrop: testColor(red: 1, green: 1, blue: 1)
      )

      let expectedSVG = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="400.0" height="200.0" viewBox="0 0 400.0 200.0" xmlns="http://www.w3.org/2000/svg">
        <rect x="0.0" y="0.0" width="400.0" height="200.0" fill="#FFFFFF" />
        <rect x="0.0" y="200.0" width="400.0" height="-200.0" fill="#CCCCFF" />
        <rect x="0.0" y="200.0" width="400.0" height="-200.0" stroke="#000000" stroke-width="2.0" />
        </svg>
        """

      #expect(svg == expectedSVG)
    }

    @Test func testColorConversion() throws {
      let drawer = GeoDrawer(
        size: .init(width: 100, height: 100),
        projection: Projections.Equirectangular()
      )

      let line = GeoJSON.LineString(positions: [
        .init(latitude: 0, longitude: 0),
        .init(latitude: 10, longitude: 10),
      ])

      // Test different color formats
      let redColor = testColor(red: 1, green: 0, blue: 0)
      let semiTransparentBlue = testColor(red: 0, green: 0, blue: 1, alpha: 0.5)

      let content: [GeoDrawer.Content] = [
        .line(line, stroke: redColor),
        .circle(.init(latitude: 5, longitude: 5), radius: 5, fill: semiTransparentBlue),
      ]

      let svg = drawer.drawSVG(content)

      let expectedSVG = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="100.0" height="100.0" viewBox="0 0 100.0 100.0" xmlns="http://www.w3.org/2000/svg">
        <path d="M 50.0 50.0 L 52.8 52.8" stroke="#FF0000" stroke-width="2.0" stroke-linecap="round" stroke-linejoin="round" fill="none" />
        <circle cx="51.4" cy="51.4" r="2.5" fill="rgba(0,0,255,0.5)" />
        </svg>
        """

      #expect(svg == expectedSVG)
    }

    @Test func testEquirectangularProjection() throws {
      let drawer = GeoDrawer(
        size: .init(width: 200, height: 200),
        projection: Projections.Equirectangular()
      )

      let line = GeoJSON.LineString(positions: [
        .init(latitude: 0, longitude: -45),
        .init(latitude: 0, longitude: 45),
      ])

      let content: [GeoDrawer.Content] = [
        .line(line, stroke: testColor(red: 1, green: 0, blue: 0))
      ]

      let svg = drawer.drawSVG(content)

      let expectedSVG = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="200.0" height="200.0" viewBox="0 0 200.0 200.0" xmlns="http://www.w3.org/2000/svg">
        <path d="M 75.0 100.0 L 125.0 100.0" stroke="#FF0000" stroke-width="2.0" stroke-linecap="round" stroke-linejoin="round" fill="none" />
        </svg>
        """

      #expect(svg == expectedSVG)
    }

    @Test func testPolygonWithHoles() throws {
      let drawer = GeoDrawer(
        size: .init(width: 400, height: 200),
        projection: Projections.Equirectangular()
      )

      let exterior = GeoJSON.Polygon.LinearRing(positions: [
        .init(latitude: 20, longitude: -20),
        .init(latitude: 20, longitude: 20),
        .init(latitude: -20, longitude: 20),
        .init(latitude: -20, longitude: -20),
        .init(latitude: 20, longitude: -20),
      ])

      let interior = GeoJSON.Polygon.LinearRing(positions: [
        .init(latitude: 10, longitude: -10),
        .init(latitude: 10, longitude: 10),
        .init(latitude: -10, longitude: 10),
        .init(latitude: -10, longitude: -10),
        .init(latitude: 10, longitude: -10),
      ])

      let polygon = GeoJSON.Polygon(exterior: exterior, interiors: [interior])

      let content: [GeoDrawer.Content] = [
        .polygon(polygon, fill: testColor(red: 0, green: 1, blue: 0))
      ]

      let svg = drawer.drawSVG(content)

      let expectedSVG = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="400.0" height="200.0" viewBox="0 0 400.0 200.0" xmlns="http://www.w3.org/2000/svg">
        <path d="M 177.8 122.2 L 222.2 122.2 L 222.2 122.2 L 222.2 77.8 L 222.2 77.8 L 177.8 77.8 L 177.8 77.8 L 177.8 122.2 Z M 188.9 111.1 L 211.1 111.1 L 211.1 111.1 L 211.1 88.9 L 211.1 88.9 L 188.9 88.9 L 188.9 88.9 L 188.9 111.1 Z" fill="#00FF00" fill-rule="evenodd" />
        </svg>
        """

      #expect(svg == expectedSVG)
    }

    @Test func testEmptyContent() throws {
      let drawer = GeoDrawer(
        size: .init(width: 100, height: 100),
        projection: Projections.Equirectangular()
      )

      let svg = drawer.drawSVG([])

      let expectedSVG = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="100.0" height="100.0" viewBox="0 0 100.0 100.0" xmlns="http://www.w3.org/2000/svg">

        </svg>
        """

      #expect(svg == expectedSVG)
    }

    @Test func testComplexMap() throws {
      let drawer = GeoDrawer(
        size: .init(width: 800, height: 400),
        projection: Projections.EqualEarth()
      )

      // Create a mix of content types
      let coastline = GeoJSON.LineString(positions: [
        .init(latitude: 40, longitude: -75),
        .init(latitude: 41, longitude: -74),
        .init(latitude: 40.5, longitude: -73),
      ])

      let country = GeoJSON.Polygon(
        exterior: .init(positions: [
          .init(latitude: 30, longitude: -100),
          .init(latitude: 35, longitude: -95),
          .init(latitude: 32, longitude: -90),
          .init(latitude: 25, longitude: -95),
          .init(latitude: 30, longitude: -100),
        ]))

      let content: [GeoDrawer.Content] = [
        .polygon(
          country, fill: testColor(red: 0.8, green: 0.9, blue: 0.8),
          stroke: testColor(red: 0.3, green: 0.5, blue: 0.3)),
        .line(coastline, stroke: testColor(red: 0, green: 0, blue: 1), strokeWidth: 2),
        .circle(
          .init(latitude: 40.7, longitude: -74), radius: 8,
          fill: testColor(red: 1, green: 0, blue: 0)),
      ]

      let svg = drawer.drawSVG(
        content,
        mapBackground: testColor(red: 0.7, green: 0.8, blue: 1.0),
        mapOutline: testColor(red: 0.2, green: 0.2, blue: 0.2),
        mapBackdrop: testColor(red: 0.95, green: 0.95, blue: 0.95)
      )

      let expectedSVG = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="800.0" height="400.0" viewBox="0 0 800.0 400.0" xmlns="http://www.w3.org/2000/svg">
        <rect x="0.0" y="0.0" width="800.0" height="400.0" fill="#F2F2F2" />
        <path d="M 163.0 394.7 L 637.0 394.7 L 637.0 394.7 L 637.8 394.3 L 640.2 393.3 L 644.1 391.6 L 649.3 389.3 L 655.6 386.3 L 662.8 382.9 L 678.8 374.5 L 695.7 364.5 L 712.4 353.1 L 728.3 340.6 L 742.8 327.1 L 755.9 312.9 L 767.4 297.9 L 777.2 282.4 L 785.4 266.4 L 791.7 250.1 L 796.3 233.6 L 799.1 216.8 L 800.0 200.0 L 799.1 183.2 L 796.3 166.4 L 791.7 149.9 L 785.4 133.6 L 777.2 117.6 L 767.4 102.1 L 755.9 87.1 L 742.8 72.9 L 728.3 59.4 L 712.4 46.9 L 695.7 35.5 L 678.8 25.5 L 662.8 17.1 L 655.6 13.7 L 649.3 10.7 L 644.1 8.4 L 640.2 6.7 L 637.8 5.7 L 637.0 5.3 L 637.0 5.3 L 163.0 5.3 L 163.0 5.3 L 162.2 5.7 L 159.8 6.7 L 155.9 8.4 L 150.7 10.7 L 144.4 13.7 L 137.2 17.1 L 121.2 25.5 L 104.3 35.5 L 87.6 46.9 L 71.7 59.4 L 57.2 72.9 L 44.1 87.1 L 32.6 102.1 L 22.8 117.6 L 14.6 133.6 L 8.3 149.9 L 3.7 166.4 L 0.9 183.2 L 0.0 200.0 L 0.9 216.8 L 3.7 233.6 L 8.3 250.1 L 14.6 266.4 L 22.8 282.4 L 32.6 297.9 L 44.1 312.9 L 57.2 327.1 L 71.7 340.6 L 87.6 353.1 L 104.3 364.5 L 121.2 374.5 L 137.2 382.9 L 144.4 386.3 L 150.7 389.3 L 155.9 391.6 L 159.8 393.3 L 162.2 394.3 L 163.0 394.7 Z" fill="#B2CCFF" />
        <path d="M 192.1 287.6 L 207.4 301.3 L 207.4 301.3 L 214.7 293.1 L 214.7 293.1 L 198.4 273.6 L 198.4 273.6 L 192.1 287.6 Z" fill="#CCE5CC" stroke="#4C7F4C" stroke-width="2.0" stroke-linecap="round" stroke-linejoin="round" />
        <path d="M 252.3 314.5 L 255.2 317.1 L 255.2 317.1 L 256.7 315.8" stroke="#0000FF" stroke-width="2.0" stroke-linecap="round" stroke-linejoin="round" fill="none" />
        <path d="M 163.0 394.7 L 637.0 394.7 L 637.0 394.7 L 637.8 394.3 L 640.2 393.3 L 644.1 391.6 L 649.3 389.3 L 655.6 386.3 L 662.8 382.9 L 678.8 374.5 L 695.7 364.5 L 712.4 353.1 L 728.3 340.6 L 742.8 327.1 L 755.9 312.9 L 767.4 297.9 L 777.2 282.4 L 785.4 266.4 L 791.7 250.1 L 796.3 233.6 L 799.1 216.8 L 800.0 200.0 L 799.1 183.2 L 796.3 166.4 L 791.7 149.9 L 785.4 133.6 L 777.2 117.6 L 767.4 102.1 L 755.9 87.1 L 742.8 72.9 L 728.3 59.4 L 712.4 46.9 L 695.7 35.5 L 678.8 25.5 L 662.8 17.1 L 655.6 13.7 L 649.3 10.7 L 644.1 8.4 L 640.2 6.7 L 637.8 5.7 L 637.0 5.3 L 637.0 5.3 L 163.0 5.3 L 163.0 5.3 L 162.2 5.7 L 159.8 6.7 L 155.9 8.4 L 150.7 10.7 L 144.4 13.7 L 137.2 17.1 L 121.2 25.5 L 104.3 35.5 L 87.6 46.9 L 71.7 59.4 L 57.2 72.9 L 44.1 87.1 L 32.6 102.1 L 22.8 117.6 L 14.6 133.6 L 8.3 149.9 L 3.7 166.4 L 0.9 183.2 L 0.0 200.0 L 0.9 216.8 L 3.7 233.6 L 8.3 250.1 L 14.6 266.4 L 22.8 282.4 L 32.6 297.9 L 44.1 312.9 L 57.2 327.1 L 71.7 340.6 L 87.6 353.1 L 104.3 364.5 L 121.2 374.5 L 137.2 382.9 L 144.4 386.3 L 150.7 389.3 L 155.9 391.6 L 159.8 393.3 L 162.2 394.3 L 163.0 394.7 Z" fill="none" stroke="#333333" stroke-width="2.0" />
        <circle cx="254.9" cy="316.3" r="4.0" fill="#FF0000" />
        </svg>
        """

      #expect(svg == expectedSVG)
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

#endif  // canImport(Testing)
