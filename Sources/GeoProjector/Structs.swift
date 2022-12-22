//
//  Structs.swift
//  
//
//  Created by Adrian Schönig on 21/12/2022.
//

import Foundation

public struct Point: Equatable {
  public static var zero = Point(x: 0, y: 0)
  
  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }
  
  public var x: Double
  public var y: Double
  
  var lambda: Double { x }
  var phi: Double { y }
  var lng: Double { x }
  var lat: Double { y }
}

public struct Size: Equatable {
  public static var zero = Size(width: 0, height: 0)
  
  public init(width: Double, height: Double) {
    self.width = width
    self.height = height
  }
  
  public var width: Double
  public var height: Double
}

public struct Rect: Equatable {
  public init(origin: Point, size: Size) {
    self.origin = origin
    self.size = size
  }
  
  public var origin: Point
  public var size: Size
  
  public mutating func absorb(_ point: Point) {
    if point.x < origin.x {
      size.width += origin.x - point.x
      origin.x = point.x
    } else if point.x > origin.x + size.width {
      size.width = point.x - origin.x
    }

    if point.y < origin.y {
      size.height += origin.y - point.y
      origin.y = point.y
    } else if point.y > origin.y + size.height {
      size.height = point.y - origin.y
    }
  }
}
