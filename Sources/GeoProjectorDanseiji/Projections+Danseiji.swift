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

    public var visibleBounds: Rect { data.edgeBounds }

    public func project(_ point: Point) -> Point? {
      DanseijiCore.project(DanseijiCore.adjusted(point, reference: reference), data: data)
    }

    public func inverse(_ point: Point) -> Point? {
      DanseijiCore.inverse(point, data: data, reference: reference)
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

    public var visibleBounds: Rect { data.edgeBounds }

    public func project(_ point: Point) -> Point? {
      DanseijiCore.project(DanseijiCore.adjusted(point, reference: reference), data: data)
    }

    public func inverse(_ point: Point) -> Point? {
      DanseijiCore.inverse(point, data: data, reference: reference)
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

    public var visibleBounds: Rect { data.edgeBounds }

    public func project(_ point: Point) -> Point? {
      DanseijiCore.project(DanseijiCore.adjusted(point, reference: reference), data: data)
    }

    public func inverse(_ point: Point) -> Point? {
      DanseijiCore.inverse(point, data: data, reference: reference)
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

    public var visibleBounds: Rect { data.edgeBounds }

    public func project(_ point: Point) -> Point? {
      DanseijiCore.project(DanseijiCore.adjusted(point, reference: reference), data: data)
    }

    public func inverse(_ point: Point) -> Point? {
      DanseijiCore.inverse(point, data: data, reference: reference)
    }
  }

  /// Danseiji V — shows off continents by compressing the oceans.
  ///
  /// V's mesh deforms continents and oceans with a hand-tuned, asymmetric
  /// pattern. Rotating the map about an arbitrary reference longitude
  /// shears those deformations relative to the geography in a way that
  /// stops being meaningful, so the reference is intentionally pinned at
  /// `(0, 0)` regardless of the constructor argument.
  public struct DanseijiV: Projection {
    public init(reference: Point) {
      // `reference` ignored by design — see doc comment.
      let data = DanseijiLoader.data(for: .v)
      self.data = data
      self.projectionSize = data.projectionSize
      self.mapBounds = .bezier(data.edge)
    }

    public let reference: Point = .init(x: 0, y: 0)
    public let projectionSize: Size
    public let mapBounds: MapBounds
    private let data: DanseijiData

    public var visibleBounds: Rect { data.edgeBounds }

    public func project(_ point: Point) -> Point? {
      DanseijiCore.project(DanseijiCore.adjusted(point, reference: reference), data: data)
    }

    public func inverse(_ point: Point) -> Point? {
      DanseijiCore.inverse(point, data: data, reference: reference)
    }
  }

  /// Danseiji VI — compromise where both physical area and population affect size.
  ///
  /// Like V, VI is hand-tuned: its cell sizes encode population density on
  /// top of equal-area distortions, so rotating about a different reference
  /// longitude misaligns the population-weighted regions from their
  /// underlying geography. The reference is therefore pinned at `(0, 0)`
  /// regardless of the constructor argument.
  public struct DanseijiVI: Projection {
    public init(reference: Point) {
      // `reference` ignored by design — see doc comment.
      let data = DanseijiLoader.data(for: .vi)
      self.data = data
      self.projectionSize = data.projectionSize
      self.mapBounds = .bezier(data.edge)
    }

    public let reference: Point = .init(x: 0, y: 0)
    public let projectionSize: Size
    public let mapBounds: MapBounds
    private let data: DanseijiData

    public var visibleBounds: Rect { data.edgeBounds }

    public func project(_ point: Point) -> Point? {
      DanseijiCore.project(DanseijiCore.adjusted(point, reference: reference), data: data)
    }

    public func inverse(_ point: Point) -> Point? {
      DanseijiCore.inverse(point, data: data, reference: reference)
    }
  }

}
