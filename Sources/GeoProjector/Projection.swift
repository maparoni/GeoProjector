//
//  Projection.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

import Foundation

import GeoJSONKit

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


public enum Projection {
  
  
  /// Fancy name for 'no' projection
  case equirectangular(phiOne: Double = 0)
  
  /// Web standard
  case mercator
  
  /// "World from space"
  case orthographic
  
  public func point(for position: GeoJSON.Position, size: Size) -> Point {
    let input: Point = .init(x: (position.longitude + 180) / 360, y: (position.latitude * -1 + 90) / 180)
    
    let projected: Point
    
    switch self {
    case .equirectangular(0):
      projected = PlateCarree().project(input)
      
    case .equirectangular:
      preconditionFailure("TODO")

    case .mercator:
      preconditionFailure("TODO")

    case .orthographic:
      let x = Orthographic.x(lat: position.latitude, lng: position.longitude)
      let y = Orthographic.y(lat: position.latitude, lng: position.longitude)
      projected = .init(x: x * size.width, y: y * size.height)
    }
    
    return .init(x: projected.x * size.width, y: projected.y * size.height)
  }
  
}

extension GeoJSON {
  typealias DegreesRadians = Double
}

extension GeoJSON.Degrees {
  /**
   Returns the direction in radians.
   */
  func toRadians() -> GeoJSON.DegreesRadians {
    return self * .pi / 180.0
  }
}
