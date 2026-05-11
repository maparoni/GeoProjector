[![GitHub License](https://img.shields.io/github/license/maparoni/GeoProjector)](https://github.com/maparoni/GeoProjector/blob/main/LICENSE)
[![CI](https://github.com/maparoni/GeoProjector/actions/workflows/swift.yml/badge.svg)](https://github.com/maparoni/GeoProjector/actions/workflows/swift.yml)

# GeoProjector

This is a Swift-only library to calculate and draw map projections.

**The API is still evolving — pin to a specific minor version while we are
on `0.x`.**

- **GeoProjector**: Map projections, turning geographic coordinates into
  projected coordinates and into screen coordinates. Includes a forward
  `project` and an `inverse` so you can map a screen-space click back to
  latitude/longitude.
- **GeoProjectorDanseiji**: The six [Danseiji](https://kunimune.home.blog/2019/11/07/introducing-the-danseiji-projections/)
  projections by Justin Kunimune, packaged as their own product so the
  ~1 MB of pre-baked mesh data only ships with apps that ask for it.
- **GeoDrawer**: Draw GeoJSON using whichever projection you choose. Also
  drape raster base maps under your vector layers — either a single source
  image (e.g. NASA Blue Marble) or a tiled source (slippy `{z}/{x}/{y}`
  URL templates, or any custom `TileSource`).

## Goals of this library

- Support a selection of map projections, but not an exhaustive list
- Provide methods for drawing those projections, draw GeoJSON content on top,
  draping raster imagery underneath, and drawing just a section of the
  resulting map
- Provide methods for projecting points and inverting screen-space points back
  to geographic coordinates
- Compatibility with Apple platforms and Linux

## Dependencies

This library is part of the [Maparoni](https://maparoni.app) suite of mapping 
related Swift libraries and depends on:

- [GeoJSONKit](https://github.com/maparoni/GeoJSONKit), a light-weight GeoJSON
  framework.
- [GeoJSONKit-Turf](https://github.com/maparoni/geojsonkit-turf), a fork of
  [turf-swift](https://github.com/mapbox/turf-swift) with GeoJSONKit's GeoJSON
  enums used for the basic data models.
  
## Usage

### Installation

To install GeoProjector using the [Swift Package Manager](https://swift.org/package-manager/),
add the following package to the `dependencies` in your `Package.swift` file or
in Xcode:

```swift
.package(
  url: "https://github.com/maparoni/geoprojector",
  from: "0.1.0"
)
```

The package vends three products. Add only the ones you need to your target's
dependencies — pulling in `GeoProjectorDanseiji` is what brings the mesh data
along, so leave it out unless you actually use those projections.

```swift
.target(
  name: "MyApp",
  dependencies: [
    .product(name: "GeoProjector",         package: "GeoProjector"), // projections
    .product(name: "GeoDrawer",            package: "GeoProjector"), // drawing helpers
    .product(name: "GeoProjectorDanseiji", package: "GeoProjector"), // optional
  ]
)
```

### Projections

Projections are defined using the `Projection` protocol, which declares the
forward `project(_:)` and inverse `inverse(_:)` methods, plus metadata such as
the shape of the projection's `mapBounds`.

The projections themselves are available through the `Projections` namespace
(i.e., a caseless enum) which provides implementations of Equirectangular,
Cassini, Mercator, Gall-Peters, Equal Earth, Natural Earth, Orthographic,
Azimuthal Equidistant, and — via `GeoProjectorDanseiji` — Danseiji I through
VI. Note that the implementations are based on radians, but there are various
helper methods to work with GeoJSON and coordinates in degrees.

Project a coordinate to a screen-space point:

```swift
import GeoProjector

let projection = Projections.Orthographic(
  reference: GeoJSON.Position(latitude: 0, longitude: 100)
)
let sydney = GeoJSON.Position(latitude: -33.8, longitude: 151.3)
let projected = projection.point(
  for: sydney,
  size: .init(width: 100, height: 100), // the maximum size of the canvas
  coordinateSystem: .topLeft
)
```

Convert a screen-space point (e.g., the location of a click) back to a
geographic coordinate:

```swift
let click = Point(x: 60, y: 40)
let geo = projection.coordinate(
  at: click,
  size: .init(width: 100, height: 100),
  coordinateSystem: .topLeft
) // GeoJSON.Position?, nil if the click is outside the projection's image
```

Inverse returns `nil` when the click sits outside the projection's image —
e.g. clicking off the globe of an Orthographic map, or beyond the bezier
outline of Equal Earth — so you can use it to filter map-area hits.

Coordinate-system handling matches the platform convention: `.topLeft` puts
`(0, 0)` at the top-left corner (UIKit, SwiftUI, SVG) and `.bottomLeft` puts
it at the bottom-left (mathematical / non-flipped AppKit).

### Maps

`GeoDrawer` ships a SwiftUI view called `GeoMap` (backed by `GeoMapView`,
which is an `NSView` on macOS and a `UIView` on iOS / tvOS / visionOS). It
draws GeoJSON content with the projection of your choice and updates async
when its inputs change.

```swift
import SwiftUI
import GeoDrawer

struct MyMap: View {
  var body: some View {
    GeoMap(
      contents: try! GeoDrawer.Content.world(),
      projection: Projections.Cassini()
    )
  }
}
```

You can also draw straight into a `CGContext` (see `GeoDrawer.draw(_:in:)`)
or render to SVG (`GeoDrawer.drawSVG(_:)`).

### Base maps

Drape a raster image under the vector layers — useful for backdrops like
NASA Blue Marble or any other equirectangular / Mercator world image. The
source's projection is first-class: pass any `Projection` and the renderer
forward-projects each output pixel through it to find the source pixel.

```swift
guard let bm = GeoDrawer.BaseMap(
  uiImage: UIImage(named: "blue-marble")!,
  sourceProjection: Projections.Equirectangular(),  // default
  sampling: .bilinear
) else { return }

GeoMap(
  contents: [.baseMap(bm)] + vectorLayers,
  projection: Projections.EqualEarth()
)
```

For high-resolution imagery (split into tiles ahead of time) or live slippy
maps, use a `TileSource` and `TiledBaseMap` instead. The protocol is pure
Swift and works on Linux server-side; only the default tile-bytes decoder
is gated behind CoreGraphics.

```swift
let osm = URLTemplateTileSource(
  template: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
  projection: Projections.Mercator(),
  attribution: "© OpenStreetMap contributors",
  userAgent: "MyApp/1.0 (you@example.com)"
)
let tiled = GeoDrawer.TiledBaseMap(source: osm)  // .auto picks zoom from canvas

GeoMap(
  contents: [.tiledBaseMap(tiled)],
  projection: Projections.Mercator()
)
```

`StaticTileSource` covers the static-grid case (load all tiles into memory
once); `URLTemplateTileSource` covers slippy-map services. Both are
`Sendable` and safe to share across the renderer's parallel sampling
tasks.

### Render quality

`GeoMap` exposes a `quality:` knob so the consuming app can trade off
rendering cost against crispness:

- `.draft` (½× point resolution) — fastest, visibly soft. Right for
  interactive previews while the user is dragging sliders or cycling
  projections.
- `.standard` (1× point resolution) — fast, sharp on non-Retina, soft on
  Retina.
- `.matchDisplay` (the default) — renders at the destination display's
  backing scale; matches what native UIKit/AppKit drawing produces.
- `.custom(Double)` — pick a pixel-density factor directly (e.g. `2.0`
  for an oversampled export at a non-Retina destination).

```swift
GeoMap(
  contents: [.tiledBaseMap(osm)],
  projection: Projections.Mercator(),
  quality: isInteracting ? .draft : .matchDisplay
)
```

## Credits

The code in this repo is written by myself, [Adrian Schönig](https://github.com/nighthawk), along recently with help from [Claude](https://claude.ai)
but it wouldn't have been able to do this so smoothly without the help of these
precious resources:

- Justin Kunimune's [jkunimune/Map-Projections](https://github.com/jkunimune/Map-Projections), 
  which is comprehensive suite of map projections implemented in Java, including
  some projections of his own making.
- The comprehensive description of [map projections](https://en.wikipedia.org/wiki/Map_projection)
  on Wikipedia.

## License

This library is available under the [MIT License](https://mit-license.org). Use it as you please according to those terms.

The [examples](Examples/) are public domain and can be adapted freely.
