//
//  DanseijiVariant.swift
//  GeoProjectorDanseiji
//

import Foundation
import GeoProjector
import GeoJSONKit

/// Selector for one of the six Danseiji projection variants. Supplied as a
/// sibling to `ProjectionMode` for clients that want enum-driven, Codable
/// selection across the variants without losing `String` raw values.
public enum DanseijiVariant: String, Codable, Sendable, CaseIterable {
  case i, ii, iii, iv, v, vi

  var resourceName: String {
    switch self {
    case .i: return "danseijiI"
    case .ii: return "danseijiII"
    case .iii: return "danseijiIII"
    case .iv: return "danseijiIV"
    case .v: return "danseijiV"
    case .vi: return "danseijiVI"
    }
  }

  /// Constructs the `Projection` for this variant.
  public func resolve(for center: GeoJSON.Position = .init(latitude: 0, longitude: 0)) -> any Projection {
    switch self {
    case .i: return Projections.DanseijiI(reference: center)
    case .ii: return Projections.DanseijiII(reference: center)
    case .iii: return Projections.DanseijiIII(reference: center)
    case .iv: return Projections.DanseijiIV(reference: center)
    case .v: return Projections.DanseijiV(reference: center)
    case .vi: return Projections.DanseijiVI(reference: center)
    }
  }
}
