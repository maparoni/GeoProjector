//
//  NaturalEarthTests.swift
//  GeoProjector
//
//  Created by Adrian Schönig on 3/5/2025.
//

#if canImport(Testing)
import Testing

@testable import GeoProjector

struct NaturalEarthTests {
  
  @Test func matchesReferencePoints() async throws {
    // Reference coordinates projected with the polynomial Natural Earth projection (lon, lat, X, Y):
    // The radius of the sphere is 6371008.7714
    let reference = """
      0.0        0.0        0.0        0.0
      0.0        22.5        0.0        2525419.569383768
      0.0        45.0        0.0        5052537.389973222
      0.0        67.5        0.0        7400065.6562573705
      0.0        90.0        0.0        9062062.394736718
      45.0        0.0        4356790.016612169        0.0
      45.0        22.5        4253309.544984069        2525419.569383768
      45.0        45.0        3924521.5829515466        5052537.389973222
      45.0        67.5        3354937.47115583        7400065.6562573705
      45.0        90.0        2397978.2448443635        9062062.394736718
      90.0        0.0        8713580.033224339        0.0
      90.0        22.5        8506619.089968137        2525419.569383768
      90.0        45.0        7849043.165903093        5052537.389973222
      90.0        67.5        6709874.94231166        7400065.6562573705
      90.0        90.0        4795956.489688727        9062062.394736718
      135.0        0.0        1.3070370049836507E7        0.0
      135.0        22.5        1.2759928634952208E7        2525419.569383768
      135.0        45.0        1.177356474885464E7        5052537.389973222
      135.0        67.5        1.0064812413467491E7        7400065.6562573705
      135.0        90.0        7193934.734533091        9062062.394736718
      180.0        0.0        1.7427160066448677E7        0.0
      180.0        22.5        1.7013238179936275E7        2525419.569383768
      180.0        45.0        1.5698086331806187E7        5052537.389973222
      180.0        67.5        1.341974988462332E7        7400065.6562573705
      180.0        90.0        9591912.979377454        9062062.394736718
      """
    
    // Parse reference data
    let lines = reference.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
    let referencePoints = lines.compactMap { line -> (lon: Double, lat: Double, x: Double, y: Double)? in
      let components = line.split(separator: " ").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
      guard components.count == 4 else { return nil }
      return (lon: components[0], lat: components[1], x: components[2], y: components[3])
    }
    
    // Earth radius used in reference data
    let earthRadius = 6371008.7714
    
    // Create projection
    let projection = Projections.NaturalEarth(reference: .init(x: 0, y: 0))
    
    // Test reference points
    for point in referencePoints {
      // Convert degrees to radians for input
      let lonRad = point.lon * .pi / 180.0
      let latRad = point.lat * .pi / 180.0
      
      // Project the point
      let projected = try #require(projection.project(.init(x: lonRad, y: latRad)), "Failed to project point at lon: \(point.lon), lat: \(point.lat)")
      
      // Scale to match reference earth radius
      let scaledX = projected.x * earthRadius
      let scaledY = projected.y * earthRadius
      
      // Compare with reference data within tolerance
      #expect(abs(scaledX - point.x) < 0.1, "X coordinate doesn't match for lon: \(point.lon), lat: \(point.lat). Expected: \(point.x), got: \(scaledX)")
      #expect(abs(scaledY - point.y) < 0.1, "Y coordinate doesn't match for lon: \(point.lon), lat: \(point.lat). Expected: \(point.y), got: \(scaledY)")
    }
  }
}

#endif