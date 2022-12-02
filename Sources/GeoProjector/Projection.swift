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
  case orthographic(reference: GeoJSON.Position = .init(latitude: 0, longitude: 0))
  
  public func point(for position: GeoJSON.Position, size: Size) -> Point {
//    let input: Point = .init(x: (position.longitude + 180) / 360, y: (position.latitude * -1 + 90) / 180)
    let input = Point(x: position.longitude.toRadians(), y: position.latitude.toRadians())
    
    let projected: Point
    
    switch self {
    case .equirectangular(0):
      projected = PlateCarree().project(input)
      
    case .equirectangular:
      preconditionFailure("TODO")

    case .mercator:
      projected = Meractor().project(input)

    case .orthographic(let reference):
      projected = Orthographic(refLat: reference.latitude.toRadians(), refLng: reference.longitude.toRadians()).project(input)
    }
    
    #warning("TODO: This sort-of works, *EXCEPT* that the project can change the size, e.g., mercator... i.e., the size (or aspect ration) is a function of the projection, too, which we should somehow consider... hmm")
    let reversed = Point(x: projected.x.toDegrees(), y: projected.y.toDegrees())
    let normalized = Point(x: (reversed.x + 180) / 360, y: (reversed.y * -1 + 90) / 180)
    return .init(x: normalized.x * size.width, y: normalized.y * size.height)
    
//    return .init(x: projected.x * size.width, y: projected.y * size.height)
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

extension GeoJSON.DegreesRadians {
  /**
   Returns the direction in degrees.
   */
  func toDegrees() -> GeoJSON.Degrees {
    return self * 180.0 / .pi
  }
}
