//
//  TranslationTests.swift
//  
//
//  Created by Adrian Schönig on 9/12/2022.
//

#if canImport(Testing)
import Testing

@testable import GeoProjector

struct TranslationTests {
  @Test func equirectangularInSquare() throws {
    #expect(Projections.Equirectangular().translate(Point(x: 0, y: 0), to: .init(width: 100, height: 100), coordinateSystem: .topLeft) == .init(x: 50, y: 50))

    #expect(Projections.Equirectangular().translate(Point(x: -1 * .pi, y: 0.5 * .pi), to: .init(width: 100, height: 100), coordinateSystem: .topLeft) == .init(x: 0, y: 25))

    #expect(Projections.Equirectangular().translate(Point(x: .pi, y: 0.5 * .pi), to: .init(width: 100, height: 100), coordinateSystem: .topLeft) == .init(x: 100, y: 25))

    #expect(Projections.Equirectangular().translate(Point(x: .pi, y: -0.5 * .pi), to: .init(width: 100, height: 100), coordinateSystem: .topLeft) == .init(x: 100, y: 75))

    #expect(Projections.Equirectangular().translate(Point(x: -1 * .pi, y: -0.5 * .pi), to: .init(width: 100, height: 100), coordinateSystem: .topLeft) == .init(x: 0, y: 75))
  }
  
  @Test func equirectangularInWideStripe() throws {
    #expect(Projections.Equirectangular().translate(Point(x: 0, y: 0), to: .init(width: 400, height: 100), coordinateSystem: .topLeft) == .init(x: 200, y: 50))

    #expect(Projections.Equirectangular().translate(Point(x: -1 * .pi, y: 0.5 * .pi), to: .init(width: 400, height: 100), coordinateSystem: .topLeft) == .init(x: 100, y: 0))

    #expect(Projections.Equirectangular().translate(Point(x: .pi, y: 0.5 * .pi), to: .init(width: 400, height: 100), coordinateSystem: .topLeft) == .init(x: 300, y: 0))

    #expect(Projections.Equirectangular().translate(Point(x: .pi, y: -0.5 * .pi), to: .init(width: 400, height: 100), coordinateSystem: .topLeft) == .init(x: 300, y: 100))

    #expect(Projections.Equirectangular().translate(Point(x: -1 * .pi, y: -0.5 * .pi), to: .init(width: 400, height: 100), coordinateSystem: .topLeft) == .init(x: 100, y: 100))
  }
}

#endif