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
  
  public func scaled(x: Double, y: Double) -> Rect {
    var updated = self
    updated.scale(x: x, y: y)
    return updated
  }
  
  public mutating func scale(x: Double, y: Double) {
    let newSize = Size(width: size.width * x, height: size.height * y)
    let offset = Point(
      x: (newSize.width - size.width) / 2,
      y: (newSize.height - size.height) / 2
    )
    self.size = newSize
    self.origin.x -= offset.x
    self.origin.y -= offset.y
  }
}

public struct EdgeInsets: Equatable {
  public static let zero = EdgeInsets()
  
  public init(top: Double = 0, left: Double = 0, bottom: Double = 0, right: Double = 0) {
    self.top = top
    self.left = left
    self.bottom = bottom
    self.right = right
  }
  
  public var top: Double = 0
  public var left: Double = 0
  public var bottom: Double = 0
  public var right: Double = 0
}
