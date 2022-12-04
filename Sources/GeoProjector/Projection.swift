//
//  Projection.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

import Foundation

import GeoJSONKit
import GeoJSONKitTurf

public struct Point: Equatable {
  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }
  
  public let x: Double
  public let y: Double
}

public struct Size: Equatable {
  public init(width: Double, height: Double) {
    self.width = width
    self.height = height
  }
  
  public let width: Double
  public let height: Double
}

public protocol Projection {
  init(reference: Point)
  
  func project(_ point: Point) -> Point
  
  var showsFullEarth: Bool { get }
  
  var mightInvert: Bool { get }
}

extension Projection {
  public var showsFullEarth: Bool { true }
  public var mightInvert: Bool { false }
  
}

extension Projection {
  public init(reference: GeoJSON.Position = .init(latitude: 0, longitude: 0)) {
    self.init(reference: .init(x: reference.longitude.toRadians(), y: reference.latitude.toRadians()))
  }
}

extension Projection {
  
  public func point(for position: GeoJSON.Position, size: Size) -> Point {
    let input = Point(x: position.longitude.toRadians(), y: position.latitude.toRadians())
    
    let projected = project(input)
    
    let reversed = Point(x: projected.x.toDegrees(), y: projected.y.toDegrees())
    let normalized = Point(x: (reversed.x + 180) / 360, y: (reversed.y * -1 + 90) / 180)
    return .init(x: normalized.x * size.width, y: normalized.y * size.height)
  }
  
}
