//
//  Projections.swift
//  
//
//  Created by Adrian Schönig on 4/12/2022.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2022 Corporoni Pty Ltd. See LICENSE.

import Foundation

/// Namespace for all projections
public enum Projections {}

extension Projections {
  /// Wraps a longitude in radians back into `-pi...pi`.
  static func wrapLongitude(_ x: Double) -> Double {
    var v = x
    if v >  .pi { v -= 2 * .pi }
    if v < -.pi { v += 2 * .pi }
    return v
  }
}

