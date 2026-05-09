//
//  Projections+Danseiji.swift
//  GeoProjectorDanseiji
//
//  Public `Projection`-conforming wrappers for each Danseiji variant.
//
//  The Danseiji family of map projections is the work of Justin Kunimune;
//  see https://kunimune.home.blog/2019/11/07/introducing-the-danseiji-projections/
//  and https://github.com/jkunimune/Map-Projections (MIT). The mesh data files
//  in `Resources/` are vendored unchanged from that repository.
//
//  Latitude in the `reference` is intentionally ignored: the mesh data is
//  computed for a fixed orientation. Longitude in the reference is honoured
//  and rotates the map east/west, matching the behaviour of `NaturalEarth`
//  and `EqualEarth`.
//

import Foundation
import GeoProjector

extension Projections {

  /// Danseiji I — the optimal conventional equal-area map.
  public struct DanseijiI: Projection {
    public init(reference: Point) {
      self.reference = reference
      let data = DanseijiLoader.data(for: .i)
      self.data = data
      self.projectionSize = data.projectionSize
      self.mapBounds = .bezier(data.edge)
    }

    public let reference: Point
    public let projectionSize: Size
    public let mapBounds: MapBounds
    private let data: DanseijiData

    public func willWrap(_ point: Point) -> Bool {
      DanseijiCore.willWrap(point, reference: reference)
    }

    public func project(_ point: Point) -> Point? {
      DanseijiCore.project(DanseijiCore.adjusted(point, reference: reference), data: data)
    }
  }

  /// Danseiji II — optimised giving more weight to shapes than sizes.
  public struct DanseijiII: Projection {
    public init(reference: Point) {
      self.reference = reference
      let data = DanseijiLoader.data(for: .ii)
      self.data = data
      self.projectionSize = data.projectionSize
      self.mapBounds = .bezier(data.edge)
    }

    public let reference: Point
    public let projectionSize: Size
    public let mapBounds: MapBounds
    private let data: DanseijiData

    public func willWrap(_ point: Point) -> Bool {
      DanseijiCore.willWrap(point, reference: reference)
    }

    public func project(_ point: Point) -> Point? {
      DanseijiCore.project(DanseijiCore.adjusted(point, reference: reference), data: data)
    }
  }

  /// Danseiji III — optimised to push distortion off continents into oceans.
  public struct DanseijiIII: Projection {
    public init(reference: Point) {
      self.reference = reference
      let data = DanseijiLoader.data(for: .iii)
      self.data = data
      self.projectionSize = data.projectionSize
      self.mapBounds = .bezier(data.edge)
    }

    public let reference: Point
    public let projectionSize: Size
    public let mapBounds: MapBounds
    private let data: DanseijiData

    public func willWrap(_ point: Point) -> Bool {
      DanseijiCore.willWrap(point, reference: reference)
    }

    public func project(_ point: Point) -> Point? {
      DanseijiCore.project(DanseijiCore.adjusted(point, reference: reference), data: data)
    }
  }

  /// Danseiji IV — optimised to display landmasses accurately and uninterrupted.
  public struct DanseijiIV: Projection {
    public init(reference: Point) {
      self.reference = reference
      let data = DanseijiLoader.data(for: .iv)
      self.data = data
      self.projectionSize = data.projectionSize
      self.mapBounds = .bezier(data.edge)
    }

    public let reference: Point
    public let projectionSize: Size
    public let mapBounds: MapBounds
    private let data: DanseijiData

    public func willWrap(_ point: Point) -> Bool {
      DanseijiCore.willWrap(point, reference: reference)
    }

    public func project(_ point: Point) -> Point? {
      DanseijiCore.project(DanseijiCore.adjusted(point, reference: reference), data: data)
    }
  }

  /// Danseiji V — shows off continents by compressing the oceans.
  public struct DanseijiV: Projection {
    public init(reference: Point) {
      self.reference = reference
      let data = DanseijiLoader.data(for: .v)
      self.data = data
      self.projectionSize = data.projectionSize
      self.mapBounds = .bezier(data.edge)
    }

    public let reference: Point
    public let projectionSize: Size
    public let mapBounds: MapBounds
    private let data: DanseijiData

    public func willWrap(_ point: Point) -> Bool {
      DanseijiCore.willWrap(point, reference: reference)
    }

    public func project(_ point: Point) -> Point? {
      DanseijiCore.project(DanseijiCore.adjusted(point, reference: reference), data: data)
    }
  }

  /// Danseiji VI — compromise where both physical area and population affect size.
  public struct DanseijiVI: Projection {
    public init(reference: Point) {
      self.reference = reference
      let data = DanseijiLoader.data(for: .vi)
      self.data = data
      self.projectionSize = data.projectionSize
      self.mapBounds = .bezier(data.edge)
    }

    public let reference: Point
    public let projectionSize: Size
    public let mapBounds: MapBounds
    private let data: DanseijiData

    public func willWrap(_ point: Point) -> Bool {
      DanseijiCore.willWrap(point, reference: reference)
    }

    public func project(_ point: Point) -> Point? {
      DanseijiCore.project(DanseijiCore.adjusted(point, reference: reference), data: data)
    }
  }

}
